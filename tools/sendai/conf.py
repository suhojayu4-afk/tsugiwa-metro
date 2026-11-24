"""Sendai: what the shared city tools (fetch.py, build_city.py, build_map.py,
make_landmarks.py in this folder) need to know about the city.

The Sendai City Subway (Namboku and Tozai lines). The ground: the hills of
Aobayama in the west to the Pacific coast, and up the coast to Matsushima.
"""
CITY = 'sendai'
NAME = {'ja': '仙台', 'ko': '센다이', 'en': 'Sendai'}
CENTER = (38.2600, 140.8800)
UNITS = 150.0
GROUND = (38.170, 140.760, 38.425, 141.120)
OUTER_MARGIN = 4000
SEA = [(38.200, 141.050), (38.250, 141.080), (38.300, 141.095), (38.180, 141.090), (38.230, 141.200),
       (38.330, 141.090), (38.120, 141.050)]
WEATHER = {'forecastOffice': '040000', 'forecastArea': '040010', 'amedas': '34392'}
STATION_TYPES = ('station', 'halt')
RIVERS = {'広瀬川': 45, '名取川': 70, '七北田川': 45, '梅田川': 15, '貞山運河': 20, '貞山堀': 20, '砂押川': 25,
          '笊川': 12}
CENTRES = [(38.2610, 140.8790, 0.5, 'cbd'),    # Sendai station west / Chuo-dori
           (38.2640, 140.8700, 0.45, 'cbd'),   # Ichibancho / Kotodai
           (38.2600, 140.8740, 0.3, 'shop'),   # Ichibancho arcades
           (38.2265, 140.8790, 0.25, 'shop')]  # Nagamachi
OPERATOR = '仙台市'
