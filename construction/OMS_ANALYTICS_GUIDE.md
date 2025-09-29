# OMS Analytics & Reporting System

## 🚀 **Advanced Analytics Dashboard - Now Live!**

Your OMS system now includes a comprehensive analytics and reporting platform that provides deep insights into outage patterns, crew performance, source reliability, and customer impact.

## 📊 **Analytics Dashboard Access**

- **Analytics Dashboard**: http://localhost:9300
- **Main OMS Dashboard**: http://localhost:9200
- **OMS API**: http://localhost:9100

## 🔍 **Available Analytics Endpoints**

### **1. Outage Trends Analysis**
```bash
GET /api/oms/analytics/outage-trends?days=30&granularity=day&outage_type=outage&severity=critical
```

**Features:**
- ✅ **Time-based trends** with configurable granularity (hour/day/week/month)
- ✅ **Severity distribution** analysis
- ✅ **Confidence score trends**
- ✅ **Customer impact over time**
- ✅ **Restoration time patterns**
- ✅ **Filter by outage type and severity**

**Use Cases:**
- Identify peak outage periods
- Analyze seasonal patterns
- Monitor system reliability trends
- Plan preventive maintenance schedules

### **2. Crew Performance Analytics**
```bash
GET /api/oms/analytics/crew-performance?days=30&crew_name=Line%20Crew%20Alpha&assignment_type=repair
```

**Features:**
- ✅ **Completion rates** by crew and assignment type
- ✅ **Response time analysis** (dispatch to arrival)
- ✅ **Work duration tracking** (on-site to completion)
- ✅ **On-time arrival rates**
- ✅ **Assignment volume analysis**

**Use Cases:**
- Evaluate crew efficiency
- Optimize resource allocation
- Identify training needs
- Performance benchmarking

### **3. Source Reliability Analysis**
```bash
GET /api/oms/analytics/source-reliability?days=30
```

**Features:**
- ✅ **Accuracy rates** by source type (SCADA, Kaifa, ONU, Call Center)
- ✅ **Event volume analysis**
- ✅ **Correlation effectiveness**
- ✅ **High-confidence outage contribution**
- ✅ **Restoration rate analysis**

**Use Cases:**
- Validate source system reliability
- Prioritize source investments
- Optimize correlation algorithms
- Quality assurance monitoring

### **4. Geographic Hotspot Analysis**
```bash
GET /api/oms/analytics/geographic-hotspots?days=30&min_outages=2&radius_km=5.0
```

**Features:**
- ✅ **Clustering algorithm** for outage concentration
- ✅ **Configurable radius** and minimum outage thresholds
- ✅ **Severity breakdown** by location
- ✅ **Customer impact mapping**
- ✅ **Time period analysis**

**Use Cases:**
- Identify problem areas for infrastructure investment
- Plan preventive maintenance routes
- Risk assessment and mitigation
- Geographic service quality analysis

### **5. Customer Impact Analysis**
```bash
GET /api/oms/analytics/customer-impact?days=30&granularity=day
```

**Features:**
- ✅ **Customer impact trends** over time
- ✅ **Major vs minor outage** classification
- ✅ **Restoration time impact** on customers
- ✅ **Service level monitoring**
- ✅ **Critical outage identification**

**Use Cases:**
- Customer service planning
- SLA compliance monitoring
- Impact assessment for management reporting
- Service quality improvement

## 📈 **Analytics Dashboard Features**

### **Interactive Charts & Visualizations:**
- **Line Charts** - Trend analysis over time
- **Bar Charts** - Comparative performance metrics
- **Doughnut Charts** - Distribution analysis
- **Area Charts** - Cumulative impact visualization
- **Stacked Charts** - Multi-dimensional analysis

### **Real-time Controls:**
- **Time Period Selection** - 7, 30, 90, 365 days
- **Granularity Options** - Hour, day, week, month
- **Filter Controls** - Source, severity, type filters
- **Geographic Parameters** - Radius, minimum thresholds

### **Professional Reporting:**
- **Summary Statistics** - Key performance indicators
- **Trend Analysis** - Historical pattern identification
- **Performance Metrics** - Crew and system efficiency
- **Geographic Insights** - Location-based analytics

## 🎯 **Dashboard Tabs & Sections**

### **📊 Outage Trends Tab**
- **Outage Trends Over Time** - Volume and pattern analysis
- **Severity Distribution** - Critical, high, medium, low breakdown
- **Customer Impact Trends** - Affected customer patterns
- **Restoration Time Trends** - Recovery time analysis

### **👷 Crew Performance Tab**
- **Crew Completion Rates** - Success rate by crew
- **Response Time Trends** - Dispatch to arrival analysis
- **Work Duration Analysis** - On-site efficiency metrics
- **Assignment Volume** - Workload distribution

### **🖥️ Source Reliability Tab**
- **Source Event Distribution** - Volume by source type
- **Accuracy Rate Analysis** - Reliability comparison
- **Correlation Effectiveness** - System integration metrics
- **High-Confidence Contributions** - Quality source identification

