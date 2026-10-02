#!/usr/bin/env python3
"""Level checker: draws a top-down map of a level and checks it is winnable.

Usage:  python3 tools/levels/check.py [Name ...]      (default: every level)
Output: tools/levels/out/<Name>.png plus a report on stdout. Exit code 1 on a FAIL.

Checks (approximations of the real physics, good for catching layout mistakes):
  * every item starts inside the level bounds, clear of walls, props and water;
  * every REQUIRED item has a route to the truck ramp WITHOUT breaking anything, for its
    narrow side (min of width/depth) plus a margin: it can be turned to fit a doorway,
    corners are not modelled; a second pass reports routes that need a breakable;
  * the required items' footprint fits the truck floor (fill ratio);
  * spawns are clear.
It does not simulate Roblox physics: real handling still needs a Studio playtest.
"""
import json, math, os, subprocess, sys
from collections import deque
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LUNE = os.environ.get("LUNE", "/tmp/sh-tools/lune/lune")
OUT = os.path.join(ROOT, "tools", "levels", "out")
RES = 0.5  # grid cell in studs
TRUCK_FLOOR = 2
WALL_THICK = 0.5  # LevelBuilder default wall thickness

PROPS = {  # footprint (w, d) of solid props, None = not solid
    "Counter": lambda p: (p.get("Length", 6), 2.4), "Stove": lambda p: (3, 2.4),
    "Shelf": lambda p: (p.get("Length", 8), 3), "Tree": lambda p: (1.4 * p.get("Scale", 1),) * 2,
    "DeadTree": lambda p: (1.3 * p.get("Scale", 1),) * 2, "Bush": lambda p: (3.4 * p.get("Scale", 1),) * 2,
    "Hedge": lambda p: (p.get("Length", 8), 2), "Fence": lambda p: (p.get("Length", 8), 0.45),
    "Mailbox": lambda p: (1, 1.8), "StreetLamp": lambda p: (0.5, 0.5), "Lantern": lambda p: (0.4, 0.4),
    "Pallet": lambda p: (4, 4), "Forklift": lambda p: (3.6, 9), "Cone": lambda p: (1.4, 1.4),
    "Tombstone": lambda p: (2.2, 0.7), "Pumpkin": lambda p: (2, 2), "Parasol": lambda p: (0.3, 0.3),
    "Bathtub": lambda p: (3.4, 6.4), "Fireplace": lambda p: (6, 1.6),
    "Block": lambda p: (p.get("Size", [4, 4, 4])[0], p.get("Size", [4, 4, 4])[2]),
    "Sign": lambda p: (3.6, 0.3), "Rug": None, "Cobweb": None,
    "Stones": None, "Doormat": None, "FlowerBed": None,
}


def lune_dump(path):
    out = subprocess.run([LUNE, "run", os.path.join(ROOT, "tools/levels/dump.luau"), path], capture_output=True, text=True)
    if out.returncode != 0:
        raise SystemExit(out.stderr)
    return json.loads(out.stdout)


def furniture():
    return lune_dump(os.path.join(ROOT, "src/shared/FurnitureData.luau"))["Kinds"]


def v3(t, y=0):
    return (t[0], t[1], t[2]) if len(t) == 3 else (t[0], y, t[1])


def rect_corners(cx, cz, w, d, rot_deg):
    a = math.radians(rot_deg)
    # Roblox: rotating by +a about Y maps local X (1,0,0) to (cos a, 0, -sin a)
    ux, uz = math.cos(a), -math.sin(a)
    vx, vz = math.sin(a), math.cos(a)
    pts = []
    for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        pts.append((cx + ux * sx * w / 2 + vx * sz * d / 2, cz + uz * sx * w / 2 + vz * sz * d / 2))
    return pts


