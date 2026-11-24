"""Real Tottori timetables, train by train, from JR おでかけネット's 区間時刻表
(line-timetable pages; 若桜鉄道 and 智頭急行 are on them too).

  python tools/tottori/fetch_timetables.py [weekday-date holiday-date]
      ->  assets/cities/tottori/trains.json

Each page lists every train of one direction for the given date; a train is
split into one run per app line it rides (a 上郡 → 鳥取 train = 智頭急行 +
因美線). Limited expresses go to their own app lines by name.

trains.json: {lineId: {"weekday": [run], "holiday": [run]}}, run =
{"no": "1631D", "kind": "普通", "name": "", "to": "境港",
 "stops": [[stationId, arriveMin, departMin], ...]} with minutes after
midnight of the service day (00:30 = 1470).
"""
import html
import json
import os
import re
import sys
import time
import unicodedata
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
CITY = os.path.join(ROOT, 'assets', 'cities', 'tottori')
CACHE = os.path.join(ROOT, 'docs', 'art', 'gen', 'tottori', 'timetables')

# page id: app lines its ordinary (普通/快速) trains belong to
PAGES = {
    2393: ['sanin'], 2396: ['sanin'],  # 福知山 – 鳥取 (東浜 … 鳥取)
    2401: ['sanin'], 2402: ['sanin'],  # 鳥取 – 米子
    2412: ['sakai'], 2413: ['sakai'],
    2405: ['wakasa'], 2408: ['wakasa'],
    2411: ['hakubi'], 2415: ['hakubi'],
    2414: ['chizukyu', 'inbi'], 2417: ['chizukyu', 'inbi'],
}
EXPRESS = {'スーパーまつかぜ': 'matsukaze', 'スーパーおき': 'matsukaze', 'スーパーはくと': 'hakuto',
           'スーパーいなば': 'hakuto', 'やくも': 'yakumo'}


def norm(name):
    return unicodedata.normalize('NFKC', name).replace('ヶ', 'ケ').replace('ヵ', 'カ').strip()


def fetch(page, date):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, f'{page}_{date}.html')
    if not os.path.exists(path):
        url = f'https://timetable.jr-odekake.net/line-timetable/{page}?date={date}'
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=30) as r:
            open(path, 'wb').write(r.read())
        time.sleep(0.5)
    return open(path, encoding='utf-8').read()


def cells(row):
    return [re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', '', c))).strip()
            for c in re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', row, re.S)]


def minute(text):
    m = re.match(r'(\d{1,2}):(\d{2})', text)
    if not m:
        return None
    v = int(m.group(1)) * 60 + int(m.group(2))
    return v + 24 * 60 if v < 4 * 60 else v


def parse(page_html):
    """[(no, kind, name, [(stationName, arr, dep)])] in table order."""
    rows = [cells(r) for r in re.findall(r'<tr[^>]*>(.*?)</tr>', page_html, re.S)]
    head = {r[0]: r[2:] for r in rows[:6] if r}
    nos = head.get('列車番号', [])
    def col(key, i):
        v = head.get(key, [])
        return v[i] if i < len(v) else ''

    trains = [(no, col('列車種別', i), col('列車名', i), []) for i, no in enumerate(nos)]
    last = ''
    for r in rows[6:]:
        if len(r) < 3 or r[1] not in ('発', '着'):
            last = r[0] if r and r[1] not in ('発', '着') else last
            continue
        name = norm(r[0]) if r[0] else last
        last = name
        for i, v in enumerate(r[2:2 + len(trains)]):
            m = minute(v)
            if m is None:
                continue
            stops = trains[i][3]
            if stops and stops[-1][0] == name:
                arr = stops[-1][1]
                stops[-1] = (name, arr, m) if r[1] == '発' else (name, m, m)
            else:
                stops.append((name, m, m))
    return trains


def clock(m):
    return f'{m // 60:02d}:{m % 60:02d}'


def retime(out, lines):
    """First / last train and the intervals in timetables.json from the real
    trains (the map's running trains and the last-train alarm use them)."""
    path = os.path.join(CITY, 'timetables.json')
    tt = json.load(open(path, encoding='utf-8'))
    for lid, days in out.items():
        if lid not in tt or not days['weekday']:
            continue
        order = lines[lid]['stations']
        for kind in ('weekday', 'holiday'):
            runs = days[kind] or days['weekday']
            # Per station and way: the trains leaving it; the line's interval
            # is the median station's (trains start at many stations).
            leave = {}
            for r in runs:
                st = r['stops']
                fwd = order.index(st[1][0]) > order.index(st[0][0])
                for sid, _, dep in st[:-1]:
                    leave.setdefault((sid, fwd), []).append(dep)
            for band in tt[lid][kind]:
                lo, hi = (int(band[k][:2]) * 60 + int(band[k][3:]) for k in ('from', 'to'))
                counts = sorted(max(sum(lo <= m < hi for m in leave.get((sid, w), [])) for w in (True, False))
                                for sid in order)
                n = counts[len(counts) // 2]
                band['everyMin'] = max(5, round((hi - lo) / n)) if n else 180
        firsts = [r['stops'][0][2] for r in days['weekday']]
        tt[lid]['firstTrain'] = clock(min(firsts))
        tt[lid]['lastTrain'] = clock(max(firsts))
    json.dump(tt, open(path, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)


def main():
    dates = {'weekday': sys.argv[1], 'holiday': sys.argv[2]} if len(sys.argv) > 2 else {
        'weekday': '20261124', 'holiday': '20261129'}
    stations = json.load(open(os.path.join(CITY, 'stations.json'), encoding='utf-8'))
    lines = {line['id']: line for line in json.load(open(os.path.join(CITY, 'lines.json'), encoding='utf-8'))}
    by_name = {norm(s['name']['ja']): s['id'] for s in stations}
    # 東山公園 is on two lines in the table but one station here: fine.
    out = {lid: {'weekday': [], 'holiday': []} for lid in lines}
    missing = set()
    for kind, date in dates.items():
        seen = set()
        for page, ordinary in PAGES.items():
            for no, cls, name, stops in parse(fetch(page, date)):
                if '特急' in cls:
                    target = EXPRESS.get(name)
                    if target is None:
                        continue
                    targets = [target]
                else:
                    targets = ordinary
                for t in targets:
                    lid = f'tottori.{t}'
                    on = set(lines[lid]['stations'])
                    run = []
                    for sname, arr, dep in stops:
                        sid = by_name.get(sname)
                        if sid is None:
                            continue
                        if sid in on:
                            run.append([sid, arr, dep])
                    if len(run) < 2 or (lid, no, run[0][0]) in seen:
                        continue
                    seen.add((lid, no, run[0][0]))
                    run[0][1] = run[0][2]
                    run[-1][2] = run[-1][1]
                    dest = norm(stops[-1][0])
                    out[lid][kind].append({'no': no, 'kind': cls, 'name': name, 'to': dest, 'stops': run})
                for sname, _, _ in stops:
                    if sname not in by_name:
                        missing.add(sname)
        for lid in out:
            out[lid][kind].sort(key=lambda r: r['stops'][0][2])
    json.dump(out, open(os.path.join(CITY, 'trains.json'), 'w', encoding='utf-8'), ensure_ascii=False,
              separators=(',', ':'))
    retime(out, lines)
    for lid, v in out.items():
        print(lid, len(v['weekday']), len(v['holiday']))
    print('stations not in the app (fine when outside the map):', len(missing))


if __name__ == '__main__':
    main()
