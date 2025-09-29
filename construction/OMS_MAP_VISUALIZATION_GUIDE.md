# 🗺️ OMS Map Visualization Guide

## Overview

The OMS Map Visualization provides a comprehensive geographic view of all outage management data, enabling operators to visualize events, outages, crews, and network assets on an interactive map.

## 🎯 Features

### **Interactive Map Components**
- **Outage Events** - Color-coded markers by severity (Critical: Red, High: Orange, Medium: Yellow, Low: Green)
- **Event Sources** - Different markers for SCADA, Kaifa meters, ONU devices, and call center reports
- **Crew Locations** - Real-time crew positions and status tracking
- **Network Assets** - Substations, feeders, and distribution points
- **Geographic Hotspots** - Circular overlays showing outage clusters
- **Layer Controls** - Toggle visibility of different data types

### **Map Controls**
- **Refresh** - Update map data in real-time
- **Layers** - Toggle different data layer visibility
- **Fit View** - Auto-zoom to show all active data points
- **Info Panel** - Detailed information popup for each marker

## 🛠️ Technical Implementation

### **API Endpoint**
```
GET /api/oms/map/data
```

**Parameters:**
- `days` (int): Number of days to include (default: 7)
- `data_types` (string): Comma-separated list of data types (default: "all")
- `bounding_box` (string): Optional geographic filter (format: "lat1,lng1,lat2,lng2")

**Response Structure:**
```json
{
  "map_data": {
    "outages": [...],     // Outage events with coordinates
    "events": [...],      // All source events (SCADA, Kaifa, ONU, Call Center)
    "crews": [...],       // Crew locations and assignments
    "assets": {           // Network infrastructure
      "substations": [...],
      "feeders": [...]
    },
    "hotspots": [...]     // Geographic outage clusters
  },
  "metadata": {
    "total_outages": 23,
    "total_events": 30,
    "total_crews": 3,
    "total_hotspots": 2,
    "last_updated": "2025-09-25T16:51:00Z"
  }
}
```

### **Map Technology Stack**
- **Leaflet.js** - Open-source interactive map library
- **OpenStreetMap** - Free map tile provider
- **Custom Markers** - CSS-styled markers with FontAwesome icons
- **Layer Groups** - Organized marker management by data type

### **Marker Types & Styling**

#### Outage Markers
- **Critical**: Red circle with lightning bolt icon (30px)
- **High**: Orange circle with lightning bolt icon (28px)
- **Medium**: Yellow circle with lightning bolt icon (26px)
- **Low**: Green circle with lightning bolt icon (24px)

#### Event Markers
- **SCADA**: Gray circle with server icon (18px)
- **Kaifa**: Gray circle with meter icon (18px)
- **ONU**: Gray circle with WiFi icon (18px)
- **Call Center**: Gray circle with phone icon (18px)

#### Crew Markers
- **All Crews**: Blue circle with users icon (32px)

#### Asset Markers
- **Substations**: Teal circle with industry icon (20px)
- **Feeders**: Teal circle with bolt icon (20px)

#### Hotspot Markers
- **High Severity**: Red semi-transparent circle
- **Medium Severity**: Yellow semi-transparent circle

## 🎮 User Interface

### **Map Tab Navigation**
1. Click the **Map** tab in the dashboard
2. Map automatically loads with all data types visible
3. Use legend to understand marker meanings
4. Click markers for detailed information

### **Layer Controls**
- **Show Outages**: Toggle outage markers visibility
- **Show Events**: Toggle event source markers visibility
- **Show Crews**: Toggle crew location markers visibility
- **Show Assets**: Toggle network asset markers visibility
- **Show Hotspots**: Toggle geographic hotspot overlays

### **Interactive Features**
- **Click Markers**: View detailed popup information
- **Click Info Panel**: Extended details in side panel
- **Zoom & Pan**: Standard map navigation
- **Fit to Data**: Auto-zoom to show all markers

## 📊 Data Visualization

### **Outage Information**
- Severity level and status
- Number of affected customers
- Confidence score percentage
- Source types contributing to the outage
- Detection timestamp

### **Event Details**
- Event type and source system
- Severity level
- Timestamp of occurrence
- Related meter/substation information
- Customer association (where applicable)