def wall_pieces(w, mode):
    """Solid wall rectangles (as polygons) for route checks. mode: 'intact' | 'broken'."""
    ax, az = w["A"]
    bx, bz = w["B"]
    L = math.hypot(bx - ax, bz - az)
    ux, uz = (bx - ax) / L, (bz - az) / L
    thick = w.get("Thick", WALL_THICK)
    opens = sorted(w.get("Openings", []), key=lambda o: o["At"])
    solids, cur = [], 0.0
    for o in opens:
        f, t = o["At"] - o["Width"] / 2, o["At"] + o["Width"] / 2
        if f > cur:
            solids.append((cur, f))
        passable = o["Kind"] in ("Door", "Gap", "SwingDoor") or (mode == "broken" and o["Kind"] in ("BreakWindow", "BoardedDoor"))
        if not passable:
            solids.append((f, t))
        cur = t
    if cur < L:
        solids.append((cur, L))
    polys = []
    nx, nz = -uz, ux
    for f, t in solids:
        p0 = (ax + ux * f, az + uz * f)
        p1 = (ax + ux * t, az + uz * t)
        h = thick / 2
        polys.append([(p0[0] + nx * h, p0[1] + nz * h), (p1[0] + nx * h, p1[1] + nz * h), (p1[0] - nx * h, p1[1] - nz * h), (p0[0] - nx * h, p0[1] - nz * h)])
    return polys


def truck_geom(t):
    px, _, pz = v3(t["Pos"])
    rot = t.get("Rot", 0)
    L, W = t.get("Length", 18), t.get("Width", 11)
    a = math.radians(rot)
    def world(lx, lz):
        # local -> world for rotation about Y
        return (px + lx * math.cos(a) + lz * math.sin(a), pz - lx * math.sin(a) + lz * math.cos(a))
    body = [world(x, z) for x, z in ((-W / 2 - 0.6, 0), (W / 2 + 0.6, 0), (W / 2 + 0.6, -L - 7), (-W / 2 - 0.6, -L - 7))]
    cargo = [world(x, z) for x, z in ((-W / 2, 0), (W / 2, 0), (W / 2, -L), (-W / 2, -L))]
    ramp = [world(x, z) for x, z in ((-W / 2, 0), (W / 2, 0), (W / 2, t.get("RampLength", 6)), (-W / 2, t.get("RampLength", 6)))]
    goal = world(0, t.get("RampLength", 6) + 1.5)
    return body, cargo, ramp, goal, (L, W)


def point_in_poly(x, z, poly):
    inside = False
    n = len(poly)
    for i in range(n):
        x1, z1 = poly[i]
        x2, z2 = poly[(i + 1) % n]
        if (z1 > z) != (z2 > z):
            xi = x1 + (z - z1) * (x2 - x1) / (z2 - z1)
            if x < xi:
                inside = not inside
    return inside


class Grid:
    def __init__(self, bmin, bmax):
        self.x0, self.z0 = bmin
        self.nx = int((bmax[0] - bmin[0]) / RES) + 1
        self.nz = int((bmax[1] - bmin[1]) / RES) + 1
        self.block = bytearray(self.nx * self.nz)

    def idx(self, x, z):
        i, j = int((x - self.x0) / RES), int((z - self.z0) / RES)
        if 0 <= i < self.nx and 0 <= j < self.nz:
            return i, j
        return None

    def fill_poly(self, poly, pad=0.0):
        xs = [p[0] for p in poly]
        zs = [p[1] for p in poly]
        i0, j0 = max(0, int((min(xs) - pad - self.x0) / RES)), max(0, int((min(zs) - pad - self.z0) / RES))
        i1, j1 = min(self.nx - 1, int((max(xs) + pad - self.x0) / RES) + 1), min(self.nz - 1, int((max(zs) + pad - self.z0) / RES) + 1)
        for i in range(i0, i1 + 1):
            for j in range(j0, j1 + 1):
                x, z = self.x0 + i * RES, self.z0 + j * RES
                if point_in_poly(x, z, poly) or (pad > 0 and dist_to_poly(x, z, poly) <= pad):
                    self.block[j * self.nx + i] = 1


