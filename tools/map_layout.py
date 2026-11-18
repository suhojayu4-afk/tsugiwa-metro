"""Line layout for the route map (build_map.py): station spots, express
trains that ride along the local lines, and lines drawn side by side
where they share a stretch.

- Stations are snapped to a 4-unit grid and nudged apart.
- A train that skips stations (Tokaido Line, Tokyo -> Shinagawa) is drawn
  through the stops of the line that really runs beside it, so the two run
  together instead of cutting across the map.
- Every stretch between two stops is one corridor; the lines on it are put
  side by side in an order that keeps them from crossing (the line that
  turns left further on runs on the left), each line shifted sideways by
  SPACING units. Segments stay straight or 45°.
"""
import heapq
import math
from functools import cmp_to_key

GRID = 1
MIN_GAP = 22        # map units between two stations (two markers side by side)
SPACING = 6         # map units between lines running side by side


def snap(p):
    return (round(p[0] / GRID) * GRID, round(p[1] / GRID) * GRID)


def km(a, b):
    return math.hypot((a[0] - b[0]) * 111.0, (a[1] - b[1]) * 90.9)


# ---------- stations ----------
EPS = 30            # how far (map units) a station may sit from its real spot to keep a line straight


def _shapes(a, b):
    """Octilinear ways from a to b (a and b included): one bend either way,
    or straight / 45° already."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    adx, ady = abs(dx), abs(dy)
    if adx < 1e-6 or ady < 1e-6 or abs(adx - ady) < 1e-6:
        return [[a, b]]
    sx, sy = (1 if dx > 0 else -1), (1 if dy > 0 else -1)
    d = min(adx, ady)
    if adx > ady:
        k1 = (a[0] + sx * (adx - d), a[1])          # straight first, then 45°
        k2 = (a[0] + sx * d, a[1] + sy * d)          # 45° first, then straight
    else:
        k1 = (a[0], a[1] + sy * (ady - d))
        k2 = (a[0] + sx * d, a[1] + sy * d)
    return [[a, k1, b], [a, k2, b]]


def _project(p, pts):
    """(distance, arc length) of the point of polyline [pts] nearest to p."""
    best, run = (1e18, 0.0), 0.0
    for a, b in zip(pts, pts[1:]):
        L = math.dist(a, b)
        t = 0 if L == 0 else max(0, min(1, ((p[0] - a[0]) * (b[0] - a[0]) + (p[1] - a[1]) * (b[1] - a[1])) / L ** 2))
        q = (a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1]))
        d = math.dist(p, q)
        if d < best[0]:
            best = (d, run + t * L)
        run += L
    return best


def _at(pts, s):
    for a, b in zip(pts, pts[1:]):
        L = math.dist(a, b)
        if s <= L or b is pts[-1]:
            t = 0 if L == 0 else min(1.0, s / L)
            return (a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1]))
        s -= L
    return pts[-1]


def schematize(rides, raw, order, closed, eps=lambda sid: EPS, half=None):
    """Station spots and the drawn shape of every stretch.

    Lines are laid one by one ([order]: the main lines first). On each line
    the stations already placed are fixed; between two of them the line is
    one straight / 45° run with at most one bend, and the stations between
    sit on it in order, at least MIN_GAP apart. If a station would end up
    more than eps(station) from its real spot (EPS in the centre, more in
    the suburbs), it is fixed there instead and both halves are laid again."""
    pos, shape = {}, {}

    grid = {}

    def cell(p):
        return int(p[0] // MIN_GAP), int(p[1] // MIN_GAP)

    def fix(sid):
        if sid not in pos:
            put(sid, snap(raw[sid]))

    def put(sid, p):
        pos[sid] = p
        grid.setdefault(cell(p), []).append(sid)

    def crowded(p, sid):
        gx, gy = cell(p)
        h = half or {}
        return any(o != sid and math.dist(pos[o], p) < MIN_GAP + h.get(o, 0) + h.get(sid, 0)
                   for dx in (-2, -1, 0, 1, 2) for dy in (-2, -1, 0, 1, 2) for o in grid.get((gx + dx, gy + dy), ()))

    def lay(chain):
        a, b = chain[0], chain[-1]
        inner = chain[1:-1]
        if a == b and len(chain) <= 2:   # the same station twice in a row: nothing to lay
            return
        if a == b:   # a loop closing on one fixed station: split it in the middle
            fix(chain[len(chain) // 2])
            k = len(chain) // 2
            lay(chain[:k + 1])
            lay(chain[k:])
            return
        best = None
        for pts in _shapes(pos[a], pos[b]):
            prj = [_project(raw[s], pts) for s in inner]
            err = max((d - eps(s_) for (d, _), s_ in zip(prj, inner)), default=0)
            if best is None or err < best[0]:
                best = (err, pts, prj)
        err, pts, prj = best
        if inner and err > 0:
            worst = max(range(len(inner)), key=lambda i: prj[i][0] - eps(inner[i]))
            fix(inner[worst])
            k = worst + 1
            lay(chain[:k + 1])
            lay(chain[k:])
            return
        total = sum(math.dist(p, q) for p, q in zip(pts, pts[1:]))
        ss = [s_ for _, s_ in prj]
        for i in range(1, len(ss)):                 # keep the running order
            ss[i] = max(ss[i], ss[i - 1])
        n = len(ss)
        gap = min(MIN_GAP, total / (n + 1)) if n else 0
        for i in range(n):                          # at least [gap] apart, clear of both ends
            lo = (i + 1) * gap
            hi = total - (n - i) * gap
            ss[i] = min(max(ss[i], lo, ss[i - 1] + gap if i else lo), hi)
        spots = [pos[a]] + [_at(pts, s_) for s_ in ss] + [pos[b]]
        # A spot on the run that would sit on top of another line's station:
        # keep that station where it really is and lay both halves again.
        for i, (sid, p) in enumerate(zip(inner, spots[1:-1])):
            if crowded(p, sid):
                fix(sid)
                lay(chain[:i + 2])
                lay(chain[i + 1:])
                return
        for sid, p in zip(inner, spots[1:-1]):
            put(sid, p)
        # The drawn shape of each stretch: the piece of [pts] between its two stations.
        marks = [0.0] + ss + [total]
        for i in range(len(chain) - 1):
            u, v = chain[i], chain[i + 1]
            s0, s1 = marks[i], marks[i + 1]
            piece = [_at(pts, s0)]
            run = 0.0
            for p, q in zip(pts, pts[1:]):
                run += math.dist(p, q)
                if s0 < run < s1:
                    piece.append(q)
            piece.append(_at(pts, s1))
            piece[0], piece[-1] = pos[u], pos[v]
            key = frozenset((u, v))
            if key not in shape and u != v:
                shape[key] = (u, piece)

    for lid in order:
        seq = rides[lid] + ([rides[lid][0]] if closed[lid] else [])
        fix(seq[0])
        fix(seq[-1])
        start = 0
        for i in range(1, len(seq)):
            if seq[i] in pos:
                lay(seq[start:i + 1])
                start = i
    return pos, shape


def relax(pos, shape, half, rounds=20):
    """Last touch: two station markers that still touch are pushed apart;
    the stretches at a moved station are drawn again (one bend)."""
    moved = set()
    for _ in range(rounds):
        grid = {}
        for sid, p in pos.items():
            grid.setdefault((int(p[0] // 40), int(p[1] // 40)), []).append(sid)
        hit = False
        for sid, (ax, ay) in list(pos.items()):
            gx, gy = int(ax // 40), int(ay // 40)
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    for o in grid.get((gx + dx, gy + dy), ()):
                        if o <= sid:
                            continue
                        (ax, ay), (bx, by) = pos[sid], pos[o]
                        need = MIN_GAP + half.get(sid, 0) + half.get(o, 0)
                        d = math.hypot(bx - ax, by - ay)
                        if d < need:
                            ux, uy = ((bx - ax) / d, (by - ay) / d) if d > 1e-6 else (1.0, 0.0)
                            push = (need - d) / 2 + 0.5
                            pos[sid] = (ax - ux * push, ay - uy * push)
                            pos[o] = (bx + ux * push, by + uy * push)
                            moved |= {sid, o}
                            hit = True
        if not hit:
            break
    for key in [k for k in shape if k & moved]:
        u, v = tuple(key)
        shape[key] = (u, _shapes(pos[u], pos[v])[0])
    return moved


def place(raw, half=None):
    """Spots for the stations, apart enough that their markers (wider
    where several lines pass, [half] = half the extra width) never touch."""
    half = half or {}
    pos = {sid: snap(p) for sid, p in raw.items()}
    ids = sorted(pos)
    for _ in range(30):
        grid = {}
        for sid in ids:
            x, y = pos[sid]
            grid.setdefault((int(x // MIN_GAP), int(y // MIN_GAP)), []).append(sid)
        moved = False
        for sid in ids:
            ax, ay = pos[sid]
            gx, gy = int(ax // MIN_GAP), int(ay // MIN_GAP)
            for dx in (-2, -1, 0, 1, 2):
                for dy in (-2, -1, 0, 1, 2):
                    for other in grid.get((gx + dx, gy + dy), ()):
                        if other <= sid:
                            continue
                        (ax, ay), (bx, by) = pos[sid], pos[other]
                        need = MIN_GAP + half.get(sid, 0) + half.get(other, 0)
                        if math.hypot(ax - bx, ay - by) < need:
                            ddx, ddy = bx - ax, by - ay
                            if ddx == 0 and ddy == 0:
                                ddx = 1
                            n = math.hypot(ddx, ddy)
                            push = (need - n) / 2 + 0.5
                            pos[other] = snap((bx + ddx / n * push, by + ddy / n * push))
                            pos[sid] = snap((ax - ddx / n * push, ay - ddy / n * push))
                            moved = True
        if not moved:
            break
    return pos


# ---------- express trains along the local lines ----------
def _seg_dev(p, a, b):
    """Distance (km) of point p from segment a-b, all (lat, lng)."""
    ax, ay = a[1] * 90.9, a[0] * 111.0
    bx, by = b[1] * 90.9, b[0] * 111.0
    px, py = p[1] * 90.9, p[0] * 111.0
    l2 = (bx - ax) ** 2 + (by - ay) ** 2
    t = 0 if l2 == 0 else max(0, min(1, ((px - ax) * (bx - ax) + (py - ay) * (by - ay)) / l2))
    return math.hypot(px - ax - t * (bx - ax), py - ay - t * (by - ay))


def _shortest(adj, a, b, limit, skip):
    dist, prev, heap = {a: 0.0}, {}, [(0.0, a)]
    while heap:
        d, u = heapq.heappop(heap)
        if u == b:
            path = [b]
            while path[-1] != a:
                path.append(prev[path[-1]])
            return d, path[::-1]
        if d > dist.get(u, 1e18) or d > limit:
            continue
        for v, w in adj.get(u, ()):
            if frozenset((u, v)) == skip:
                continue
            nd = d + w
            if nd < dist.get(v, 1e18) and nd <= limit:
                dist[v], prev[v] = nd, u
                heapq.heappush(heap, (nd, v))
    return None


def ride_paths(lines, geo, group):
    """Each line as the list of stations it passes (its stops plus the ones
    it runs through without stopping)."""
    adj_all, adj_grp = {}, {}
    for l in lines:
        st = l['stations']
        pairs = list(zip(st, st[1:])) + ([(st[-1], st[0])] if l['loop'] else [])
        for a, b in pairs:
            w = km(geo[a], geo[b])
            for adj in (adj_all, adj_grp.setdefault(group[l['id']], {})):
                adj.setdefault(a, set()).add((b, w))
                adj.setdefault(b, set()).add((a, w))
    out = {}
    for l in lines:
        st = l['stations']
        pairs = list(zip(st, st[1:])) + ([(st[-1], st[0])] if l['loop'] else [])
        seq = [st[0]]
        for a, b in pairs:
            direct = km(geo[a], geo[b])
            via = None
            if direct > 0.3:
                skip = frozenset((a, b))
                # The same railway company's tracks first (JR rapid beside JR local) ...
                r = _shortest(adj_grp[group[l['id']]], a, b, direct * 1.3, skip)
                if r and len(r[1]) > 2:
                    via = r[1]
                else:
                    # ... then any line running right along it (Joban rapid beside the Chiyoda Line).
                    r = _shortest(adj_all, a, b, direct * 1.15, skip)
                    if r and len(r[1]) > 2 and max(_seg_dev(geo[s], geo[a], geo[b]) for s in r[1][1:-1]) \
                            <= max(0.5, 0.1 * direct):
                        via = r[1]
            for x in (via[1:] if via else [b]):
                if x != seq[-1]:
                    seq.append(x)
        if l['loop']:
            seq = seq[:-1]
        out[l['id']] = seq
    return out


# ---------- corridors ----------
def _octi(a, b):
    """Points from a to b (a excluded): straight, then 45°, then straight."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    adx, ady = abs(dx), abs(dy)
    if adx < 1e-9 or ady < 1e-9 or abs(adx - ady) < 1e-9:
        return [b]
    sx, sy = (1 if dx > 0 else -1), (1 if dy > 0 else -1)
    diag = min(adx, ady)
    rest = max(adx, ady) - diag
    half = round(rest / 2 / GRID) * GRID
    p1 = (a[0] + sx * half, a[1]) if adx > ady else (a[0], a[1] + sy * half)
    p2 = (p1[0] + sx * diag, p1[1] + sy * diag)
    return [p for p in (p1, p2, b) if p != a]


