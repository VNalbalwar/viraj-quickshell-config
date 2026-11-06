/* qs-gtk-live - makes running GTK3 and GTK4 apps pick up changes to ~/.config/gtk-{3,4}.0/gtk.css straight away.
 *
 * Why: GTK reads that file once, when an app starts, and never looks again, so a theme switch only reaches apps you
 * open afterwards. (GTK4 also dropped GTK_MODULES, the old plug-in hook, so there is no GTK-level way in.)
 *
 * How: this is a GIO module. GLib loads every module found in $GIO_EXTRA_MODULES into each GLib/GTK process, early. We
 * do nothing unless GTK ends up in that process; once it does (and a display is open) we
 *   - load the same gtk.css into a style provider of our own, one priority step above GTK's static copy, and
 *   - watch the file; on any change (debounced - theme switchers write several files) we reload that provider,
 *     which makes GTK restyle every open window, exactly as if the app had just started.
 * GTK itself is never patched or replaced, so GTK updates can't break this. GTK symbols are looked up at run time
 * (dlsym), so the module neither links GTK nor pulls it into non-GTK programs. */
#define _GNU_SOURCE
#include <gio/gio.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

#define USER_PRIORITY_PLUS_ONE 801               /* GTK_STYLE_PROVIDER_PRIORITY_USER (800) + 1 */

typedef gpointer (*fn_ptr_void) (void);
typedef gpointer (*fn_ptr_ptr) (gpointer);
typedef void (*fn_add4) (gpointer display, gpointer provider, guint priority);
typedef void (*fn_add3) (gpointer screen, gpointer provider, guint priority);
typedef void (*fn_load4) (gpointer provider, const char *text);
typedef gboolean (*fn_load3) (gpointer provider, const char *data, gssize len, GError **error);

static int gtk_major = 0;
static gpointer provider = NULL;
static char *css_path = NULL;
static guint reload_id = 0;
static int tries = 0;

static void *
sym (const char *name)
{
  return dlsym (RTLD_DEFAULT, name);
}

/* ── fading between two themes ──────────────────────────────────────────────────────────────────────────────────────────
 * GTK restyles instantly when a provider reloads (CSS transitions only run for state changes). To make a theme switch
 * glide instead, we step the @define-color values from the old to the new ones ourselves, a dozen reloads over ~0.4 s.
 * Only "@define-color name #RRGGBB;" lines are interpolated; everything else in gtk.css is taken as is. */
#define FADE_STEPS 16
#define FADE_MS 30

static GHashTable *shown = NULL;                 /* name -> guint 0xRRGGBB currently on screen */
static GHashTable *from_colors = NULL;
static GHashTable *to_colors = NULL;
static char *to_text = NULL;
static int fade_step = 0;
static guint fade_id = 0;

static GHashTable *
parse_colors (const char *text)
{
  GHashTable *t = g_hash_table_new_full (g_str_hash, g_str_equal, g_free, NULL);
  const char *p = text;

  while ((p = strstr (p, "@define-color ")) != NULL)
    {
      char name[96];
      unsigned int rgb;

      if (sscanf (p, "@define-color %95s #%6x;", name, &rgb) == 2)
        g_hash_table_insert (t, g_strdup (name), GUINT_TO_POINTER (rgb | 0x1000000));   /* bit 24 marks "present" */
      p += 14;
    }
  return t;
}

static guint
mix_rgb (guint a, guint b, double t)
{
  guint out = 0;
  int shift;

  for (shift = 16; shift >= 0; shift -= 8)
    {
      double ca = (a >> shift) & 0xff, cb = (b >> shift) & 0xff;
      out |= ((guint) (ca + (cb - ca) * t + 0.5) & 0xff) << shift;
    }
  return out;
}

/* the new gtk.css with every @define-color value replaced by the mix at t */
static char *
text_at (double t)
{
  GString *out = g_string_new (NULL);
  const char *p = to_text;

  while (*p)
    {
      const char *eol = strchr (p, '\n');
      gsize len = eol ? (gsize) (eol - p) : strlen (p);
      char name[96];
      unsigned int rgb;

      if (strncmp (p, "@define-color ", 14) == 0 && sscanf (p, "@define-color %95s #%6x;", name, &rgb) == 2
          && g_hash_table_contains (from_colors, name))
        {
          guint from = GPOINTER_TO_UINT (g_hash_table_lookup (from_colors, name)) & 0xffffff;
          g_string_append_printf (out, "@define-color %s #%06X;", name, mix_rgb (from, rgb, t));
        }
      else
        g_string_append_len (out, p, len);
      g_string_append_c (out, '\n');
      p += len + (eol ? 1 : 0);
    }
  return g_string_free (out, FALSE);
}

static void
apply_text (const char *text)
{
  if (gtk_major == 4)
    ((fn_load4) sym ("gtk_css_provider_load_from_string")) (provider, text);
  else
    ((fn_load3) sym ("gtk_css_provider_load_from_data")) (provider, text, -1, NULL);
}

static gboolean
fade_tick (gpointer data)
{
  double lin = (double) ++fade_step / FADE_STEPS;
  double t = 1.0 - (1.0 - lin) * (1.0 - lin) * (1.0 - lin);        /* ease-out */
  char *text;

  if (fade_step >= FADE_STEPS)
    {
      apply_text (to_text);
      g_clear_pointer (&shown, g_hash_table_destroy);
      shown = to_colors;
      to_colors = NULL;
      g_clear_pointer (&from_colors, g_hash_table_destroy);
      fade_id = 0;
      return G_SOURCE_REMOVE;
    }

  text = text_at (t);
  apply_text (text);
  g_free (text);
  return G_SOURCE_CONTINUE;
}