### **Crew Information**
- Crew name and type
- Current status (on-site, en-route, available)
- Crew size and equipment
- Current assignment details
- Estimated completion/arrival times

### **Asset Information**
- Asset name and type
- Operational status
- Voltage level (for electrical assets)
- Current load percentage
- Parent substation relationship

### **Hotspot Analysis**
- Geographic center and radius
- Number of outages in cluster
- Total customers affected
- Severity classification
- Confidence level

## 🔄 Real-time Updates

### **Auto-refresh**
- Map data refreshes every 30 seconds
- New events appear automatically
- Crew positions update in real-time
- Outage status changes reflect immediately

### **Manual Refresh**
- Click **Refresh** button for immediate update
- Useful during active storm events
- Ensures latest information is displayed

## 🎨 Visual Design

### **Glass-morphism Style**
- Translucent control panels
- Blurred background effects
- Subtle shadows and borders
- Consistent with overall dashboard theme

### **Color Coding**
- **Critical Issues**: Red (#dc3545)
- **High Priority**: Orange (#fd7e14)
- **Medium Priority**: Yellow (#ffc107)
- **Low Priority**: Green (#28a745)
- **Crews**: Blue (#007bff)
- **Assets**: Teal (#20c997)
- **Events**: Gray (#6c757d)

### **Responsive Design**
- Adapts to different screen sizes
- Mobile-friendly controls
- Touch-optimized interactions
- Collapsible info panels

## 🚀 Usage Examples

### **Storm Response**
1. Navigate to Map tab during storm events
2. Enable all layer types for complete view
3. Use hotspots to identify affected areas
4. Track crew assignments and progress
5. Monitor new events in real-time

### **Routine Monitoring**
1. Check crew locations and availability
2. Verify asset operational status
3. Review recent event patterns
4. Identify potential problem areas

### **Post-Event Analysis**
1. Examine outage distribution patterns
2. Analyze crew response effectiveness
3. Review event source reliability
4. Document geographic impact areas

## 🔧 Configuration Options

### **Map Center**
- Default: New York City area (40.7128, -74.0060)
- Zoom level: 12 (neighborhood view)
- Easily configurable for different regions

### **Data Time Range**
- Default: 7 days of historical data
- Configurable via API parameter
- Real-time events always included

### **Marker Clustering**
- Future enhancement for high-density areas
- Reduces visual clutter
- Improves performance with many markers

## 📈 Performance Considerations

### **Optimization Features**
- Layer-based marker management
- Efficient marker creation and updates
- Minimal DOM manipulation
- Cached map data

### **Scalability**
- Handles hundreds of markers efficiently
- Responsive to map interactions
- Memory-efficient marker management
- Smooth zoom and pan operations

## 🔮 Future Enhancements

### **Planned Features**
1. **Real-time Crew Tracking** - GPS integration for live crew positions
2. **Weather Overlay** - Storm tracking and weather data integration
3. **Predictive Analytics** - AI-powered outage prediction zones
4. **Mobile App Integration** - Native mobile map interface
5. **3D Visualization** - Elevation and underground asset views
6. **Custom Basemaps** - Satellite imagery and custom map tiles
7. **Drawing Tools** - Manual outage area marking
8. **Export Functions** - Map screenshots and data exports

### **Integration Opportunities**
- **GIS Systems** - Integration with existing geographic information systems
- **Weather APIs** - Real-time weather data overlay
- **Traffic Data** - Crew routing optimization
- **Customer Data** - Customer location and impact visualization

## 🛡️ Security & Privacy

### **Data Protection**
- No sensitive customer information in map data
- Anonymized location coordinates
- Secure API endpoints with authentication
- Audit logging for map access

### **Access Control**
- Role-based map access permissions
- Sensitive asset location protection
- Crew privacy considerations
- Data retention policies

---

## 📞 Support & Maintenance

For technical support or feature requests related to the map visualization:

1. **API Issues**: Check `/api/oms/map/data` endpoint status
2. **Display Problems**: Verify Leaflet.js library loading
3. **Performance Issues**: Monitor marker count and layer complexity
4. **Data Accuracy**: Validate coordinate data in source systems

The map visualization provides a powerful tool for outage management, combining geographic awareness with real-time operational data to enhance decision-making and response effectiveness.

---

*Last Updated: September 25, 2025*
*Version: 1.0*

