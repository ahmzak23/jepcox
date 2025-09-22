#!/bin/bash
# Setup Enhanced Monitoring for OMS System

echo "🚀 Setting up Enhanced Monitoring for OMS System"
echo "=" * 60

# Create monitoring directories
mkdir -p prometheus_conf/rules
mkdir -p grafana_conf/dashboards
mkdir -p grafana_conf/provisioning/dashboards
mkdir -p grafana_conf/provisioning/datasources

# Copy Prometheus configuration
echo "📊 Setting up Prometheus configuration..."
cp prometheus_conf/prometheus.yml prometheus_conf/prometheus.yml.backup 2>/dev/null || true

# Copy Grafana dashboards
echo "📈 Setting up Grafana dashboards..."
cp grafana_conf/dashboards/*.json grafana_conf/provisioning/dashboards/ 2>/dev/null || true

# Create Grafana dashboard provisioning config
cat > grafana_conf/provisioning/dashboards/dashboard.yml << EOF
apiVersion: 1

providers:
  - name: 'OMS Dashboards'
    orgId: 1
    folder: 'OMS System'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

# Create Grafana datasource provisioning config
cat > grafana_conf/provisioning/datasources/datasource.yml << EOF
apiVersion: 1

datasources:
  - name: 'Prometheus'
    type: 'prometheus'
    access: 'proxy'
    url: 'http://prometheus:9090'
    isDefault: true
    editable: true
EOF

echo "✅ Monitoring setup complete!"
echo ""
echo "📋 Available Dashboards:"
echo "   🏠 OMS System Overview: http://localhost:3000/d/oms-system"
echo "   📊 Kafka Monitoring: http://localhost:3000/d/kafka-monitoring"
echo "   ⚡ APISIX Performance: http://localhost:3000/d/apisix-performance"
echo ""
echo "🔍 Monitoring Endpoints:"
echo "   📈 Prometheus: http://localhost:9090"
echo "   📊 Grafana: http://localhost:3000 (admin/admin)"
echo "   🖥️  APISIX Metrics: http://localhost:9080/metrics"
echo ""
echo "🚨 Alert Rules:"
echo "   - APISIX Gateway Health"
echo "   - Kafka Cluster Health"
echo "   - High Error Rates"
echo "   - Resource Usage"
echo "   - Consumer Lag"
echo ""
echo "💡 Next Steps:"
echo "   1. Access Grafana: http://localhost:3000"
echo "   2. Import dashboards from the dashboard list"
echo "   3. Configure alert notifications"
echo "   4. Set up custom metrics for your OMS application"
