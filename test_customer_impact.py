#!/usr/bin/env python3

import urllib.request
import json

try:
    response = urllib.request.urlopen('http://localhost:9100/api/oms/analytics/customer-impact?days=30&granularity=day')
    data = json.loads(response.read().decode())
    print('Response keys:', list(data.keys()))
    print('Impact trends:', len(data.get('impact_trends', [])))
    print('Summary:', data.get('summary', {}))
    print('Full response:', json.dumps(data, indent=2))
except Exception as e:
    print('Error:', e)
