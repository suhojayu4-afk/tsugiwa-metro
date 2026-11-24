import json,sys
p='C:/dev/tsugiwa-metro/docs/art/gen/cities/anim/jobs.json'; j=json.load(open(p))
a=sys.argv[1:]
for i in range(0,len(a),3): j[a[i]]=[a[i+1],a[i+2]]
json.dump(j,open(p,'w'),indent=1); print(len(j),'pictures recorded')
