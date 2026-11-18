"""Build the Tokyo-area city data (stations.json, lines.json, timetables.json,
walks.json, city.json) from the hand-made base (tools/data/base_tokyo: the
first 23 lines, kept as they are) plus every line in tools/data/rail_lines.py,
whose stops come from OpenStreetMap route relations (tools/fetch_rail.py).

Names: OpenStreetMap name / name:en / name:ko / name:ja-Hira, then Wikidata
(tools/fetch_wikidata_rail.py), then a kana -> hangul / romaji spelling.
Run times and headways are estimates, like the rest of the data.

  python -X utf8 tools/build_rail.py

Data (c) OpenStreetMap contributors (ODbL), Wikidata (CC0).
"""
import json
import math
import os
import re
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CITY = os.path.join(ROOT, 'assets', 'cities', 'tokyo')
BASE = os.path.join(ROOT, 'tools', 'data', 'base_tokyo')
sys.path.insert(0, os.path.join(ROOT, 'tools', 'data'))
from rail_lines import LINES, THROUGH  # noqa: E402

AREA = (34.62, 138.15, 36.86, 141.00)   # all of Kanto (Izu to Shimoda, Fuji, Kofu, Takasaki, Nikko, Mito, Boso)
load = lambda d, n: json.load(open(os.path.join(d, n), encoding='utf8'))  # noqa: E731
stations = load(BASE, 'stations.json')
lines = load(BASE, 'lines.json')
timetables = load(BASE, 'timetables.json')
city = load(BASE, 'city.json')
walks = load(BASE, 'walks.json')
osm = json.load(open(os.path.join(ROOT, 'tools', 'data', 'osm', 'rail_routes.json'), encoding='utf8'))
wd = json.load(open(os.path.join(ROOT, 'tools', 'data', 'wikidata_rail.json'), encoding='utf8'))
ROUTES = {r['id']: r for r in osm['routes']}
_tracks = os.path.join(ROOT, 'tools', 'data', 'osm', 'rail_tracks.json')
TRACKS = json.load(open(_tracks, encoding='utf8')) if os.path.exists(_tracks) else {}
NODES = osm['nodes']

# Different spellings of one station.
ALIAS = {'新線新宿': '新宿', 'モノレール浜松町': '浜松町', 'リゾートゲートウェイ・ステーション': 'リゾートゲートウェイ',
         '東京ディズニーランド・ステーション': '東京ディズニーランド', '東京ディズニーシー・ステーション': '東京ディズニーシー',
         'ベイサイド・ステーション': 'ベイサイド'}


def norm(ja):
    ja = ja.strip().replace('ヶ', 'ケ').replace('ヵ', 'カ').replace('　', ' ')
    ja = re.sub(r'[〈（(].*[〉）)]$', '', ja).strip()
    ja = ja[:-1] if ja.endswith('駅') and len(ja) > 2 else ja
    return ALIAS.get(ja, ja).replace('ヶ', 'ケ')


def display(ja):
    ja = re.sub(r'\s*[〈（(].*[〉）)]$', '', ja.strip())
    ja = ja[:-1] if ja.endswith('駅') and len(ja) > 2 else ja
    return ALIAS.get(ja, ja)


def km(a, b):
    return math.hypot((a[0] - b[0]) * 111.0, (a[1] - b[1]) * 90.9)


def inside(lat, lng):
    return AREA[0] <= lat <= AREA[2] and AREA[1] <= lng <= AREA[3]


# ---------- kana spelling ----------
_K2H = {chr(c): chr(c - 0x60) for c in range(0x30A1, 0x30F7)}


def hira(s):
    return ''.join(_K2H.get(c, c) for c in s)


# Hangul for Japanese kana (Korean standard: unaspirated at the start of a word, aspirated inside; long vowels not written).
_V = {'a': 'ㅏ', 'i': 'ㅣ', 'u': 'ㅜ', 'e': 'ㅔ', 'o': 'ㅗ', 'ya': 'ㅑ', 'yu': 'ㅠ', 'yo': 'ㅛ', 'wa': 'ㅘ'}
_ROMA = {}
for row, cons in (('あいうえお', ''), ('かきくけこ', 'k'), ('さしすせそ', 's'), ('たちつてと', 't'), ('なにぬねの', 'n'),
                  ('はひふへほ', 'h'), ('まみむめも', 'm'), ('らりるれろ', 'r'), ('がぎぐげご', 'g'), ('ざじずぜぞ', 'z'),
                  ('だぢづでど', 'd'), ('ばびぶべぼ', 'b'), ('ぱぴぷぺぽ', 'p')):
    for ch, v in zip(row, 'aiueo'):
        _ROMA[ch] = cons + v