### **🗺️ Geographic Analysis Tab**
- **Hotspot Identification** - Problem area clustering
- **Severity Mapping** - Geographic severity distribution
- **Customer Impact Mapping** - Location-based impact analysis
- **Time-based Patterns** - Geographic trend analysis

### **👥 Customer Impact Tab**
- **Impact Trends** - Customer service level analysis
- **Major vs Minor Outages** - Service disruption classification
- **Restoration Impact** - Recovery time effect on customers
- **Critical Event Analysis** - High-impact outage identification

## 📋 **Sample Analytics Queries**

### **Management Reports:**
```bash
# Monthly outage summary
curl "http://localhost:9100/api/oms/analytics/outage-trends?days=30&granularity=month"

# Crew performance for Q4
curl "http://localhost:9100/api/oms/analytics/crew-performance?days=90"

# Source reliability assessment
curl "http://localhost:9100/api/oms/analytics/source-reliability?days=30"
```

### **Operations Planning:**
```bash
# Geographic hotspots for maintenance planning
curl "http://localhost:9100/api/oms/analytics/geographic-hotspots?days=90&radius_km=10.0"

# Peak outage hours analysis
curl "http://localhost:9100/api/oms/analytics/outage-trends?days=30&granularity=hour"

# Customer impact assessment
curl "http://localhost:9100/api/oms/analytics/customer-impact?days=30&granularity=day"
```

### **Performance Monitoring:**
```bash
# Daily crew efficiency
curl "http://localhost:9100/api/oms/analytics/crew-performance?days=7"

# Weekly source accuracy
curl "http://localhost:9100/api/oms/analytics/source-reliability?days=7"

# Critical outage patterns
curl "http://localhost:9100/api/oms/analytics/outage-trends?days=30&severity=critical"
```

## 🎨 **Dashboard Customization**

### **Chart Types Available:**
- **Line Charts** - Perfect for trend analysis
- **Bar Charts** - Ideal for comparisons
- **Doughnut Charts** - Great for distributions
- **Area Charts** - Excellent for cumulative data
- **Stacked Charts** - Multi-dimensional analysis

### **Color Schemes:**
- **Blue** (#3498db) - Primary metrics
- **Red** (#e74c3c) - Critical/urgent data
- **Orange** (#f39c12) - Warning/attention
- **Green** (#27ae60) - Success/positive
- **Purple** (#9b59b6) - Special metrics

### **Interactive Features:**
- **Hover Tooltips** - Detailed data on hover
- **Zoom & Pan** - Chart navigation
- **Legend Controls** - Show/hide data series
- **Export Options** - Save charts as images
- **Responsive Design** - Works on all devices

## 📊 **Key Performance Indicators (KPIs)**

### **System Reliability:**
- **Outage Frequency** - Events per time period
- **Confidence Scores** - System accuracy
- **Restoration Times** - Recovery efficiency
- **Source Accuracy** - Input reliability

### **Operational Efficiency:**
- **Crew Response Times** - Dispatch to arrival
- **Completion Rates** - Work success rates
- **Resource Utilization** - Crew workload
- **Geographic Coverage** - Service area analysis

### **Customer Impact:**
- **Customers Affected** - Service disruption scale
- **Major Outages** - High-impact events
- **Restoration Impact** - Recovery time effect
- **Service Levels** - SLA compliance

## 🚀 **Getting Started with Analytics**

### **1. Access the Dashboard:**
Open http://localhost:9300 in your browser

### **2. Select Time Period:**
Choose from 7, 30, 90, or 365 days

### **3. Adjust Granularity:**
Select hourly, daily, weekly, or monthly views

### **4. Explore Different Tabs:**
Navigate between trends, performance, sources, geographic, and impact analysis

### **5. Use Filters:**
Apply specific filters for detailed analysis

### **6. Export Data:**
Use API endpoints for custom reporting and integration

## 🔧 **Integration & Automation**

### **API Integration:**
- **RESTful endpoints** for all analytics
- **JSON responses** for easy integration
- **Configurable parameters** for custom analysis
- **Real-time data** from live OMS system

### **Automated Reporting:**
- **Scheduled reports** via API calls
- **Email integration** for management updates
- **Dashboard embedding** in existing systems
- **Custom alerts** based on analytics thresholds

### **Data Export:**
- **CSV format** for spreadsheet analysis
- **JSON format** for system integration
- **Chart exports** for presentations
- **PDF reports** for documentation

## 🎉 **Your Analytics System is Ready!**

You now have a **comprehensive analytics and reporting platform** that provides:

- ✅ **Deep insights** into outage patterns and trends
- ✅ **Performance analytics** for crews and systems
- ✅ **Geographic analysis** for infrastructure planning
- ✅ **Customer impact** assessment and monitoring
- ✅ **Source reliability** validation and optimization
- ✅ **Interactive dashboards** with professional visualizations
- ✅ **Real-time data** from your live OMS system
- ✅ **Exportable reports** for management and compliance

**Access your analytics dashboard at: http://localhost:9300**

**Ready for advanced reporting, trend analysis, and data-driven decision making!** 📊🚀

