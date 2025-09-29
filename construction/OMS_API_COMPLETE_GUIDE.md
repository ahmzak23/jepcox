# Complete OMS API Guide

## 🚀 **Core OMS Endpoints - Now Available!**

Your OMS system now has a complete set of endpoints for full outage management operations. Here's everything you can do:

## 📊 **Dashboard & Monitoring**

### **GET /api/oms/statistics**
Get system-wide statistics for the dashboard.
```bash
curl http://localhost:9100/api/oms/statistics
```

### **GET /api/oms/outages**
List all active outages with basic details.
```bash
curl http://localhost:9100/api/oms/outages
```

## 🔍 **Outage Management**

### **GET /api/oms/outages/{outage_id}**
Get detailed information about a specific outage.
```bash
curl http://localhost:9100/api/oms/outages/123e4567-e89b-12d3-a456-426614174000
```

**Returns:**
- Complete outage details
- Event sources that contributed
- Crew assignments
- Timeline of events
- Network topology information

### **PUT /api/oms/outages/{outage_id}/status**
Update outage status (detected → confirmed → in_progress → restored).
```bash
curl -X PUT http://localhost:9100/api/oms/outages/123e4567-e89b-12d3-a456-426614174000/status \
  -H "Content-Type: application/json" \
  -d '{
    "status": "confirmed",
    "notes": "Field crew confirmed transformer failure",
    "updated_by": "operator_john"
  }'
```

**Valid statuses:** `detected`, `confirmed`, `in_progress`, `restored`, `cancelled`

## 👷 **Crew Management**

### **GET /api/oms/crews**
Get list of available and active crews.
```bash
curl http://localhost:9100/api/oms/crews
```

### **POST /api/oms/outages/{outage_id}/crew**
Assign a crew to an outage.
```bash
curl -X POST http://localhost:9100/api/oms/outages/123e4567-e89b-12d3-a456-426614174000/crew \
  -H "Content-Type: application/json" \
  -d '{
    "crew_name": "Line Crew Alpha",
    "crew_type": "line_crew",
    "estimated_arrival_time": "2025-09-25T16:30:00Z",
    "notes": "Crew equipped with bucket truck and transformer tools"
  }'
```

**Crew types:** `line_crew`, `tree_crew`, `inspection_crew`, `emergency_crew`

### **PUT /api/oms/crews/{assignment_id}/status**
Update crew status (assigned → en_route → on_site → work_completed).
```bash
curl -X PUT http://localhost:9100/api/oms/crews/456e7890-e89b-12d3-a456-426614174001/status \
  -H "Content-Type: application/json" \
  -d '{
    "status": "on_site",
    "notes": "Arrived at site, beginning assessment",
    "updated_by": "crew_leader_mike"
  }'
```

## 📱 **Customer Notifications**

### **POST /api/oms/outages/{outage_id}/notify**
Send notifications to affected customers.
```bash
curl -X POST http://localhost:9100/api/oms/outages/123e4567-e89b-12d3-a456-426614174000/notify \
  -H "Content-Type: application/json" \
  -d '{
    "notification_type": "sms",
    "message": "Power outage in your area. Estimated restoration: 2 hours. Crew is on site.",
    "customer_ids": ["customer_123", "customer_456"],
    "estimated_restoration_time": "2025-09-25T18:00:00Z"
  }'
```

**Notification types:** `sms`, `email`, `push`, `phone`

### **GET /api/oms/notifications**
Get history of sent notifications.
```bash
curl http://localhost:9100/api/oms/notifications?limit=20&offset=0
```

## 🔄 **Event Correlation**

### **POST /api/oms/events/correlate**
Core endpoint for event correlation (used by consumers).
```bash
curl -X POST http://localhost:9100/api/oms/events/correlate \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "outage",
    "source_type": "scada",
    "source_event_id": "scada_001",
    "timestamp": "2025-09-25T15:30:00Z",
    "latitude": 31.9454,
    "longitude": 35.9284,
    "correlation_params": {
      "spatial_radius_meters": 500,
      "temporal_window_minutes": 15
    }
  }'
```

