#!/usr/bin/env python3

import urllib.request
import json

# Test the map data API
url = "http://localhost:9100/api/oms/map/data?types=crews"
response = urllib.request.urlopen(url)
data = json.loads(response.read().decode())

print("Map data crews count:", len(data['map_data'].get('crews', [])))
if data['map_data'].get('crews'):
    print("First crew:", data['map_data']['crews'][0])
else:
    print("No crews in map data")
