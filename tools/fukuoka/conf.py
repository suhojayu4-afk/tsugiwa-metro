"""Fukuoka: what the shared city tools (fetch.py, build_city.py, build_map.py,
make_landmarks.py in this folder) need to know about the city.

The Fukuoka City Subway (Kuko, Hakozaki and Nanakuma lines). The ground:
Hakata Bay and Nokonoshima in the north to Dazaifu in the south-east.
"""
CITY = 'fukuoka'
NAME = {'ja': '福岡', 'ko': '후쿠오카', 'en': 'Fukuoka'}
CENTER = (33.5900, 130.4000)
UNITS = 150.0
GROUND = (33.500, 130.250, 33.665, 130.560)
OUTER_MARGIN = 4000
SEA = [(33.640, 130.330), (33.630, 130.370), (33.655, 130.300), (33.660, 130.380), (33.700, 130.300)]
WEATHER = {'forecastOffice': '400000', 'forecastArea': '400010', 'amedas': '82182'}
STATION_TYPES = ('station', 'halt')
RIVERS = {'那珂川': 60, '博多川': 20, '御笠川': 40, '室見川': 60, '樋井川': 20, '多々良川': 70, '宇美川': 25,
          '名柄川': 20}
CENTRES = [(33.5910, 130.3990, 0.6, 'cbd'),    # Tenjin
           (33.5900, 130.4200, 0.55, 'cbd'),   # Hakata station
           (33.5935, 130.4070, 0.3, 'shop'),   # Nakasu / Kawabata
           (33.5860, 130.4100, 0.25, 'shop'),  # Canal City
           (33.5830, 130.3950, 0.3, 'shop'),   # Daimyo / Yakuin
           (33.5830, 130.3600, 0.25, 'shop')]  # Nishijin
OPERATOR = '福岡市'