_ROMA.update({'し': 'shi', 'ち': 'chi', 'つ': 'tsu', 'ふ': 'fu', 'じ': 'ji', 'ぢ': 'ji', 'づ': 'zu', 'や': 'ya', 'ゆ': 'yu',
              'よ': 'yo', 'わ': 'wa', 'を': 'o', 'ゐ': 'i', 'ゑ': 'e', 'ゔ': 'vu'})
_SMALL = {'ゃ': 'ya', 'ゅ': 'yu', 'ょ': 'yo', 'ぁ': 'a', 'ぃ': 'i', 'ぅ': 'u', 'ぇ': 'e', 'ぉ': 'o'}


def syllables(h):
    """Kana -> list of romaji syllables ('n' for ん, 'Q' for っ, '-' for a long mark)."""
    out, i = [], 0
    while i < len(h):
        c = h[i]
        nxt = h[i + 1] if i + 1 < len(h) else ''
        if c == 'ん':
            out.append('N')
        elif c == 'っ':
            out.append('Q')
        elif c == 'ー':
            out.append('-')
        elif c in _ROMA:
            r = _ROMA[c]
            if nxt in _SMALL:
                s = _SMALL[nxt]
                if s.startswith('y'):
                    r = r[:-1] + s[1] if r in ('shi', 'chi', 'ji') else r[:-1] + s
                else:
                    r = r[:-1] + s
                i += 1
            out.append(r)
        elif c in (' ', '・', '　'):
            out.append(' ')
        i += 1
    return out


def romaji(h):
    syl, out = syllables(hira(h)), ''
    for i, s in enumerate(syl):
        nxt = syl[i + 1] if i + 1 < len(syl) else ''
        if s == 'N':
            out += 'n'
        elif s == 'Q':
            out += ('t' if nxt.startswith('ch') else nxt[:1]) if nxt and nxt[0] not in 'aiueo' else ''
        elif s == '-':
            continue
        elif s in ('u', 'o') and out and out[-1] in 'o' and s == 'u':
            continue  # とう -> to
        elif s == 'u' and out.endswith('u'):
            continue  # ゅう -> yu
        else:
            out += s
    out = out.replace('ou', 'o').replace('oo', 'o').replace('uu', 'u')
    return ' '.join(w.capitalize() for w in out.split(' ') if w)


_INIT = {'': 'ㅇ', 'k': 'ㄱ', 'g': 'ㄱ', 's': 'ㅅ', 'sh': 'ㅅ', 'z': 'ㅈ', 'j': 'ㅈ', 't': 'ㄷ', 'd': 'ㄷ', 'ch': 'ㅈ',
         'ts': 'ㅆ', 'n': 'ㄴ', 'h': 'ㅎ', 'f': 'ㅎ', 'b': 'ㅂ', 'p': 'ㅍ', 'm': 'ㅁ', 'r': 'ㄹ', 'y': 'ㅇ', 'w': 'ㅇ'}
_MID = {'k': 'ㅋ', 't': 'ㅌ', 'ch': 'ㅊ'}   # aspirated inside a word
_CHO = 'ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ'
_JUNG = 'ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ'
_JONG = ['', 'ㄱ', 'ㄲ', 'ㄳ', 'ㄴ', 'ㄵ', 'ㄶ', 'ㄷ', 'ㄹ', 'ㄺ', 'ㄻ', 'ㄼ', 'ㄽ', 'ㄾ', 'ㄿ', 'ㅀ', 'ㅁ', 'ㅂ', 'ㅄ', 'ㅅ', 'ㅆ',
         'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ']


def _block(cho, jung, jong=''):
    return chr(0xAC00 + (_CHO.index(cho) * 21 + _JUNG.index(jung)) * 28 + _JONG.index(jong))


