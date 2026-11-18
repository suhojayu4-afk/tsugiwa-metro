"""Every railway station of the Tokyo area from Wikidata (CC0) with its
neighbours on each line (P197 adjacent station + P81 line qualifier),
names (ja / en / ko / kana) and coordinates; plus the lines' names,
colours and operators. Saved to tools/data/wikidata_rail.json for
build_rail.py.

  python -X utf8 tools/fetch_wikidata_rail.py
"""
import json
import re
import os
import time
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'tools', 'data', 'wikidata_rail.json')
URL = 'https://query.wikidata.org/sparql'
SW, NE = (139.20, 35.30), (140.42, 36.02)

BOX = f'''SERVICE wikibase:box {{ ?st wdt:P625 ?loc .
  bd:serviceParam wikibase:cornerSouthWest "Point({SW[0]} {SW[1]})"^^geo:wktLiteral ;
                  wikibase:cornerNorthEast "Point({NE[0]} {NE[1]})"^^geo:wktLiteral . }}'''

Q_ADJ = f'''SELECT ?st ?loc ?adj ?line WHERE {{ {BOX}
  ?st p:P197 ?s . ?s ps:P197 ?adj . OPTIONAL {{ ?s pq:P81 ?line }}
  FILTER NOT EXISTS {{ ?st wdt:P576 ?end }} }}'''

Q_NAMES = '''SELECT ?it ?ja ?en ?ko ?kana ?loc WHERE {{ VALUES ?it {{ {ids} }}
  OPTIONAL {{ ?it rdfs:label ?ja FILTER(lang(?ja)="ja") }}
  OPTIONAL {{ ?it rdfs:label ?en FILTER(lang(?en)="en") }}
  OPTIONAL {{ ?it rdfs:label ?ko FILTER(lang(?ko)="ko") }}
  OPTIONAL {{ ?it wdt:P1814 ?kana }}
  OPTIONAL {{ ?it wdt:P625 ?loc }} }}'''

Q_LINES = '''SELECT ?it ?ja ?en ?ko ?color ?op ?opja ?type ?ended WHERE {{ VALUES ?it {{ {ids} }}
  OPTIONAL {{ ?it rdfs:label ?ja FILTER(lang(?ja)="ja") }}
  OPTIONAL {{ ?it rdfs:label ?en FILTER(lang(?en)="en") }}
  OPTIONAL {{ ?it rdfs:label ?ko FILTER(lang(?ko)="ko") }}
  OPTIONAL {{ ?it wdt:P465 ?color }}
  OPTIONAL {{ ?it wdt:P137 ?op . OPTIONAL {{ ?op rdfs:label ?opja FILTER(lang(?opja)="ja") }} }}
  OPTIONAL {{ ?it wdt:P31 ?type }}
  OPTIONAL {{ ?it wdt:P576 ?ended }} }}'''


def sparql(q):
    data = urllib.parse.urlencode({'query': q, 'format': 'json'}).encode()
    req = urllib.request.Request(URL, data=data, headers={
        'User-Agent': 'pixel-route-map-builder/1.0 (offline data build)', 'Accept': 'application/sparql-results+json'})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                return json.load(r)['results']['bindings']
        except Exception as e:
            print('  retry', attempt + 1, e)
            time.sleep(10 * (attempt + 1))
    raise SystemExit('Wikidata failed')


def qid(v):
    return v['value'].rsplit('/', 1)[1]


def point(v):
    m = re.search(r'Point\(([-\d.eE]+) ([-\d.eE]+)\)', v['value'])
    if not m:
        return None
    lng, lat = m.groups()
    return round(float(lat), 6), round(float(lng), 6)


def chunks(ids, n=300):
    ids = sorted(ids)
    for i in range(0, len(ids), n):
        yield ' '.join('wd:' + x for x in ids[i:i + n])


def main():
    rows = sparql(Q_ADJ)
    print(len(rows), 'adjacency rows')
    adj = {}
    for r in rows:
        st = qid(r['st'])
        adj.setdefault(st, set()).add((qid(r['adj']), qid(r['line']) if 'line' in r else None))
    items = set(adj) | {a for v in adj.values() for a, _ in v}
    lines = {l for v in adj.values() for _, l in v if l}
    stations = {}
    for ids in chunks(items):
        for r in sparql(Q_NAMES.format(ids=ids)):
            s = stations.setdefault(qid(r['it']), {})
            for k in ('ja', 'en', 'ko', 'kana'):
                if k in r:
                    s[k] = r[k]['value']
            p = point(r['loc']) if 'loc' in r and 'lat' not in s else None
            if p:
                s['lat'], s['lng'] = p
        time.sleep(1)
    linfo = {}
    for ids in chunks(lines):
        for r in sparql(Q_LINES.format(ids=ids)):
            s = linfo.setdefault(qid(r['it']), {'types': [], 'ops': []})
            for k in ('ja', 'en', 'ko', 'color'):
                if k in r:
                    s[k] = r[k]['value']
            if 'ended' in r:
                s['ended'] = True
            if 'type' in r and qid(r['type']) not in s['types']:
                s['types'].append(qid(r['type']))
            if 'opja' in r and r['opja']['value'] not in s['ops']:
                s['ops'].append(r['opja']['value'])
        time.sleep(1)
    json.dump({'source': 'Wikidata (CC0)', 'box': [SW, NE],
               'adjacent': {k: sorted(([a, l] for a, l in v), key=lambda x: (x[0], x[1] or '')) for k, v in adj.items()},
               'stations': stations, 'lines': linfo},
              open(OUT, 'w', encoding='utf8'), ensure_ascii=False, separators=(',', ':'))
    print(len(adj), 'stations in box,', len(stations), 'named,', len(linfo), 'lines')


if __name__ == '__main__':
    main()