def _unit(d):
    n = math.hypot(*d)
    return (d[0] / n, d[1] / n)


def _offset(pts, o):
    """Polyline [pts] moved [o] units to its left (screen: y down), corners mitred,
    so straight / 45° segments stay straight / 45°."""
    if o == 0:
        return list(pts)
    dirs = [_unit((b[0] - a[0], b[1] - a[1])) for a, b in zip(pts, pts[1:])]
    nrm = [(d[1], -d[0]) for d in dirs]
    out = [(pts[0][0] + nrm[0][0] * o, pts[0][1] + nrm[0][1] * o)]
    for j in range(1, len(pts) - 1):
        d1, d2 = dirs[j - 1], dirs[j]
        p1 = (pts[j][0] + nrm[j - 1][0] * o, pts[j][1] + nrm[j - 1][1] * o)
        p2 = (pts[j][0] + nrm[j][0] * o, pts[j][1] + nrm[j][1] * o)
        cr = d1[0] * d2[1] - d1[1] * d2[0]
        if abs(cr) < 1e-9:
            out.append(p2)
            continue
        t = ((p2[0] - p1[0]) * d2[1] - (p2[1] - p1[1]) * d2[0]) / cr
        out.append((p1[0] + d1[0] * t, p1[1] + d1[1] * t))
    out.append((pts[-1][0] + nrm[-1][0] * o, pts[-1][1] + nrm[-1][1] * o))
    return out