def hangul(h):
    syl = syllables(hira(h))
    out, start, prev_vowel = [], True, ''
    for s in syl:
        if s == ' ':
            out.append(' ')
            start = True
            continue
        if s == 'N' or s == 'Q':
            if out and out[-1] != ' ':
                code = ord(out[-1]) - 0xAC00
                if 0 <= code < 11172 and code % 28 == 0:
                    out[-1] = chr(ord(out[-1]) + _JONG.index('ㄴ' if s == 'N' else 'ㅅ'))
            continue
        if s == '-':
            continue
        m = re.match(r'^(ts|sh|ch|[kgszjtdnhfbpmrywv]?)(y?)([aiueo])$', s)
        if not m:
            continue
        cons, y, v = m.groups()
        if cons == 'y':
            cons, y = '', 'y'
        # Long vowels are not written: おう / おお / うう.
        if cons == '' and not y and ((v == 'u' and prev_vowel in ('o', 'u')) or (v == 'o' and prev_vowel == 'o')):
            continue
        vowel = {'a': 'ㅏ', 'i': 'ㅣ', 'u': 'ㅜ', 'e': 'ㅔ', 'o': 'ㅗ'}[v]
        if (y or cons == 'sh') and v in 'auo':
            vowel = {'a': 'ㅑ', 'u': 'ㅠ', 'o': 'ㅛ'}[v]      # きょ 쿄, しゃ 샤 (じゃ 자, ちゅ 추 stay plain)
        if cons in ('s', 'z', 'ts') and v == 'u':
            vowel = 'ㅡ'                                     # す 스, ず 즈, つ 쓰
        if cons == 'w' and v == 'a':
            vowel = 'ㅘ'
        cho = _INIT[cons] if start or cons not in _MID else _MID[cons]
        out.append(_block(cho, vowel))
        start, prev_vowel = False, v
    return ''.join(out).strip()


# ---------- Wikidata names ----------
WD = {}
for q, s in wd['stations'].items():
    if 'ja' in s and 'lat' in s:
        WD.setdefault(norm(s['ja']), []).append(s)


OSM_NAMES = {}
for _n in NODES.values():
    _t = _n['tags']
    if 'name' in _t:
        _o = OSM_NAMES.setdefault(norm(_t['name']), {})
        for _k in ('name:ko', 'name:en', 'name:ja-Hira'):
            if _k in _t and _k not in _o:
                _o[_k] = _t[_k]
KO_FIX = {'町田': '마치다', '荒川遊園地前': '아라카와유엔치마에', '東池袋四丁目': '히가시이케부쿠로욘초메',
          '静': '시즈', '旭': '아사히', '岳南江尾': '가쿠난에노오', '神谷': '가미야', '岳南富士岡': '가쿠난후지오카',
          '比奈': '히나', '岳南原田': '가쿠난하라다', '吉原本町': '요시와라혼초', '滝': '다키',
          '鬼怒川公園': '기누가와코엔', '新藤原': '신후지와라', '日光': '닛코', '茂木': '모테기'}


def wd_near(key, lat, lng):
    c = [s for s in WD.get(key, []) if km((s['lat'], s['lng']), (lat, lng)) < 2.0]
    return c[0] if c else {}


def clean_ko(ko):
    ko = re.sub(r'\s*\(.*\)$', '', ko).strip()
    return ko[:-1].strip() if ko.endswith('역') and len(ko) > 2 else ko


def clean_en(en):
    en = re.sub(r'\s+Station$', '', en, flags=re.I)
    en = re.sub(r'\s*[(（].*[)）]$', '', en)
    return unicodedata.normalize('NFKD', en).encode('ascii', 'ignore').decode().strip()


# ---------- stations ----------
by_key = {}
for s in stations:
    by_key.setdefault(norm(s['name']['ja']), []).append(s)
ids = {s['id'] for s in stations}


def slug(en):
    s = re.sub(r'[^a-z0-9]+', '_', clean_en(en).lower()).strip('_')
    return 'tokyo.' + s