def dist_seg(px, pz, a, b):
    ax, az = a
    bx, bz = b
    dx, dz = bx - ax, bz - az
    L2 = dx * dx + dz * dz
    t = 0 if L2 == 0 else max(0, min(1, ((px - ax) * dx + (pz - az) * dz) / L2))
    return math.hypot(px - (ax + t * dx), pz - (az + t * dz))


def dist_to_poly(x, z, poly):
    return min(dist_seg(x, z, poly[i], poly[(i + 1) % len(poly)]) for i in range(len(poly)))


def obstacles(level, mode, fur):
    polys = []
    for w in level.get("Walls", []):
        polys += wall_pieces(w, mode)
    for p in level.get("Props", []):
        fn = PROPS.get(p["Kind"])
        if fn is None:
            continue
        w, d = fn(p)
        x, _, z = v3(p["Pos"])
        polys.append(rect_corners(x, z, w, d, p.get("Rot", 0)))
    for h in level.get("Hazards", []):
        if h["Kind"] == "Water":
            (x0, z0), (x1, z1) = h["Min"], h["Max"]
            polys.append([(x0, z0), (x1, z0), (x1, z1), (x0, z1)])
    body, cargo, ramp, goal, _ = truck_geom(level["Truck"])
    polys.append(body)
    return polys


def route(level, fur, item, mode, cache):
    k = fur[item["Kind"]]
    sx, sy, sz = k["Size"]
    narrow = min(sx, sz)
    r = narrow / 2 + 0.25
    key = (mode, round(r, 2))
    if key not in cache:
        b = level["Bounds"]
        g = Grid(b["Min"], b["Max"])
        for poly in obstacles(level, mode, fur):
            g.fill_poly(poly, pad=r)
        cache[key] = g
    g = cache[key]
    x, _, z = v3(item["Pos"])
    _, _, _, goal, _ = truck_geom(level["Truck"])
    start = g.idx(x, z)
    target = g.idx(*goal)
    if not start or not target:
        return False, "out of grid"
    # start from the nearest free cell (items begin against walls)
    best = None
    for rr in range(0, int(6 / RES)):
        for di in range(-rr, rr + 1):
            for dj in range(-rr, rr + 1):
                i, j = start[0] + di, start[1] + dj
                if 0 <= i < g.nx and 0 <= j < g.nz and not g.block[j * g.nx + i]:
                    best = (i, j)
                    break
            if best:
                break
        if best:
            break
    if not best:
        return False, "boxed in"
    seen = bytearray(g.nx * g.nz)
    q = deque([best])
    seen[best[1] * g.nx + best[0]] = 1
    # the goal region: anything within 2 studs of the ramp foot
    tr = int(2 / RES)
    while q:
        i, j = q.popleft()
        if abs(i - target[0]) <= tr and abs(j - target[1]) <= tr:
            return True, ""
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ni, nj = i + di, j + dj
            if 0 <= ni < g.nx and 0 <= nj < g.nz:
                n = nj * g.nx + ni
                if not seen[n] and not g.block[n]:
                    seen[n] = 1
                    q.append((ni, nj))
    return False, "no route"


def overlaps(level, fur, item):
    k = fur[item["Kind"]]
    x, _, z = v3(item["Pos"])
    poly = rect_corners(x, z, k["Size"][0], k["Size"][2], item.get("Rot", 0))
    probs = []
    for w in level.get("Walls", []):
        for wp in wall_pieces(w, "intact"):
            if any(point_in_poly(px, pz, wp) for px, pz in poly) or any(point_in_poly(px, pz, poly) for px, pz in wp):
                probs.append("touches a wall")
                break
    for h in level.get("Hazards", []):
        if h["Kind"] == "Water":
            (x0, z0), (x1, z1) = h["Min"], h["Max"]
            if x0 < x < x1 and z0 < z < z1:
                probs.append("starts in water")
    b = level["Bounds"]
    if not (b["Min"][0] < x < b["Max"][0] and b["Min"][1] < z < b["Max"][1]):
        probs.append("outside bounds")
    return sorted(set(probs))


