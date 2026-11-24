"""Osaka: what the shared city tools (fetch.py, build_city.py, build_map.py,
make_landmarks.py in this folder) need to know about the city.

Osaka Metro (9 lines incl. the Nanko Port Town new tram), the JR Osaka Loop
Line and the JR Yumesaki Line to Universal City. The ground: Osaka Bay in
the west to the foot of Mt. Ikoma in the east, Esaka to Nakamozu.
"""
CITY = 'osaka'
NAME = {'ja': '大阪', 'ko': '오사카', 'en': 'Osaka'}
CENTER = (34.6900, 135.5050)          # station picking, and the middle of the map
UNITS = 150.0                         # map units per km (a dense metro, like central Tokyo)
GROUND = (34.540, 135.360, 34.790, 135.640)   # south, west, north, east: the detailed tiles
OUTER_MARGIN = 4000                   # map units of coarse ground round the tiles
# Points out on the open sea (flood-fill seeds inside the coastline walls).
SEA = [(34.600, 135.380), (34.560, 135.365), (34.650, 135.365), (34.700, 135.300), (34.450, 135.250),
       (34.580, 135.300)]
WEATHER = {'forecastOffice': '270000', 'forecastArea': '270000', 'amedas': '62078'}
STATION_TYPES = ('station', 'halt')
# Riverbank polygons and river lines kept (the rest of the canals and ditches are left out).
RIVERS = {'淀川': 160, '新淀川': 160, '大川': 70, '旧淀川': 70, '堂島川': 45, '土佐堀川': 40, '安治川': 70, '木津川': 70,
          '尻無川': 60, '神崎川': 90, '大和川': 110, '寝屋川': 30, '道頓堀川': 25, '東横堀川': 20, '中津川': 40,
          '平野川': 15, '第二寝屋川': 25, '正蓮寺川': 35, '六軒家川': 35, '住吉川': 25, '十三間川': 25}
# Office districts (CBD look) and shopping streets drawn over the landuse: (lat, lng, km, kind)
CENTRES = [(34.7025, 135.4975, 0.85, 'cbd'),    # Umeda
           (34.6880, 135.5000, 0.7, 'cbd'),     # Yodoyabashi / Kitahama / Honmachi
           (34.6810, 135.5000, 0.55, 'cbd'),
           (34.6870, 135.5300, 0.35, 'cbd'),    # Osaka Business Park
           (34.6460, 135.5130, 0.45, 'cbd'),    # Tennoji / Abeno
           (34.6680, 135.5010, 0.65, 'shop'),   # Namba / Shinsaibashi
           (34.6740, 135.5010, 0.4, 'shop'),
           (34.7070, 135.5110, 0.35, 'shop'),   # Tenjinbashi-suji
           (34.6970, 135.5330, 0.3, 'shop')]    # Kyobashi
OPERATOR = 'Osaka Metro|大阪市高速電気軌道|大阪メトロ|Osaka Municipal'