def station_for(name, lat, lng, tags, line_key):
    """The station record for a stop: an existing one with the same name
    close by, or a new one."""
    key = norm(name)
    for s in by_key.get(key, []):
        if km((s['geo']['lat'], s['geo']['lng']), (lat, lng)) < 1.3:
            return s
    w = wd_near(key, lat, lng)
    tags = {**OSM_NAMES.get(key, {}), **tags}
    kana = hira(tags.get('name:ja-Hira') or tags.get('name:ja-Kana') or tags.get('name:ja_kana') or w.get('kana', ''))
    kana = kana[:-2] if kana.endswith('えき') else kana
    en = clean_en(tags.get('name:en') or w.get('en') or (romaji(kana) if kana else name))
    ko = clean_ko(KO_FIX.get(key) or tags.get('name:ko') or w.get('ko') or (hangul(kana) if kana else ''))
    sid = slug(en)
    if sid in ids or sid == 'tokyo.':
        sid = f'{sid}_{line_key}'
    n = 2
    while sid in ids:
        sid, n = f'{sid}_{n}', n + 1
    ids.add(sid)
    rec = {'id': sid, 'name': {'ja': display(name), 'ko': ko, 'en': en}, 'kana': kana,
           'geo': {'lat': round(lat, 5), 'lng': round(lng, 5)}, 'lines': [], 'underground': []}
    stations.append(rec)
    by_key.setdefault(key, []).append(rec)
    return rec


def stops_of(rid):
    out = []
    for nid, role in ROUTES[rid]['stops']:
        n = NODES.get(str(nid))
        if not n or 'name' not in n['tags']:
            continue
        nm = n['tags']['name']
        if nm.endswith('信号場') or nm.endswith('信号所'):   # signal boxes, no passengers
            continue
        if out and norm(out[-1][0]) == norm(nm):
            continue
        out.append((nm, n['lat'], n['lng'], n['tags']))
    return out


def union(seqs):
    """All stops of several route relations (OSM lists them out of order
    now and then), one per station name."""
    seen, out = set(), []
    for seq in seqs:
        for x in seq:
            k = norm(x[0])
            if k not in seen:
                seen.add(k)
                out.append(x)
    return out


def order(pts, loop=False, given=(), ends=None):
    """Stops in running order: the shortest path through all of them, ends
    free (nearest neighbour from every start, then 2-opt). A railway line
    hardly doubles back, so this is its real order."""
    n = len(pts)
    if n < 3:
        return pts
    D = [[km(p[1:3], q[1:3]) for q in pts] for p in pts]

    def length(t):
        return sum(D[t[i]][t[i + 1]] for i in range(n - 1)) + (D[t[-1]][t[0]] if loop else 0)

    def two_opt(t):
        better = True
        while better:
            better = False
            for i in range(0, n - 1):
                for j in range(i + 1, n):
                    if loop and i == 0:
                        continue
                    a0 = D[t[i - 1]][t[i]] if (i > 0 or loop) else 0
                    b0 = D[t[j]][t[(j + 1) % n]] if (j < n - 1 or loop) else 0
                    a1 = D[t[i - 1]][t[j]] if (i > 0 or loop) else 0
                    b1 = D[t[i]][t[(j + 1) % n]] if (j < n - 1 or loop) else 0
                    if a1 + b1 < a0 + b0 - 1e-9:
                        t[i:j + 1] = t[i:j + 1][::-1]
                        better = True
        return t

    if ends:
        # Fixed first and last stop (a line whose ends are close together).
        ia, ib = [next(k for k, p in enumerate(pts) if norm(p[0]) == norm(e)) for e in ends]
        t, rest = [ia], set(range(n)) - {ia, ib}
        while rest:
            k = min(rest, key=lambda r: D[t[-1]][r])
            rest.remove(k)
            t.append(k)
        t.append(ib)
        better = True
        while better:
            better = False
            for i in range(1, n - 2):
                for j in range(i + 1, n - 1):
                    if D[t[i - 1]][t[j]] + D[t[i]][t[j + 1]] < D[t[i - 1]][t[i]] + D[t[j]][t[j + 1]] - 1e-9:
                        t[i:j + 1] = t[i:j + 1][::-1]
                        better = True
        return [pts[k] for k in t]
    best = None
    for start in range(n):
        t, rest = [start], set(range(n)) - {start}
        while rest:
            k = min(rest, key=lambda r: D[t[-1]][r])
            rest.remove(k)
            t.append(k)
        t = two_opt(t)
        if best is None or length(t) < length(best) - 1e-9:
            best = t[:]
    # OSM's own order (with missing stops put in where they cost least) wins
    # when it is about as short: lines that hook round (Tokyo - Kanda -
    # Ochanomizu - Yotsuya) are shorter in a wrong order.
    for g in given:
        idx = {norm(p[0]): k for k, p in enumerate(pts)}
        t = [idx[norm(x[0])] for x in g if norm(x[0]) in idx]
        t = list(dict.fromkeys(t))
        for k in range(n):
            if k not in t:
                pos = min(range(len(t) + 1), key=lambda m: (D[t[m - 1]][k] if m > 0 else 0)
                          + (D[k][t[m]] if m < len(t) else 0) - (D[t[m - 1]][t[m]] if 0 < m < len(t) else 0))
                t.insert(pos, k)
        if length(t) <= length(best) * 1.12:
            return [pts[k] for k in t]
    return [pts[k] for k in best]


