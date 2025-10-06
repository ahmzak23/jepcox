import requests
import json

# Test the OMS API map data endpoint
response = requests.get('http://localhost:9100/api/oms/map/data?days=7&data_types=assets')
data = response.json()

assets = data.get('map_data', {}).get('assets', {})
substations = assets.get('substations', [])

print(f'Substations returned: {len(substations)}')
print()

for s in substations:
    print(f"  - {s['name']} ({s['substation_id']})")
    print(f"    Location: ({s['latitude']}, {s['longitude']})")
    print(f"    Status: {s['status']}")
    print()

print('=' * 60)
if len(substations) > 0:
    print('SUCCESS: Substations are now being returned by the API!')
else:
    print('ERROR: No substations returned')

