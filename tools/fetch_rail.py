"""Download every passenger railway route (JR, private railways, subways,
monorails, AGT, trams) of the Tokyo area from OpenStreetMap, with the
stops in order, into tools/data/osm/rail_routes.json. build_rail.py turns
them into the app's stations / lines.

  python -X utf8 tools/fetch_rail.py

Area: Yokohama - Saitama (Omiya) - Narita - Mt. Takao.
Data (c) OpenStreetMap contributors, ODbL.
"""
import json
import os
import time
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'tools', 'data', 'osm', 'rail_routes.json')
URL = 'https://overpass-api.de/api/interpreter'
AREA = (35.30, 139.20, 36.02, 140.42)
B = '(%s,%s,%s,%s)' % AREA

Q = f"""[out:json][timeout:300];
rel["type"="route"]["route"~"^(train|subway|light_rail|monorail|tram)$"]{B}->.r;
.r out body;
rel(br.r)["type"="route_master"];
out body;
node(r.r);
out;
"""


def main():
    data = urllib.parse.urlencode({'data': Q}).encode()
    req = urllib.request.Request(URL, data=data, headers={'User-Agent': 'pixel-route-map-builder/1.0'})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=400) as r:
                res = json.load(r)
            break
        except Exception as e:
            print('  retry', attempt + 1, e)
            time.sleep(20 * (attempt + 1))
    else:
        raise SystemExit('Overpass failed')
    routes, masters, nodes = [], [], {}
    for e in res['elements']:
        if e['type'] == 'node':
            nodes[e['id']] = {'lat': round(e['lat'], 6), 'lng': round(e['lon'], 6), 'tags': e.get('tags', {})}
        elif e['tags'].get('type') == 'route_master':
            masters.append({'id': e['id'], 'tags': e['tags'],
                            'routes': [m['ref'] for m in e['members'] if m['type'] == 'relation']})
        else:
            routes.append({'id': e['id'], 'tags': e['tags'],
                           'stops': [[m['ref'], m['role']] for m in e['members']
                                     if m['type'] == 'node' and m['role'].startswith('stop')],
                           'platforms': [[m['type'], m['ref']] for m in e['members']
                                         if m['role'].startswith('platform')]})
    json.dump({'source': '(c) OpenStreetMap contributors, ODbL', 'area': AREA,
               'timestamp': res.get('osm3s', {}).get('timestamp_osm_base'),
               'routes': routes, 'masters': masters, 'nodes': nodes},
              open(OUT, 'w', encoding='utf8'), ensure_ascii=False, separators=(',', ':'))
    print(len(routes), 'routes,', len(masters), 'masters,', len(nodes), 'nodes')


if __name__ == '__main__':
    main()