def draw(level, fur, name, results):
    b = level["Bounds"]
    scale = 6
    W = int((b["Max"][0] - b["Min"][0]) * scale)
    H = int((b["Max"][1] - b["Min"][1]) * scale)
    img = Image.new("RGB", (W, H), (120, 180, 90))
    d = ImageDraw.Draw(img)
    def P(x, z):
        return ((x - b["Min"][0]) * scale, (z - b["Min"][1]) * scale)
    colors = {"Grass": (110, 190, 80), "Road": (86, 90, 100), "Pavement": (196, 192, 184), "Concrete": (176, 176, 172), "Sand": (236, 214, 160), "Dirt": (110, 92, 74), "DeadGrass": (96, 104, 74), "Patio": (226, 206, 170), "Metal": (150, 156, 164)}
    for g in level.get("Ground", []):
        c = tuple(int(v * 255) for v in g["Color"]) if "Color" in g else colors.get(g["Kind"], (180, 180, 180))
        d.rectangle([P(*g["Min"]), P(*g["Max"])], fill=c)
    for f in level.get("Floors", []):
        c = tuple(int(v * 255) for v in f["Color"]) if "Color" in f else (210, 160, 110)
        d.rectangle([P(*f["Min"]), P(*f["Max"])], fill=c)
    for h in level.get("Hazards", []):
        if h["Kind"] == "Water":
            d.rectangle([P(*h["Min"]), P(*h["Max"])], fill=(70, 160, 230))
        elif h["Kind"] == "Conveyor":
            d.rectangle([P(*h["Min"]), P(*h["Max"])], fill=(60, 60, 70), outline=(250, 210, 60), width=2)
            cx = (h["Min"][0] + h["Max"][0]) / 2
            cz = (h["Min"][1] + h["Max"][1]) / 2
            d.line([P(cx, cz), P(cx + h["Dir"][0] * 4, cz + h["Dir"][1] * 4)], fill=(250, 210, 60), width=4)
        elif h["Kind"] == "Traffic":
            d.line([P(*h["A"]), P(*h["B"])], fill=(255, 80, 60), width=3)
        elif h["Kind"] == "Ghost":
            pts = [P(*p) for p in h["Patrol"]]
            d.line(pts + [pts[0]], fill=(230, 230, 255), width=2)
        elif h["Kind"] == "Platform":
            pts = [P(p[0], p[2]) for p in h["Path"]]
            d.line(pts, fill=(255, 140, 170), width=3)
            s = h.get("Size", [8, 1, 8])
            x, _, z = h["Path"][0]
            d.rectangle([P(x - s[0] / 2, z - s[2] / 2), P(x + s[0] / 2, z + s[2] / 2)], outline=(255, 140, 170), width=2)
    for p in level.get("Props", []):
        fn = PROPS.get(p["Kind"])
        if fn is None:
            continue
        w, dd = fn(p)
        x, _, z = v3(p["Pos"])
        d.polygon([P(*q) for q in rect_corners(x, z, w, dd, p.get("Rot", 0))], fill=(90, 120, 80) if p["Kind"] in ("Tree", "Bush", "Hedge") else (140, 130, 120))
    for w in level.get("Walls", []):
        for poly in wall_pieces(w, "intact"):
            d.polygon([P(*q) for q in poly], fill=(50, 40, 50) if not w.get("Low") else (110, 90, 110))
        ax, az = w["A"]
        bx, bz = w["B"]
        L = math.hypot(bx - ax, bz - az)
        for o in w.get("Openings", []):
            t0 = (o["At"] - o["Width"] / 2) / L
            t1 = (o["At"] + o["Width"] / 2) / L
            c = {"Door": (80, 220, 90), "Gap": (80, 220, 90), "SwingDoor": (60, 200, 200), "Window": (120, 170, 255), "BreakWindow": (255, 60, 60), "BoardedDoor": (255, 150, 40)}.get(o["Kind"], (255, 255, 255))
            d.line([P(ax + (bx - ax) * t0, az + (bz - az) * t0), P(ax + (bx - ax) * t1, az + (bz - az) * t1)], fill=c, width=4)
    body, cargo, ramp, goal, _ = truck_geom(level["Truck"])
    d.polygon([P(*q) for q in body], fill=(232, 96, 60))
    d.polygon([P(*q) for q in cargo], fill=(176, 140, 100), outline=(255, 220, 70))
    d.polygon([P(*q) for q in ramp], fill=(160, 166, 176))
    d.ellipse([P(goal[0] - 1, goal[1] - 1), P(goal[0] + 1, goal[1] + 1)], fill=(255, 255, 0))
    for item in level.get("Items", []):
        k = fur[item["Kind"]]
        x, _, z = v3(item["Pos"])
        poly = rect_corners(x, z, k["Size"][0], k["Size"][2], item.get("Rot", 0))
        ok = results.get(id(item), True)
        fill = (250, 240, 200) if item.get("Required", True) is not False else (200, 200, 200)
        d.polygon([P(*q) for q in poly], fill=fill, outline=(0, 160, 0) if ok else (255, 0, 0))
        d.text(P(x - 2, z - 1), item["Kind"][:6], fill=(0, 0, 0))
    for s in level.get("Spawns", []):
        x, _, z = v3(s)
        d.ellipse([P(x - 1, z - 1), P(x + 1, z + 1)], fill=(255, 0, 255))
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".png")
    img.save(path)
    return path


