#!/usr/bin/env python3
"""
Test script to check if topology connections are working
"""

import requests
import json

def test_topology_connections():
    """Test if the API returns topology connections"""
    try:
        # Test the map data endpoint
        response = requests.get("http://localhost:9100/api/oms/map/data")
        
        if response.status_code == 200:
            data = response.json()
            
            print("API Response Status: 200")
            print(f"Total outages: {data.get('metadata', {}).get('total_outages', 0)}")
            print(f"Total connections: {data.get('metadata', {}).get('total_connections', 0)}")
            
            # Check if topology_connections exist
            map_data = data.get('map_data', {})
            topology_connections = map_data.get('topology_connections', [])
            
            print(f"Topology connections found: {len(topology_connections)}")
            
            if topology_connections:
                print("Sample connection:")
                print(json.dumps(topology_connections[0], indent=2))
            else:
                print("No topology connections found")
                print("This means either:")
                print("1. No substations exist in network_substations table")
                print("2. No SCADA events link outages to substations")
                print("3. The database query is failing")
                
        else:
            print(f"API Error: {response.status_code}")
            print(response.text)
            
    except Exception as e:
        print(f"Error testing topology: {e}")

if __name__ == "__main__":
    test_topology_connections()
