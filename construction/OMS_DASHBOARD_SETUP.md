# OMS Dashboard Setup Guide

## 🚀 Quick Start

The OMS Dashboard provides a real-time web interface for monitoring outage events, confidence scores, and system statistics.

### **1. Start the Dashboard**

```bash
# Build and start the dashboard
docker compose up -d --build oms-dashboard

# Check if it's running
docker compose ps oms-dashboard
```

### **2. Access the Dashboard**

Open your browser and navigate to:
- **Dashboard URL**: http://localhost:9200
- **OMS API**: http://localhost:9100

### **3. Verify the Setup**

```bash
# Check API health
curl http://localhost:9100/health

# Check dashboard endpoints
curl http://localhost:9100/api/oms/statistics
curl http://localhost:9100/api/oms/outages
```

## 📊 Dashboard Features

### **Real-time Statistics**
- Active outages count
- Total affected customers
- High confidence outages (>80%)
- Event source breakdown

### **Outage Details**
- Event ID and status
- Confidence score with visual indicator
- Severity level
- Affected customer count
- Network topology (substation, feeder)
- Source systems contributing
- Detection timestamp

### **Event Sources**
- SCADA events (highest priority)
- Kaifa smart meter events
- ONU device signals
- Call center reports

## 🔧 Configuration

### **Environment Variables**
The dashboard connects to the OMS API automatically. No additional configuration needed.

### **Auto-refresh**
- Dashboard refreshes every 30 seconds
- Manual refresh button available
- Real-time status indicator

## 🎯 Usage Scenarios

### **Operations Center**
- Monitor active outages in real-time
- Assess confidence levels for dispatch decisions
- Track source system contributions
- View affected customer counts

### **Management Dashboard**
- High-level outage statistics
- System performance metrics
- Source reliability tracking
- Historical trend analysis

## 🚨 Troubleshooting

### **Dashboard Not Loading**
```bash
# Check container status
docker compose logs oms-dashboard

# Restart if needed
docker compose restart oms-dashboard
```

### **No Data Showing**
```bash
# Verify OMS API is running
curl http://localhost:9100/health

# Check if data exists
curl http://localhost:9100/api/oms/statistics
```

### **API Connection Issues**
```bash
# Check network connectivity
docker compose exec oms-dashboard ping oms-api

# Verify API endpoints
docker compose exec oms-dashboard wget -qO- http://oms-api:8000/health
```

## 📱 Mobile Responsive

The dashboard is fully responsive and works on:
- Desktop computers
- Tablets
- Mobile phones
- Large displays (operations centers)

## 🔄 Integration

### **API Endpoints Used**
- `GET /health` - System health check
- `GET /api/oms/statistics` - System statistics
- `GET /api/oms/outages` - Active outages list

### **Customization**
The dashboard can be customized by editing:
- `construction/oms_dashboard/index.html` - Main dashboard file
- Styling and layout modifications
- Additional data visualizations
- Custom refresh intervals

## 🎨 Visual Indicators

### **Confidence Scores**
- **Red (0-40%)**: Low confidence
- **Orange (40-70%)**: Medium confidence  
- **Green (70-100%)**: High confidence

### **Status Colors**
- **Detected**: Yellow background
- **Confirmed**: Red background
- **In Progress**: Blue background
- **Restored**: Green background

## 📈 Next Steps

1. **Add Historical Charts** - Trend analysis over time
2. **Geographic Maps** - Visual outage locations
3. **Alert Notifications** - Real-time alerts
4. **Export Features** - PDF reports
5. **User Authentication** - Role-based access

---

**Dashboard URL**: http://localhost:9200  
**API Documentation**: http://localhost:9100/docs  
**System Health**: http://localhost:9100/health