def check(name, fur):
    level = lune_dump(os.path.join(ROOT, "src/shared/Levels", name + ".luau"))
    print(f"== {name}: {level.get('Name')}")
    fails = 0
    results = {}
    cache = {}
    req = [i for i in level.get("Items", []) if i.get("Required", True) is not False]
    for item in level.get("Items", []):
        probs = overlaps(level, fur, item)
        tag = f"{item['Kind']} @ {item['Pos']}"
        if probs:
            print(f"  FAIL {tag}: {', '.join(probs)}")
            fails += 1
            results[id(item)] = False
        if item.get("Required", True) is False:
            continue
        ok, why = route(level, fur, item, "intact", cache)
        if not ok:
            ok2, _ = route(level, fur, item, "broken", cache)
            if ok2:
                print(f"  FAIL {tag}: only reachable by breaking something (a breakable must stay optional)")
            else:
                print(f"  FAIL {tag}: {why} to the truck")
            fails += 1
            results[id(item)] = False
    _, _, _, _, (L, W) = truck_geom(level["Truck"])
    area = sum(fur[i["Kind"]]["Size"][0] * fur[i["Kind"]]["Size"][2] for i in req)
    fill = area / (L * W)
    print(f"  required items: {len(req)}, footprint {area:.0f} of truck floor {L * W:.0f} studs^2 ({fill * 100:.0f}% - stacking {'needed' if fill > 0.9 else 'optional'})")
    if fill > 1.6:
        print("  FAIL truck far too small for the required items")
        fails += 1
    for s in level.get("Spawns", []):
        x, _, z = v3(s)
        for w in level.get("Walls", []):
            for wp in wall_pieces(w, "intact"):
                if point_in_poly(x, z, wp):
                    print(f"  FAIL spawn {s} inside a wall")
                    fails += 1
    path = draw(level, fur, name, results)
    print(f"  map: {os.path.relpath(path, ROOT)}  ->  {'PASS' if fails == 0 else f'{fails} FAIL'}")
    return fails


def main():
    fur = furniture()
    names = sys.argv[1:] or [f[:-5] for f in sorted(os.listdir(os.path.join(ROOT, "src/shared/Levels"))) if f.endswith(".luau")]
    total = sum(check(n, fur) for n in names)
    sys.exit(1 if total else 0)


if __name__ == "__main__":
    main()
