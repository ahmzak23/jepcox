# 🌊 OMS Animated Flow Visualization Guide

## Overview

The OMS Animated Flow Visualization, inspired by the [Travelscope project](https://www.markuslerner.com/travelscope/), provides a dynamic representation of how outage events and alerts flow from clients/meters across Jordan to JEPCO's headquarters in Amman. This creates a powerful visual metaphor for data transmission and system connectivity.

## 🎯 Key Features

### **Animated Data Flow**
- **Dashed Line Animation** - Moving dashed lines that simulate data packets flowing to JEPCO HQ
- **Color-Coded Severity** - Lines colored by outage severity (Critical: Red, High: Orange, Medium: Yellow, Low: Green)
- **Real-time Animation** - Continuous flow animation showing active data transmission
- **Staggered Timing** - Random offsets create natural, non-synchronized flow patterns

### **Geographic Context**
- **Centered on Jordan** - Map focused on Amman, Jordan (JEPCO headquarters location)
- **JEPCO HQ Marker** - Prominent pulsing red marker at headquarters (31.9539, 35.9106)
- **Regional Coverage** - Events distributed across Jordanian cities (Amman, Zarqa, Irbid, Salt, Madaba, Karak, Aqaba, Mafraq)
- **Realistic Coordinates** - Authentic Jordanian geographic positioning

### **Interactive Controls**
- **Flow Toggle** - Turn animation on/off with a single click
- **Speed Control** - Adjust animation speed (100ms, 200ms, 500ms, 1000ms cycles)
- **Layer Management** - Show/hide flow lines independently
- **Real-time Updates** - Animation refreshes with new data automatically

## 🛠️ Technical Implementation

### **Animation Technology**
Based on the [Travelscope GitHub repository](https://github.com/markuslerner/travelscope/tree/master), the implementation uses:

- **Leaflet.js Polylines** - SVG-based dashed lines with CSS animations
- **JavaScript Intervals** - Smooth 100ms update cycles for fluid motion
- **CSS Keyframes** - Hardware-accelerated dash offset animations
- **Dynamic Styling** - Real-time opacity and dash pattern updates

### **Flow Line Creation**
```javascript
function createAnimatedFlowLine(startPoint, endPoint, color, severity, id) {
    const polyline = L.polyline([startPoint, endPoint], {
        color: color,
        weight: 3,
        opacity: 0.8,
        dashArray: '10, 10',
        className: `flow-line flow-${severity}`
    });
    
    // Add animation data
    polyline.flowData = {
        id: id,
        startPoint: startPoint,
        endPoint: endPoint,
        color: color,
        severity: severity,
        animationOffset: Math.random() * 100 // Staggered timing
    };
    
    return polyline;
}
```

### **Animation Engine**
```javascript
function animateFlowLine(line, index) {
    const now = Date.now();
    const speed = 2000; // 2 seconds per cycle
    const progress = ((now + line.flowData.animationOffset) % speed) / speed;
    
    // Create animated dash pattern
    const dashLength = 15;
    const gapLength = 10;
    const totalLength = dashLength + gapLength;
    const dashOffset = -progress * totalLength;
    
    line.setStyle({
        dashOffset: dashOffset,
        opacity: 0.6 + 0.4 * Math.sin(progress * Math.PI * 2)
    });
}
```

## 🎨 Visual Design

### **Color Scheme**
- **Critical Outages**: `#dc3545` (Red) - Highest priority alerts
- **High Priority**: `#fd7e14` (Orange) - Important events requiring attention
- **Medium Priority**: `#ffc107` (Yellow) - Standard outage reports
- **Low Priority**: `#28a745` (Green) - Minor incidents and routine reports

### **JEPCO Headquarters Marker**
- **Large Red Circle** - 40px diameter with white border
- **Pulsing Animation** - Continuous scale and shadow animation
- **Building Icon** - FontAwesome building icon for clear identification
- **Central Position** - Always visible as the destination hub

### **Flow Line Styling**
- **Dashed Pattern** - 10px dashes with 10px gaps
- **Weight**: 3px for clear visibility
- **Opacity**: 0.6-1.0 with sine wave variation
- **Animation**: Smooth dash offset movement

## 🎮 User Interface

### **Flow Control Panel**
Located in the top-right corner of the map:

```
┌─────────────────────────┐
│ 🌊 Flow Animation       │
│ ▶️ Animation On         │
│ 🏃 Speed: 100ms        │
│ Showing data flow to    │
│ JEPCO HQ                │
└─────────────────────────┘
```

### **Control Functions**
1. **Toggle Animation** - Start/stop flow animation
2. **Speed Adjustment** - Cycle through 4 speed settings
3. **Layer Toggle** - Show/hide flow lines in main controls
4. **Auto-refresh** - Animation updates with new data

### **Map Integration**
- **Layer Management** - Flow lines as separate Leaflet layer group
- **Performance Optimized** - Efficient rendering with minimal CPU usage
- **Responsive Design** - Works on all screen sizes and devices

## 📊 Data Flow Visualization

### **Source Types**
The animation shows data flow from multiple sources:

1. **SCADA Events** - High-priority breaker trips and equipment failures
2. **Kaifa Smart Meters** - Last-gasp signals from customer meters
3. **ONU Devices** - Network equipment power loss notifications
4. **Call Center Reports** - Customer outage reports and complaints
5. **Active Outages** - Confirmed outage events requiring attention

### **Flow Characteristics**
- **Direction**: All lines flow toward JEPCO headquarters in Amman
- **Density**: Higher density around headquarters (visual convergence)
- **Timing**: Staggered animation creates natural flow patterns
- **Persistence**: Lines remain visible while data is active

### **Real-time Updates**
- **New Events**: Automatically create new flow lines
- **Status Changes**: Update line colors based on severity changes
- **Data Refresh**: Complete flow recalculation every 30 seconds
- **Performance**: Smooth 60fps animation with minimal lag

## 🌍 Geographic Context

### **Jordan Coverage**
The visualization covers major Jordanian cities:

- **Amman** - Capital city and JEPCO headquarters location
- **Zarqa** - Industrial city with significant power infrastructure
- **Irbid** - Northern Jordan's largest city
- **Salt** - Historic city with mixed urban/rural coverage
- **Madaba** - Central Jordan with tourism and agriculture
- **Karak** - Southern Jordan with rural and urban areas
- **Aqaba** - Red Sea port city with industrial needs
- **Mafraq** - Northern border region with refugee populations

### **Coordinate System**
- **Center Point**: 31.9539°N, 35.9106°E (Amman)
- **Zoom Level**: 10 (city/regional view)
- **Coverage Radius**: ~50km from headquarters
- **Coordinate Accuracy**: Real-world geographic positioning

## 🚀 Usage Scenarios

### **Storm Response**
1. **Activate Flow View** - Enable animation during storm events
2. **Monitor Incoming Data** - Watch as reports flow in from affected areas
3. **Assess Coverage** - Identify areas with heavy data flow (high impact)
4. **Track Response** - Observe flow reduction as crews restore service

### **Routine Monitoring**
1. **Daily Operations** - Monitor normal data flow patterns
2. **System Health** - Verify all source systems are transmitting
3. **Geographic Analysis** - Identify areas with consistent issues
4. **Performance Metrics** - Measure data transmission effectiveness

### **Training & Demonstration**
1. **System Overview** - Show how data flows through the OMS
2. **Source Education** - Demonstrate different event types and sources
3. **Geographic Awareness** - Familiarize operators with service areas
4. **Response Procedures** - Illustrate data-driven decision making

## 🔧 Configuration Options

### **Animation Settings**
```javascript
// Configurable parameters
const ANIMATION_CONFIG = {
    updateInterval: 100,        // Milliseconds between updates
    cycleDuration: 2000,        // Complete animation cycle time
    dashLength: 15,             // Length of each dash
    gapLength: 10,              // Length of gaps between dashes
    opacityRange: [0.6, 1.0],   // Min/max opacity values
    lineWeight: 3               // Stroke width in pixels
};
```

### **Performance Tuning**
- **Update Frequency**: Adjustable from 50ms to 1000ms
- **Line Density**: Configurable maximum lines per view
- **Animation Quality**: High/medium/low quality modes
- **Memory Management**: Automatic cleanup of inactive lines

## 📈 Performance Considerations

### **Optimization Features**
- **Efficient Rendering**: SVG-based lines with CSS animations
- **Staggered Updates**: Prevents frame rate drops
- **Memory Management**: Automatic cleanup of old animations
- **Responsive Scaling**: Adapts to map zoom levels

### **Scalability**
- **Line Limits**: Handles up to 1000+ simultaneous flow lines
- **Browser Compatibility**: Works on all modern browsers
- **Mobile Support**: Touch-optimized for mobile devices
- **Network Efficiency**: Minimal bandwidth usage

## 🔮 Future Enhancements

### **Planned Features**
1. **Bidirectional Flow** - Show data flowing back to field devices
2. **Flow Intensity** - Vary line thickness based on data volume
3. **Temporal Animation** - Show historical flow patterns over time
4. **3D Visualization** - Add elevation and depth to flow lines
5. **Sound Effects** - Audio feedback for critical events
6. **Flow Analytics** - Statistical analysis of data flow patterns

### **Integration Opportunities**
- **Weather Overlay** - Show storm tracks affecting data flow
- **Traffic Integration** - Display crew movement alongside data flow
- **Predictive Analytics** - AI-powered flow prediction
- **Augmented Reality** - AR visualization for field crews

## 🛡️ Technical Specifications

### **Browser Requirements**
- **Modern Browsers**: Chrome 60+, Firefox 55+, Safari 12+, Edge 79+
- **JavaScript**: ES6+ support required
- **CSS**: CSS3 animations and transforms
- **Performance**: Hardware acceleration recommended

### **Mobile Compatibility**
- **iOS**: iOS 12+ with WebKit
- **Android**: Android 7+ with Chrome
- **Touch Support**: Optimized touch interactions
- **Responsive**: Adapts to all screen sizes

## 📞 Support & Troubleshooting

### **Common Issues**
1. **Animation Not Starting**: Check browser console for JavaScript errors
2. **Poor Performance**: Reduce animation speed or disable on low-end devices
3. **Lines Not Visible**: Verify flow lines layer is enabled
4. **Coordinate Issues**: Ensure map data includes valid latitude/longitude

### **Debugging Tools**
- **Console Logging**: Detailed animation state information
- **Performance Monitoring**: FPS and memory usage tracking
- **Layer Inspector**: Visual debugging of Leaflet layers
- **Network Analysis**: API response timing and data validation

---

## 🎯 Conclusion

The OMS Animated Flow Visualization transforms abstract data transmission into an intuitive, engaging visual experience. By showing how outage events flow from across Jordan to JEPCO's headquarters in Amman, operators can better understand system connectivity, data flow patterns, and geographic relationships.

This implementation, inspired by the innovative [Travelscope visualization](https://www.markuslerner.com/travelscope/), provides a powerful tool for outage management, training, and system monitoring that enhances situational awareness and improves decision-making capabilities.

---

*Last Updated: September 25, 2025*  
*Version: 1.0*  
*Inspired by: [Travelscope - Interactive WebGL worldmap](https://www.markuslerner.com/travelscope/)*

