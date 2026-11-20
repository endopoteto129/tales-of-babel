import sys, importlib
from gen import report, write_gd
FLOORS = {1: "grass", 2: "town", 3: "bamboo", 4: "colosseum", 5: "library", 6: "factory", 7: "summit"}
done = {}
for f, theme in FLOORS.items():
    try:
        mod = importlib.import_module("f%d" % f)
    except ModuleNotFoundError:
        continue
    m = mod.build()
    if "-q" not in sys.argv:
        report("F%d" % f, m.text())
    done[f] = (theme, m, getattr(mod, "EXTRA", {}))
write_gd(done, "../../data/fieldmaps.gd")
print("wrote", list(done))
