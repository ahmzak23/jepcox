# CORS Fix for OMS Dashboard

## 🚨 Problem
The dashboard is showing CORS errors because the OMS API doesn't have Cross-Origin Resource Sharing (CORS) headers enabled.

## ✅ Solution Applied
I've added CORS middleware to the OMS API. Now you need to restart the API service to apply the fix.

## 🔧 Quick Fix

### **Option 1: Use the Restart Script (Windows)**
```bash
cd apisix-workshop/construction
restart_oms_api.bat
```

### **Option 2: Manual Restart**
```bash
# Stop the OMS API
docker compose stop oms-api

# Rebuild and restart with CORS support
docker compose up -d --build oms-api

# Wait a few seconds, then check
docker compose ps oms-api
```

### **Option 3: Full System Restart**
```bash
# Restart everything
docker compose down
docker compose up -d --build
```

## ✅ Verification

After restarting, test the API:

```bash
# Test API health
curl http://localhost:9100/health

# Test CORS headers
curl -H "Origin: http://localhost:9200" \
     -H "Access-Control-Request-Method: GET" \
     -H "Access-Control-Request-Headers: X-Requested-With" \
     -X OPTIONS \
     http://localhost:9100/health
```

## 🎯 Expected Results

After the restart:
- ✅ Dashboard should load data without CORS errors
- ✅ Statistics cards should show real numbers
- ✅ Outage list should populate (if any outages exist)
- ✅ Event sources should show counts
- ✅ Auto-refresh should work every 30 seconds

## 🔍 Troubleshooting

### **If CORS errors persist:**
1. Check if the API is actually running:
   ```bash
   docker compose logs oms-api
   ```

2. Verify the CORS middleware was added:
   ```bash
   docker compose exec oms-api cat /app/main.py | grep -i cors
   ```

3. Test API directly:
   ```bash
   curl -v http://localhost:9100/health
   ```

### **If dashboard still shows no data:**
- This is normal if no outage events exist yet
- The dashboard will show "No active outages detected" 
- Statistics will show 0 values
- This is expected behavior for a new system

## 📊 What to Expect

Once fixed, the dashboard will show:
- **Real-time statistics** from your database
- **Active outages** (if any exist)
- **Event source counts** from the last 24 hours
- **Auto-refresh** every 30 seconds
- **Professional UI** with confidence indicators

---

**Dashboard URL**: http://localhost:9200  
**API Health Check**: http://localhost:9100/health  
**API Documentation**: http://localhost:9100/docs

