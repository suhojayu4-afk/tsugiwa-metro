"""Rewrite only the landmarks of a city's map.json and its landmarks.json
(after moving or adding one in tools/<city>/landmarks.py), without painting
the ground again.

  python -X utf8 tools/relandmark.py <city>
"""
import json
import os
import sys

city = sys.argv[1]
HERE = os.path.join(os.path.dirname(os.path.abspath(__file__)), city)
sys.path.insert(0, HERE)
os.environ.pop('MAP_NEW_LAYOUT', None)
import build_map as B  # noqa: E402  (keeps the line layout)

p = os.path.join(B.CITY, 'map.json')
data = json.load(open(p, encoding='utf8'))
data['landmarks'] = B.landmark_list()
json.dump(data, open(p, 'w', encoding='utf8'), ensure_ascii=False, separators=(',', ':'))
json.dump(B.landmark_notes(), open(os.path.join(B.CITY, 'landmarks.json'), 'w', encoding='utf8'),
          ensure_ascii=False, indent=1)
print(city, len(data['landmarks']), 'landmarks')
