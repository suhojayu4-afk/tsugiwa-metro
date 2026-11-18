"""Tokyo districts for the pixel route map's ground texture.

The real shapes (coast, rivers, moats, parks, expressways, land use) come
from OpenStreetMap (tools/fetch_osm.py -> tools/data/osm). What OSM does
not say well is the *feel* of each area, so it is listed here: where the
office towers stand (cbd) and where the shopping streets are (shop).
Everything else on land is town; far from the centre it is greener.

  (lat, lng, radius km, kind)
"""

DISTRICTS = [
    (35.6830, 139.7650, 0.65, 'cbd'),    # Marunouchi / Otemachi
    (35.6835, 139.7745, 0.40, 'cbd'),    # Nihonbashi
    (35.6900, 139.6930, 0.65, 'cbd'),    # Nishi-Shinjuku
    (35.6650, 139.7600, 0.45, 'cbd'),    # Shiodome / Shimbashi
    (35.6690, 139.7470, 0.55, 'cbd'),    # Toranomon / Kasumigaseki
    (35.6620, 139.7310, 0.45, 'cbd'),    # Roppongi
    (35.6740, 139.7370, 0.35, 'cbd'),    # Akasaka
    (35.6585, 139.7020, 0.40, 'cbd'),    # Shibuya
    (35.7295, 139.7160, 0.40, 'cbd'),    # Ikebukuro
    (35.6270, 139.7400, 0.45, 'cbd'),    # Shinagawa Konan
    (35.6190, 139.7280, 0.25, 'cbd'),    # Osaki
    (35.6550, 139.7570, 0.30, 'cbd'),    # Hamamatsucho
    (35.6350, 139.7900, 0.35, 'cbd'),    # Ariake / Big Sight
    (35.6980, 139.4140, 0.45, 'cbd'),    # Tachikawa
    (35.6930, 139.7020, 0.40, 'shop'),   # Shinjuku east (Kabukicho)
    (35.6715, 139.7650, 0.45, 'shop'),   # Ginza / Yurakucho
    (35.7090, 139.7765, 0.40, 'shop'),   # Ueno / Okachimachi
    (35.6990, 139.7720, 0.35, 'shop'),   # Akihabara
    (35.6930, 139.7690, 0.30, 'shop'),   # Kanda
    (35.7120, 139.7960, 0.40, 'shop'),   # Asakusa
    (35.6680, 139.7070, 0.40, 'shop'),   # Harajuku / Omotesando
    (35.6470, 139.7100, 0.30, 'shop'),   # Ebisu
    (35.6610, 139.6680, 0.25, 'shop'),   # Shimokitazawa
    (35.6430, 139.6700, 0.25, 'shop'),   # Sangenjaya
    (35.7060, 139.6650, 0.30, 'shop'),   # Nakano
    (35.7030, 139.5800, 0.35, 'shop'),   # Kichijoji
    (35.6960, 139.8140, 0.35, 'shop'),   # Kinshicho
    (35.6720, 139.7960, 0.25, 'shop'),   # Monzen-nakacho
    (35.7490, 139.8040, 0.35, 'shop'),   # Kita-Senju
    (35.7780, 139.7210, 0.30, 'shop'),   # Akabane
    (35.7020, 139.9850, 0.40, 'shop'),   # Funabashi
    (35.6950, 139.7480, 0.30, 'shop'),   # Jimbocho / Kudanshita
]

# Town further than this from the centre (km) is drawn as greener suburbs.
SUBURB_KM = 9.0