SPEED = {'jr': 17.0, 'jr_local': 13.0, 'jr_branch': 14.0, 'private': 13.5, 'private_branch': 12.0, 'subway': 11.5,
         'agt': 9.0, 'tram': 5.5}
HEADWAY = {'jr': (10, 5, 10, 7, 15), 'jr_local': (5, 3, 4, 3, 6), 'jr_branch': (15, 10, 15, 12, 20),
           'private': (6, 3, 5, 4, 8), 'private_branch': (10, 6, 10, 8, 15), 'subway': (5, 3, 5, 4, 7),
           'agt': (8, 4, 6, 5, 10), 'tram': (8, 6, 7, 6, 10)}
GROUP = {'jr': 'jr', 'jr_local': 'jr', 'jr_branch': 'jr'}


def group_of(key, kind):
    for prefix, g in (('tokyu', 'tokyu'), ('odakyu', 'odakyu'), ('keio', 'keio'), ('seibu', 'seibu'),
                      ('tobu', 'tobu'), ('keisei', 'keisei'), ('hokuso', 'keisei'), ('keikyu', 'keikyu'),
                      ('sotetsu', 'sotetsu'), ('yokohama_', 'yokohama'), ('minatomirai', 'yokohama'),
                      ('seaside', 'yokohama')):
        if key.startswith(prefix):
            return g
    return GROUP.get(kind, 'other')


