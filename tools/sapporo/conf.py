"""Sapporo: what the shared city tools (fetch.py, build_city.py, build_map.py,
make_landmarks.py in this folder) need to know about the city.

The Sapporo City Subway (Namboku, Tozai, Toho lines) and the Sapporo
streetcar loop, and the JR Hakodate Line along Ishikari Bay to Otaru. The
ground: the grid of the Ishikari plain, the Toyohira river, the mountains
in the west (Mt. Moiwa, Okurayama, Teine) and the coast to Otaru.
"""
CITY = 'sapporo'
NAME = {'ja': '札幌', 'ko': '삿포로', 'en': 'Sapporo'}
CENTER = (43.0620, 141.3540)
UNITS = 150.0
GROUND = (42.965, 140.960, 43.225, 141.500)
OUTER_MARGIN = 4000
SEA = [(43.215, 141.150), (43.220, 141.080), (43.205, 141.200), (43.222, 141.020), (43.300, 141.100)]
WEATHER = {'forecastOffice': '016000', 'forecastArea': '016010', 'amedas': '14163'}
STATION_TYPES = ('station', 'halt', 'tram_stop')
RIVERS = {'豊平川': 110, '創成川': 18, '発寒川': 25, '琴似発寒川': 25, '新川': 35, '伏籠川': 20, '厚別川': 25,
          '精進川': 10, '望月寒川': 10, '月寒川': 12, '石狩川': 220, '茨戸川': 60, '野津幌川': 15}
CENTRES = [(43.0610, 141.3540, 0.55, 'cbd'),   # Odori / Sapporo station
           (43.0680, 141.3510, 0.45, 'cbd'),   # Sapporo station
           (43.0550, 141.3530, 0.35, 'shop'),  # Susukino / Tanukikoji
           (43.0390, 141.4730, 0.25, 'shop'),  # Shin-Sapporo
           (43.1960, 140.9970, 0.3, 'shop')]   # Otaru
OPERATOR = '札幌市|札幌'
