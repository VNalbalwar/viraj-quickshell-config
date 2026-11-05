"""Per-app color hooks for qs-theme. Each module has apply(pal); they run in parallel and a broken one
never blocks the others. `pal` is the palette dict from ~/.cache/wallust/quickshell.json."""
import concurrent.futures
import importlib
import sys
import traceback

MODULES = ["nvim", "gtk", "spotify", "zed"]


def _run(name, pal):
    try:
        importlib.import_module(f"{__name__}.{name}").apply(pal)
    except Exception:
        print(f"[qs-theme] {name} failed:", file=sys.stderr)
        traceback.print_exc()


def apply_all(pal):
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(MODULES)) as ex:
        list(ex.map(lambda n: _run(n, pal), MODULES))
