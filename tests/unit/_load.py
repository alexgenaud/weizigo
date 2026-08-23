"""Load a fleet module that is not importable by name.

`tools/runner` has no extension, `token-capture.py` and friends are hyphenated,
and `bin/subagent` is extensionless — none can be `import`ed. Every unit test
loads its target through here so the mechanism lives in one place.

Loading executes module top-level code, so a module with side effects at import
time is a finding: report it rather than working around it.

T792: `spec_from_file_location(name, path)` with NO explicit loader returns
None whenever `path` has no extension it recognises (verified on 3.9 and
3.14) — it guesses the loader from the suffix and an extensionless file
matches nothing.  That is exactly `bin/subagent` and `bin/dispatch`, the two
modules this docstring names as the reason this file exists, so the
mechanism as first written could load neither.  Passing an explicit
`SourceFileLoader` (correct for every module this tree targets — all are
plain Python source, extension or not) fixes it for extensionless AND
hyphenated names alike.
"""
import importlib.machinery
import importlib.util
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def load(relpath, name=None):
    """Load <repo>/<relpath> as a module object."""
    path = os.path.join(REPO, relpath)
    if not os.path.exists(path):
        raise FileNotFoundError(path)
    name = name or os.path.basename(relpath).replace("-", "_").replace(".py", "")
    loader = importlib.machinery.SourceFileLoader(name, path)
    spec = importlib.util.spec_from_file_location(name, path, loader=loader)
    if spec is None or spec.loader is None:
        raise ImportError("cannot load %s" % path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod
