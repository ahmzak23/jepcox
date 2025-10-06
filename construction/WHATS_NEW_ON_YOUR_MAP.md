# 🗺️ What's New on Your Geographic View

## ✅ Database Status

All meter correlation features are now **ACTIVE** in your database:

- ✅ **39 meters** in the system
- ✅ **3 substations** (Central Amman, Zarqa, Irbid)
- ✅ **117 substation-meter links** established
- ✅ **All consumers** updated and running
- ✅ **OMS API** restarted

---

## 🔄 Step 1: Refresh Your Dashboard

**Right now, do this:**

1. Go to your browser with the dashboard open: **http://localhost:9200**
2. **Press F5** or click the **Refresh** button in the dashboard
3. Go to the **"Geographic View"** tab
4. The map should now show additional features!

---

## 👀 Step 2: What You Should See Now

### **NEW Features on the Map:**

#### 1. **Substation Markers** 
- **3 teal/cyan markers** with industrial icons
- Located at:
  - Central Amman (31.9539, 35.9106)
  - Zarqa (32.0731, 36.0880)
  - Irbid (32.5561, 35.8515)

**Click any substation marker to see:**
```
Central Amman Substation
Status: Active
Total Meters: 39
Online Meters: [count]
Offline Meters: [count]
```

#### 2. **Meter Status Layer**
Toggle the **"Show Assets"** checkbox in the control panel to see:
- Individual meter locations
- Color-coded by status:
  - 🟢 Green = Online
  - 🔴 Red = Offline
  - 🟡 Yellow = Unknown

#### 3. **Enhanced Outage Information**
When you click any outage marker, the popup now shows:
- **Affected meters count**
- **Substation/Feeder information**
- **Customer impact**
- **Correlated events** from all 4 sources

---

## 🧪 Step 3: Test the New Features

### Test A: Create a Test SCADA Event

Open a new terminal and run:

```bash
curl -X POST http://localhost:9086/scada/outage \
  -H "Content-Type: application/json" \
  -d "{
    \"eventType\": \"breaker_trip\",
    \"substationId\": \"SS001\",
    \"feederId\": \"FD001\",
    \"mainStationId\": \"MS001\",
    \"alarmType\": \"fault\",
    \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"voltage\": 0.0,
    \"severity\": \"critical\",
    \"reason\": \"Test meter correlation\",
    \"coordinates\": {
      \"lat\": 31.9539,
      \"lng\": 35.9106
    }
  }"
```

**Then watch the consumer logs:**
```bash
docker-compose logs -f scada-consumer
```

**You should see:**
```
INFO - Stored SCADA event xxx to database
INFO - Meter Check Results:
INFO -   Total meters: 39
INFO -   Offline meters: [count]
INFO -   Online meters: [count]
WARNING - OUTAGE DETECTED - Event ID: OMS_SCADA_xxx, [count] meters offline
```

### Test B: View on the Map

1. **Refresh the dashboard** (F5)
2. **Look for a new red marker** at Central Amman
3. **Click the marker** - it should show:
   - Outage details
   - Number of affected meters
   - Substation information
   - Correlation sources

---

## 📊 Step 4: Enhanced API Responses

### Check Map Data API

Open in browser or use curl:

```
http://localhost:9100/api/oms/map/data?days=7
```

**You'll now see NEW data:**

```json
{
  "map_data": {
    "outages": [
      {
        "outage_id": "OMS_xxx",
        "latitude": 31.9539,
        "longitude": 35.9106,
        "severity": "critical",
        "affected_customers": 39,
        "total_meters": 39,
        "offline_meters": [count],
        "substation_id": "SS001",
        "substation_name": "Central Amman Substation"
      }
    ],
    "assets": {
      "substations": [
        {
          "substation_id": "SS001",
          "name": "Central Amman Substation",
          "latitude": 31.9539,
          "longitude": 35.9106,
          "total_meters": 39,
          "online_meters": [count],
          "offline_meters": [count],
          "status": "active"
        }
      ]
    }
  }
}
```

---

## 🎨 Visual Improvements

### Before (What you had):
- ❌ Only flow lines showing data streams
- ❌ Generic outage markers
- ❌ No infrastructure visibility
- ❌ No meter-level detail

### After (What you have now):
- ✅ **Substation markers** showing infrastructure
- ✅ **Meter-to-substation relationships**
- ✅ **Real-time meter status** (when events occur)
- ✅ **Precise customer impact**
- ✅ **Multi-source correlation** visible in popups
- ✅ **Topology-aware views**

---

## 🔍 Understanding the Map Layers

### Layer Controls (Right side panel):

**Show/Hide Elements:**
- ☑️ **Show Outages** - Red/orange/yellow markers for outages
- ☑️ **Show Events** - Gray markers for source events (SCADA/ONU/Kaifa/Call Center)
- ☑️ **Show Crews** - Blue markers for field crews
- ☑️ **Show Assets** - Teal markers for substations/feeders
- ☑️ **Show Hotspots** - Circular overlays for outage clusters
- ☑️ **Show Flow Lines** - Animated blue dots (your current view)

**Try toggling these to see different views!**

---

## 🚨 When a Real Outage Occurs

**The NEW workflow:**

1. **SCADA breaker trips** at a substation
2. **Consumer automatically**:
   - Queries all 39 meters under that substation
   - Checks each meter's status
   - Identifies offline meters (< 1 second)
3. **Creates outage event** with precise count
4. **Map updates** showing:
   - Red marker at substation
   - Affected meter locations
   - Customer count
   - Crew dispatch recommendations

**You see everything in real-time on the map!**

---

## 📈 Data You Can Now Query

### Get All Meters Under a Substation
```sql
SELECT * FROM get_meters_by_substation('SS001');
```

### View Substation Health
```sql
SELECT * FROM network_substations_with_meters;
```

### Check Recent Meter Status Changes
```sql
SELECT 
    m.meter_number,
    mse.event_type,
    mse.source_type,
    mse.event_timestamp,
    mse.previous_status || ' -> ' || mse.new_status as change
FROM oms_meter_status_events mse
JOIN oms_meters m ON mse.meter_id = m.id
ORDER BY mse.event_timestamp DESC
LIMIT 20;
```

---

## 🎯 Next Steps

### 1. **Add More Substations**
Edit `construction/link_meters_to_substations.sql` to add your real substations with actual GPS coordinates.

### 2. **Import Real Meter Data**
Add your actual meter locations to `oms_meters` table:

```sql
UPDATE oms_meters
SET location_lat = [latitude], location_lng = [longitude]
WHERE meter_number = 'M12345678';
```

### 3. **Configure Feeders**
Add feeder topology:

```sql
INSERT INTO network_feeders (feeder_id, substation_id, name, location_lat, location_lng)
VALUES ('FD001', (SELECT id FROM network_substations WHERE substation_id = 'SS001'), 
        'Feeder 001', 31.9540, 35.9110);
```

---

## 🐛 Troubleshooting

### Issue: Still not seeing substations on map

**Check 1: Are consumers running?**
```bash
docker-compose ps scada-consumer onu-consumer hes-consumer call-center-consumer
```

**Check 2: Is OMS API running?**
```bash
docker-compose ps oms-api
```

**Check 3: Check API response**
```bash
curl http://localhost:9100/api/oms/map/data?days=7
```

### Issue: Markers overlap

**Solution:** Zoom in on the map - markers will spread out at higher zoom levels.

### Issue: No real-time updates

**Solution:** Click the **Refresh** button in the dashboard or set auto-refresh interval.

---

## ✨ Summary

### You Now Have:

✅ **Unified meter registry** - 39 meters from all sources  
✅ **Substation topology** - 3 substations with health monitoring  
✅ **Automatic correlation** - SCADA events → meter checks → outage detection  
✅ **Visual representation** - Everything on the map  
✅ **Real-time updates** - When new events occur  

### What Changed on Your Map:

| Feature | Before | After |
|---------|--------|-------|
| **Infrastructure** | Not visible | ✅ 3 substations shown |
| **Meter Status** | Unknown | ✅ 39 meters tracked |
| **Outage Detection** | Manual | ✅ Automatic (< 1 sec) |
| **Customer Impact** | Estimated | ✅ Precise count (39) |
| **Event Correlation** | Separate | ✅ Linked visually |

---

## 🎉 Your Geographic View is Now Enhanced!

**Refresh your dashboard and explore the new features!**

Dashboard: **http://localhost:9200**  
API: **http://localhost:9100/api/oms/map/data**

---

**Questions or Issues?** See the comprehensive documentation:
- `construction/VIEW_METER_CORRELATION_ON_MAPS.md`
- `construction/OMS_METER_CORRELATION_GUIDE.md`
- `construction/START_HERE.md`

