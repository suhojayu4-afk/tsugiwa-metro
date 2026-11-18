"""Make a layer file from the pieces fetch_osm.py did get (tools/data/osm/_cache)
plus an older, smaller download of the same layer, when Overpass will not
send the rest (busy server, a tile too heavy).

  python -X utf8 tools/merge_osm_cache.py landuse tools/data/osm_old/landuse.json

Data (c) OpenStreetMap contributors, ODbL.
"""
import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import fetch_osm  # noqa: E402

name, old = sys.argv[1], sys.argv[2]
body = fetch_osm.LAYERS[name]
# A piece belongs to this layer when its query holds the layer's text (any tile box).
key = body.split(fetch_osm.B)[0]
elements, seen = [], set()
for f in glob.glob(os.path.join(fetch_osm.OUT, '_cache', '*.json')):
    res = json.load(open(f, encoding='utf8'))
    q = res.get('osm3s', {}).get('query') or ''
    els = res.get('elements', [])
    tags_ok = any(k in json.dumps(e.get('tags', {}), ensure_ascii=False)
                  for e in els[:50] for k in (['motorway', 'trunk'] if name == 'motorways' else
                                             ['commercial', 'retail', 'industrial', 'port', 'railway']))
    if not tags_ok:
        continue
    for e in els:
        if e['type'] in ('way', 'relation') and (e['type'], e['id']) not in seen:
            seen.add((e['type'], e['id']))
            elements.append(e)
feats = [fetch_osm.convert(e) for e in elements]
feats = [f for f in feats if f['outer'] and any(len(r) > 1 for r in f['outer'])]
ids = {f['id'] for f in feats}
older = [f for f in json.load(open(old, encoding='utf8'))['features'] if f['id'] not in ids]
json.dump({'source': '(c) OpenStreetMap contributors, ODbL', 'bbox': fetch_osm.BBOX, 'features': feats + older},
          open(os.path.join(fetch_osm.OUT, name + '.json'), 'w', encoding='utf8'), ensure_ascii=False,
          separators=(',', ':'))
print(name, len(feats), 'new +', len(older), 'from the older file')