added = []
for spec in LINES:
    sources = [stops_of(r) for r in spec['routes']]
    if spec.get('tracks'):
        # Lines without an OSM route: the stations along their named tracks.
        sources.append([(t['name'], t['lat'], t['lng'], t['tags']) for t in TRACKS.get(spec['tracks'], [])])
    sources.append([(n, la, ln, {}) for n, la, ln in spec.get('extra', [])])
    seq = [x for x in union(sources) if inside(x[1], x[2]) and norm(x[0]) not in spec['drop']]
    seq = order(seq, spec['loop'], [stops_of(r) for r in spec['routes']], spec['ends'])
    names = [norm(x[0]) for x in seq]
    a, b = spec['cut']
    ia = names.index(norm(a)) if a else 0
    ib = names.index(norm(b)) if b else len(seq) - 1
    seq = seq[min(ia, ib):max(ia, ib) + 1]
    gaps = [km(seq[i][1:3], seq[i + 1][1:3]) for i in range(len(seq) - 1)]
    if gaps and len(gaps) > 3:
        med = sorted(gaps)[len(gaps) // 2]
        for i, g_ in enumerate(gaps):
            if g_ > max(4.0, 3.5 * med):
                print(f"   ! {spec['key']}: {seq[i][0]} -> {seq[i + 1][0]} {g_:.1f} km")
    lid = spec['replace'] or f"tokyo.{spec['key']}"
    recs = []
    for nm, lat, lng, tags in seq:
        r = station_for(nm, lat, lng, tags, spec['key'])
        if recs and recs[-1] is r:
            continue
        recs.append(r)

    def named(n, near):
        c = [s for s in by_key.get(norm(n), []) if km((s['geo']['lat'], s['geo']['lng']), near) < 30]
        if not c:
            raise SystemExit(f'{spec["key"]}: no station {n}')
        return min(c, key=lambda s: km((s['geo']['lat'], s['geo']['lng']), near))

    for n in reversed(spec['pre']):
        recs.insert(0, named(n, (recs[0]['geo']['lat'], recs[0]['geo']['lng'])))
    for n in spec['post']:
        recs.append(named(n, (recs[-1]['geo']['lat'], recs[-1]['geo']['lng'])))
    if spec['loop'] and recs[0] is recs[-1]:
        recs = recs[:-1]
    kind = spec['kind']
    for r in recs:
        if lid not in r['lines']:
            r['lines'].append(lid)
        if kind == 'subway' and lid not in r['underground']:
            r['underground'].append(lid)
    loop = spec['loop']
    pairs = list(zip(recs, recs[1:])) + ([(recs[-1], recs[0])] if loop else [])
    g = lambda r: (r['geo']['lat'], r['geo']['lng'])  # noqa: E731
    run_sec = [max(60, round((30 + km(g(x), g(y)) * 1000 / SPEED[kind]) / 5) * 5) for x, y in pairs]
    first, last = recs[0]['name'], recs[-1]['name']
    line = {
        'id': lid, 'name': {'ja': spec['ja'], 'ko': spec['ko'], 'en': spec['en']}, 'color': spec['color'],
        'loop': loop, 'dwellSec': 30 if kind.startswith('jr') else 25, 'group': group_of(spec['key'], kind),
        'directions': {
            'forward': {'ja': f"{last['ja']}方面", 'ko': f"{last['ko']} 방면", 'en': f"for {last['en']}"},
            'reverse': {'ja': f"{first['ja']}方面", 'ko': f"{first['ko']} 방면", 'en': f"for {first['en']}"},
        } if not loop else {
            'forward': {'ja': '右回り', 'ko': '시계 방향', 'en': 'Clockwise'},
            'reverse': {'ja': '左回り', 'ko': '반시계 방향', 'en': 'Counterclockwise'},
        },
        'stations': [r['id'] for r in recs], 'runSec': run_sec,
    }
    if spec['replace']:
        old = next(l for l in lines if l['id'] == lid)
        # Stations that were only on the old, shorter version keep nothing of it.
        for s in stations:
            if lid in s['lines'] and s['id'] not in line['stations']:
                s['lines'].remove(lid)
                if lid in s['underground']:
                    s['underground'].remove(lid)
        lines[lines.index(old)] = line
    else:
        lines.append(line)
        added.append(lid)
    early, rush, day, evening, night = HEADWAY[kind]
    if lid not in timetables or spec['replace']:
        timetables[lid] = {
            'firstTrain': '04:50' if kind.startswith('jr') else '05:00',
            'lastTrain': '24:30' if kind not in ('jr_branch', 'private_branch', 'tram') else '23:30',
            'weekday': [
                {'from': '04:30', 'to': '07:00', 'everyMin': early},
                {'from': '07:00', 'to': '09:30', 'everyMin': rush},
                {'from': '09:30', 'to': '17:00', 'everyMin': day},
                {'from': '17:00', 'to': '20:00', 'everyMin': evening},
                {'from': '20:00', 'to': '25:00', 'everyMin': night}],
            'holiday': [
                {'from': '04:30', 'to': '09:00', 'everyMin': early},
                {'from': '09:00', 'to': '21:00', 'everyMin': day},
                {'from': '21:00', 'to': '25:00', 'everyMin': night}],
        }
    print(f"{lid:34s} {len(recs):3d}  {recs[0]['name']['ja']} ~ {recs[-1]['name']['ja']}")

# Groups for the first lines (hand-made).
BASE_GROUP = {'tokyo.yamanote': 'jr', 'tokyo.narita_express': 'jr', 'tokyo.keio': 'keio', 'tokyo.skyliner': 'keisei',
              'tokyo.access_express': 'keisei'}
for l in lines:
    if 'group' not in l:
        l['group'] = BASE_GROUP.get(l['id'], 'toei' if 'toei' in l['id'] else 'metro')
# Old station records nobody uses any more (only on the shortened lines).
used = {s for l in lines for s in l['stations']}
stations = [s for s in stations if s['id'] in used]

# On foot between nearby stations with different names (上野 ↔ 京成上野, 新宿 ↔ 西武新宿).
known = {frozenset((w['a'], w['b'])) for w in walks}
geo = {s['id']: (s['geo']['lat'], s['geo']['lng']) for s in stations}
st_list = sorted(stations, key=lambda s: s['geo']['lng'])
for i, a in enumerate(st_list):
    for b in st_list[i + 1:]:
        if (b['geo']['lng'] - a['geo']['lng']) * 90.9 > 0.45:
            break
        d = km(geo[a['id']], geo[b['id']])
        if d > 0.40 or frozenset((a['id'], b['id'])) in known or set(a['lines']) & set(b['lines']):
            continue
        walks.append({'a': a['id'], 'b': b['id'], 'min': max(2, round(d * 1000 / 70) + 2),
                      'names': f"{a['name']['ja']} ↔ {b['name']['ja']}"})
        known.add(frozenset((a['id'], b['id'])))

# Through trains (rail_lines.THROUGH): where a train runs on from one line
# onto another without anyone changing, with the direction it carries on in.
line_by_id = {l['id']: l for l in lines}
st_name = {s['id']: s['name']['ja'] for s in stations}


def _at(lid, name):
    hit = [sid for sid in line_by_id[lid]['stations'] if norm(st_name[sid]) == norm(name)]
    if not hit:
        raise SystemExit(f'through: {name} is not on {lid}')
    return hit[0]


def _next_to(lid, sid, name):
    seq = line_by_id[lid]['stations']
    i = seq.index(sid)
    nb = [seq[j] for j in (i - 1, i + 1) if 0 <= j < len(seq)]
    if line_by_id[lid]['loop']:
        nb = [seq[(i - 1) % len(seq)], seq[(i + 1) % len(seq)]]
    if name is None:
        if len(nb) != 1:
            raise SystemExit(f'through: {st_name[sid]} is not an end of {lid}; give the previous station')
        return nb[0]
    hit = [x for x in nb if norm(st_name[x]) == norm(name)]
    if not hit:
        raise SystemExit(f'through: {name} is not next to {st_name[sid]} on {lid}')
    return hit[0]


def _lid(key):
    return next(sp['replace'] for sp in LINES if sp['key'] == key and sp['replace'])         if any(sp['key'] == key and sp['replace'] for sp in LINES) else f'tokyo.{key}'


through = []
for a_key, at_name, b_key, toward, prev in THROUGH:
    a, b = _lid(a_key), _lid(b_key)
    at_a, at_b = _at(a, at_name), _at(b, at_name)
    assert at_a == at_b, (a_key, b_key, at_name)
    nxt = _next_to(b, at_b, toward)
    back = _next_to(a, at_a, prev)
    through.append({'a': a, 'at': at_a, 'b': b, 'toward': nxt})
    through.append({'a': b, 'at': at_a, 'b': a, 'toward': back})
print(len(through), 'through runs (both ways)')

# Different stations with the same name (栄町 in Chiba and in Kita ward):
# add the place in brackets, like the transit apps do - 栄町（千葉市）.
_areas_f = os.path.join(ROOT, 'tools', 'data', 'osm', 'station_areas.json')
_areas = json.load(open(_areas_f, encoding='utf8'))['areas'] if os.path.exists(_areas_f) else {}
_by_name = {}
for s_ in stations:
    _by_name.setdefault(s_['name']['ja'], []).append(s_)
for name, same in _by_name.items():
    if len(same) < 2:
        continue
    # The best-known one (most lines, then nearest central Tokyo) keeps the plain name.
    same.sort(key=lambda s_: (-len(s_['lines']), km((s_['geo']['lat'], s_['geo']['lng']), (35.681, 139.767))))
    for s_ in same[1:]:
        ward = _areas.get(s_['id'], {}).get('ward')
        line0 = next(l for l in lines if l['id'] == s_['lines'][0])['name']
        if not ward or ward['ja'] == name:
            ward = line0            # 小川町 in 小川町 town: name the line instead
        s_['name']['ja'] += f"（{ward['ja']}）"
        s_['name']['ko'] += f" ({ward.get('ko') or ward['ja']})"
        s_['name']['en'] += f" ({ward.get('en') or ward['ja']})"
        print('   same name:', s_['name']['ja'], '/', s_['name']['ko'])

allids = [s['id'] for s in stations]
assert len(allids) == len(set(allids))
missing_ko = [s['name']['ja'] for s in stations if not s['name']['ko']]
assert not missing_ko, missing_ko
city['lines'] = [l['id'] for l in lines]
city['dataNote'] = ('Stations and lines: OpenStreetMap contributors (ODbL) and Wikidata (CC0). Run times and '
                    'headways are approximate estimates. Replace with licensed timetable data later.')
dump = lambda obj, name: json.dump(obj, open(os.path.join(CITY, name), 'w', encoding='utf8'), ensure_ascii=False, indent=1)  # noqa: E731
dump(stations, 'stations.json')
dump(lines, 'lines.json')
dump(timetables, 'timetables.json')
dump(city, 'city.json')
dump(walks, 'walks.json')
dump(through, 'through.json')
print(len(stations), 'stations,', len(lines), 'lines,', len(walks), 'walks')
