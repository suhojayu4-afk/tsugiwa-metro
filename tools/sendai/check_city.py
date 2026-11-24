"""Sanity check of the built city data: long hops between neighbouring
stations (a station picked from the wrong place) and the station ids.

  python -X utf8 tools/<city>/check_city.py
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import conf  # noqa: E402

D = os.path.join(os.path.dirname(os.path.dirname(HERE)), 'assets', 'cities', conf.CITY)
st = {s['id']: s for s in json.load(open(os.path.join(D, 'stations.json'), encoding='utf8'))}
for l in json.load(open(os.path.join(D, 'lines.json'), encoding='utf8')):
    ids = l['stations'] + ([l['stations'][0]] if l['loop'] else [])
    for a, b in zip(ids, ids[1:]):
        ga, gb = st[a]['geo'], st[b]['geo']
        d = math.hypot((ga['lat'] - gb['lat']) * 111, (ga['lng'] - gb['lng']) * 91)
        if d > 3.2 or d < 0.25:
            print(f"{l['id']}: {a} -> {b} {d:.2f} km")
S, W, N, E = conf.GROUND
for s in st.values():
    g = s['geo']
    if not (S < g['lat'] < N and W < g['lng'] < E):
        print('outside the ground:', s['id'])
print(len(st), 'stations')
