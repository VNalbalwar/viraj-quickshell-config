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

static void
load_css (void)
{
  char *text = NULL;

  if (!g_file_get_contents (css_path, &text, NULL, NULL))
    text = g_strdup ("");                        /* file gone: no overrides */

  if (gtk_major == 4)
    ((fn_load4) sym ("gtk_css_provider_load_from_string")) (provider, text);
  else
    ((fn_load3) sym ("gtk_css_provider_load_from_data")) (provider, text, -1, NULL);
  g_free (text);
}

static gboolean
reload_cb (gpointer data)
{
  reload_id = 0;
  load_css ();
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
  load_css ();

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
