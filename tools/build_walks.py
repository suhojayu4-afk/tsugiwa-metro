"""Walking transfers between stations with different names
(上野 ↔ 京成上野, 有楽町 ↔ 日比谷, …) → assets/cities/tokyo/walks.json.

1. Automatic: every pair of different stations closer than AUTO_METERS gets
   a walking transfer; minutes come from the distance.
2. Easy to change by hand: tools/data/walk_rules.json, with Japanese
   station names —
     "add":     [["上野", "京成上野", 5], …]      always connect (minutes)
     "remove":  [["新宿", "新宿西口"], …]         never connect
     "minutes": {"有楽町/日比谷": 3, …}           fix the minutes

  python tools/build_walks.py
"""
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CITY = os.path.join(ROOT, 'assets', 'cities', 'tokyo')
RULES = os.path.join(ROOT, 'tools', 'data', 'walk_rules.json')
AUTO_METERS = 450
WALK_M_PER_MIN = 100         # map distance per minute (real paths are longer, but often underground)

stations = json.load(open(os.path.join(CITY, 'stations.json'), encoding='utf8'))
by_ja = {s['name']['ja']: s for s in stations}
rules = json.load(open(RULES, encoding='utf8')) if os.path.exists(RULES) else {}


def meters(a, b):
    dy = (a['geo']['lat'] - b['geo']['lat']) * 111_000
    dx = (a['geo']['lng'] - b['geo']['lng']) * 91_000
    return math.hypot(dx, dy)


def station(name):
    s = by_ja.get(name)
    if s is None:
        raise SystemExit(f'walk_rules.json: unknown station 「{name}」')
    return s


def key(a, b):
    return tuple(sorted((a['id'], b['id'])))


walks = {}
for i, a in enumerate(stations):
    for b in stations[i + 1:]:
        if set(a['lines']) & set(b['lines']):
            continue                                  # already on the same line
        d = meters(a, b)
        if d <= AUTO_METERS:
            walks[key(a, b)] = max(3, math.ceil(d / WALK_M_PER_MIN) + 1)

for pair in rules.get('remove', []):
    walks.pop(key(station(pair[0]), station(pair[1])), None)
for a_name, b_name, minutes in rules.get('add', []):
    walks[key(station(a_name), station(b_name))] = minutes
for pair, minutes in rules.get('minutes', {}).items():
    a_name, b_name = pair.split('/')
    k = key(station(a_name), station(b_name))
    if k not in walks:
        raise SystemExit(f'walk_rules.json minutes: 「{pair}」 is not a walking transfer (add it first)')
    walks[k] = minutes

ids = {s['id']: s for s in stations}
out = [{'a': a, 'b': b, 'min': m, 'names': f"{ids[a]['name']['ja']} ↔ {ids[b]['name']['ja']}"}
       for (a, b), m in sorted(walks.items(), key=lambda kv: ids[kv[0][0]]['name']['ja'])]
json.dump(out, open(os.path.join(CITY, 'walks.json'), 'w', encoding='utf8'), ensure_ascii=False, indent=1)
print(len(out), 'walking transfers')
for w in out:
    print(f"  {w['names']}  {w['min']}分")