def layout(lines, pos, rank, rides, shape):
    """Map paths for every line: {'id', 'closed', 'path', 'stops'}. [rank]
    breaks ties in the side-by-side order (earlier lines nearer the left);
    [shape] is the drawn way of each stretch (schematize)."""
    closed = {l['id']: l['loop'] for l in lines}

    def edges_of(lid):
        seq = rides[lid]
        e = list(zip(seq, seq[1:]))
        return e + ([(seq[-1], seq[0])] if closed[lid] else [])

    on_edge = {}
    for lid in rides:
        for a, b in edges_of(lid):
            on_edge.setdefault(frozenset((a, b)), [])
            if lid not in on_edge[frozenset((a, b))]:
                on_edge[frozenset((a, b))].append(lid)

    def follow(lid, u, v, forward):
        """Stations of line [lid] after v (riding u -> v), or before u."""
        seq, loop = rides[lid], closed[lid]
        n = len(seq)
        nxt = lambda i: (i + 1) % n if loop else i + 1  # noqa: E731
        prv = lambda i: (i - 1) % n if loop else i - 1  # noqa: E731
        i = next((i for i in range(n) if seq[i] == u and 0 <= nxt(i) < n and seq[nxt(i)] == v), None)
        step = 1
        if i is None:
            i = next(i for i in range(n) if seq[i] == u and 0 <= prv(i) < n and seq[prv(i)] == v)
            step = -1
        out = []
        j = i + 2 * step if forward else i - step
        while len(out) < n - 2:
            if loop:
                j %= n
            elif not 0 <= j < n:
                break
            out.append(seq[j])
            j += step if forward else -step
        return out

    def side(prev, at, nxt):
        """< 0: turning left at [at] (screen coordinates, y down)."""
        d = (pos[at][0] - pos[prev][0], pos[at][1] - pos[prev][1])
        e = (pos[nxt][0] - pos[at][0], pos[nxt][1] - pos[at][1])
        if d == (0, 0) or e == (0, 0):
            return 0
        d, e = _unit(d), _unit(e)
        return d[0] * e[1] - d[1] * e[0]

    def compare(u, v):
        def cmp(a, b):
            # Ahead: where they part, the one turning left keeps left.
            fa, fb = follow(a, u, v, True), follow(b, u, v, True)
            prev, at = u, v
            for x, y in zip(fa, fb):
                if x != y:
                    sa, sb = side(prev, at, x), side(prev, at, y)
                    if abs(sa - sb) > 1e-6:
                        return -1 if sa < sb else 1
                    break
                prev, at = at, x
            # Behind: where they joined, the one coming from the left keeps left.
            ba, bb = follow(a, u, v, False), follow(b, u, v, False)
            nxt, at = v, u
            for x, y in zip(ba, bb):
                if x != y:
                    sa, sb = side(x, at, nxt), side(y, at, nxt)
                    if abs(sa - sb) > 1e-6:
                        return -1 if sa < sb else 1
                    break
                nxt, at = at, x
            return -1 if rank[a] < rank[b] else 1
        return cmp

    order = {}
    for e, lids in on_edge.items():
        u, v = sorted(e)
        order[e] = sorted(lids, key=cmp_to_key(compare(u, v)))

    base = {}
    for e in on_edge:
        u, v = sorted(e)
        if e in shape:
            first, pts = shape[e]
            base[e] = list(pts) if first == u else list(pts)[::-1]
        else:
            base[e] = [pos[u]] + _octi(pos[u], pos[v])

    def offset_pts(lid, a, b):
        e = frozenset((a, b))
        u, v = sorted(e)
        lids = order[e]
        k = lids.index(lid)
        o = ((len(lids) - 1) / 2 - k) * SPACING
        pts = _offset(base[e], o)
        return pts if (a, b) == (u, v) else pts[::-1]

    out = []
    for l in lines:
        lid = l['id']
        stops_at = set(l['stations'])
        path, stops = [], {}
        edges = edges_of(lid)
        for i, (a, b) in enumerate(edges):
            pts = offset_pts(lid, a, b)
            if not path:
                path.append(pts[0])
            elif math.dist(path[-1], pts[0]) > 1e-6:
                path += _octi(path[-1], pts[0])
            if a in stops_at and a not in stops:
                stops[a] = pts[0]
            path += pts[1:]
            if b in stops_at and b not in stops and i == len(edges) - 1:
                stops[b] = pts[-1]
        if closed[lid] and math.dist(path[-1], path[0]) > 1e-6:
            path += _octi(path[-1], path[0])
        if closed[lid] and math.dist(path[-1], path[0]) <= 1e-6:
            path = path[:-1]
        clean = [path[0]]
        for p in path[1:]:
            if math.dist(p, clean[-1]) > 1e-6:
                clean.append(p)
        # drop points in the middle of a straight run
        simple = [clean[0]]
        for i in range(1, len(clean) - 1):
            a, b, c = simple[-1], clean[i], clean[i + 1]
            if abs((b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0])) > 1e-6:
                simple.append(b)
        if len(clean) > 1:
            simple.append(clean[-1])
        for sid in l['stations']:
            if sid not in stops:
                stops[sid] = pos[sid]
        out.append({'id': lid, 'closed': closed[lid], 'path': [[round(x, 2), round(y, 2)] for x, y in simple],
                    'stops': {sid: (round(p[0], 2), round(p[1], 2)) for sid, p in stops.items()}})
    return out