static void
fade_to (char *new_text)
{
  GHashTable *target = parse_colors (new_text);

  if (fade_id)
    {                                            /* interrupted mid-fade: carry on from what is on screen now */
      double lin = (double) fade_step / FADE_STEPS;
      double t = 1.0 - (1.0 - lin) * (1.0 - lin) * (1.0 - lin);
      GHashTableIter it;
      gpointer k, v;
      GHashTable *now = g_hash_table_new_full (g_str_hash, g_str_equal, g_free, NULL);

      g_hash_table_iter_init (&it, to_colors);
      while (g_hash_table_iter_next (&it, &k, &v))
        {
          guint to_rgb = GPOINTER_TO_UINT (v) & 0xffffff;
          guint from_rgb = from_colors && g_hash_table_contains (from_colors, k)
                             ? GPOINTER_TO_UINT (g_hash_table_lookup (from_colors, k)) & 0xffffff : to_rgb;
          g_hash_table_insert (now, g_strdup (k), GUINT_TO_POINTER (mix_rgb (from_rgb, to_rgb, t) | 0x1000000));
        }
      g_source_remove (fade_id);
      fade_id = 0;
      g_clear_pointer (&from_colors, g_hash_table_destroy);
      g_clear_pointer (&to_colors, g_hash_table_destroy);
      g_clear_pointer (&shown, g_hash_table_destroy);
      shown = now;
    }

  g_free (to_text);
  to_text = new_text;

  if (shown == NULL || g_hash_table_size (shown) == 0)
    {                                            /* first load: nothing to fade from */
      apply_text (to_text);
      g_clear_pointer (&shown, g_hash_table_destroy);
      shown = target;
      return;
    }

  from_colors = shown;
  shown = NULL;
  to_colors = target;
  fade_step = 0;
  fade_id = g_timeout_add (FADE_MS, fade_tick, NULL);
}

static gboolean
reload_cb (gpointer data)
{
  char *text = NULL;

  reload_id = 0;
  if (!g_file_get_contents (css_path, &text, NULL, NULL))
    text = g_strdup ("");
  fade_to (text);
  return G_SOURCE_REMOVE;
}

static void
file_changed (GFileMonitor *m, GFile *file, GFile *other, GFileMonitorEvent ev, gpointer data)
{
  switch (ev)
    {
    case G_FILE_MONITOR_EVENT_CHANGES_DONE_HINT:
    case G_FILE_MONITOR_EVENT_CREATED:
    case G_FILE_MONITOR_EVENT_DELETED:
    case G_FILE_MONITOR_EVENT_RENAMED:
    case G_FILE_MONITOR_EVENT_MOVED_IN:
    case G_FILE_MONITOR_EVENT_MOVED_OUT:
      break;
    default:
      return;
    }
  if (reload_id)
    g_source_remove (reload_id);
  reload_id = g_timeout_add (150, reload_cb, NULL);
}

/* called until GTK is in this process and has a display (or we give up: most processes using GIO are not GTK apps) */
static gboolean
try_start (gpointer data)
{
  gpointer display;
  GFile *file;
  GFileMonitor *monitor;

  if (sym ("gtk_css_provider_new") == NULL || sym ("gdk_display_get_default") == NULL)
    return ++tries < 120 ? G_SOURCE_CONTINUE : G_SOURCE_REMOVE;

  display = ((fn_ptr_void) sym ("gdk_display_get_default")) ();
  if (display == NULL)
    return ++tries < 240 ? G_SOURCE_CONTINUE : G_SOURCE_REMOVE;

  if (sym ("gtk_style_context_add_provider_for_display"))
    gtk_major = 4;
  else if (sym ("gtk_style_context_add_provider_for_screen"))
    gtk_major = 3;
  else
    return G_SOURCE_REMOVE;

  css_path = g_build_filename (g_get_user_config_dir (), gtk_major == 4 ? "gtk-4.0" : "gtk-3.0", "gtk.css", NULL);
  provider = ((fn_ptr_void) sym ("gtk_css_provider_new")) ();
  {
    char *first = NULL;
    if (!g_file_get_contents (css_path, &first, NULL, NULL))
      first = g_strdup ("");
    fade_to (first);                             /* first load: applied at once, and remembered for the next fade */
  }

  if (gtk_major == 4)
    ((fn_add4) sym ("gtk_style_context_add_provider_for_display")) (display, provider, USER_PRIORITY_PLUS_ONE);
  else
    ((fn_add3) sym ("gtk_style_context_add_provider_for_screen"))
      (((fn_ptr_ptr) sym ("gdk_display_get_default_screen")) (display), provider, USER_PRIORITY_PLUS_ONE);

  file = g_file_new_for_path (css_path);
  monitor = g_file_monitor_file (file, G_FILE_MONITOR_WATCH_MOVES, NULL, NULL);
  if (monitor)
    g_signal_connect (monitor, "changed", G_CALLBACK (file_changed), NULL);
  g_object_unref (file);
  return G_SOURCE_REMOVE;
}

/* GIO unloads modules that registered no types; we have timers and signal handlers living in this code, so pin it */
static void
pin_module (void)
{
  Dl_info info;

  if (dladdr ((void *) pin_module, &info) && info.dli_fname)
    dlopen (info.dli_fname, RTLD_NOW | RTLD_NODELETE);
}

void
g_io_module_load (GIOModule *module)
{
  static gsize once = 0;

  if (g_once_init_enter (&once))
    {
      pin_module ();
      g_timeout_add (500, try_start, NULL);
      g_once_init_leave (&once, 1);
    }
}

void
g_io_module_unload (GIOModule *module)
{
}

char **
g_io_module_query (void)
{
  return g_new0 (char *, 1);                     /* registers no extension points */
}