## 🏥 **System Health**

### **GET /health**
Check API health status.
```bash
curl http://localhost:9100/health
```

## 🧪 **Complete Workflow Example**

Here's a complete outage management workflow:

### **1. Detect Outage**
```bash
# KAIFA consumer automatically calls correlate endpoint
# This creates an outage event with status "detected"
```

### **2. Get Outage Details**
```bash
curl http://localhost:9100/api/oms/outages
# Find the outage ID from the response
```

### **3. Confirm Outage**
```bash
curl -X PUT http://localhost:9100/api/oms/outages/{outage_id}/status \
  -H "Content-Type: application/json" \
  -d '{"status": "confirmed", "updated_by": "operator"}'
```

### **4. Assign Crew**
```bash
curl -X POST http://localhost:9100/api/oms/outages/{outage_id}/crew \
  -H "Content-Type: application/json" \
  -d '{
    "crew_name": "Emergency Line Crew",
    "crew_type": "emergency_crew",
    "estimated_arrival_time": "2025-09-25T16:00:00Z"
  }'
```

### **5. Send Customer Notifications**
```bash
curl -X POST http://localhost:9100/api/oms/outages/{outage_id}/notify \
  -H "Content-Type: application/json" \
  -d '{
    "notification_type": "sms",
    "message": "Power outage detected. Crew dispatched. ETA: 1 hour."
  }'
```

### **6. Update Crew Status**
```bash
curl -X PUT http://localhost:9100/api/oms/crews/{assignment_id}/status \
  -H "Content-Type: application/json" \
  -d '{"status": "on_site", "updated_by": "crew_leader"}'
```

### **7. Complete Work**
```bash
curl -X PUT http://localhost:9100/api/oms/crews/{assignment_id}/status \
  -H "Content-Type: application/json" \
  -d '{"status": "work_completed", "updated_by": "crew_leader"}'
```

### **8. Restore Power**
```bash
curl -X PUT http://localhost:9100/api/oms/outages/{outage_id}/status \
  -H "Content-Type: application/json" \
  -d '{"status": "restored", "updated_by": "operator"}'
```

### **9. Send Restoration Notification**
```bash
curl -X POST http://localhost:9100/api/oms/outages/{outage_id}/notify \
  -H "Content-Type: application/json" \
  -d '{
    "notification_type": "sms",
    "message": "Power has been restored to your area. Thank you for your patience."
  }'
```

## 📈 **Dashboard Integration**

The dashboard automatically shows:
- ✅ **Real-time statistics** from `/api/oms/statistics`
- ✅ **Active outages** from `/api/oms/outages`
- ✅ **Auto-refresh** every 30 seconds
- ✅ **Source breakdown** and confidence scores

## 🔧 **API Documentation**

Access interactive API documentation at:
- **Swagger UI**: http://localhost:9100/docs
- **ReDoc**: http://localhost:9100/redoc

## 🎯 **What You Can Do Now**

### **Operations Center:**
- ✅ Monitor all active outages in real-time
- ✅ Update outage status as information changes
- ✅ Assign crews to outages
- ✅ Track crew progress and status
- ✅ Send customer notifications
- ✅ View complete outage timeline and history

### **Field Crews:**
- ✅ Receive outage assignments
- ✅ Update their status (en route, on site, completed)
- ✅ Add notes about work progress
- ✅ View detailed outage information

### **Management:**
- ✅ Monitor system performance
- ✅ Track crew efficiency
- ✅ Analyze notification effectiveness
- ✅ Generate compliance reports

## 🚀 **Your OMS is Now Complete!**

You now have a **fully functional Outage Management System** with:
- ✅ **Real-time event correlation**
- ✅ **Complete outage lifecycle management**
- ✅ **Crew dispatch and tracking**
- ✅ **Customer notification system**
- ✅ **Professional dashboard**
- ✅ **RESTful API for integration**

**Ready for production use!** 🎉

