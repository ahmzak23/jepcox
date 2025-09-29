#!/usr/bin/env python3

import urllib.request
import json

# Test the map data API
url = "http://localhost:9100/api/oms/map/data?types=crews"
response = urllib.request.urlopen(url)
data = json.loads(response.read().decode())

print("Response status:", response.status)
print("Crews count:", len(data['map_data'].get('crews', [])))
print("Crew data:", data['map_data'].get('crews', []))

# Test the crews API
url2 = "http://localhost:9100/api/oms/crews"
response2 = urllib.request.urlopen(url2)
data2 = json.loads(response2.read().decode())

print("\nCrews API response:")
print("Active crews:", data2.get('active_crews', []))
print("Total active crews:", data2.get('total_active_crews', 0))
