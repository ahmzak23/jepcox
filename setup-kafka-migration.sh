#!/bin/bash

# Kafka Migration Script
# This script exports and imports Kafka topics, consumer groups, and configurations
# Can be used for backup, migration, or replication

set -e

# Configuration
KAFKA_BROKER="${KAFKA_BROKER:-localhost:9093}"
KAFKA_CONTAINER="${KAFKA_CONTAINER:-apisix-workshop-kafka}"
EXPORT_DIR="${EXPORT_DIR:-./kafka_export}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Kafka Migration Tool${NC}"
echo -e "${GREEN}========================${NC}"
echo ""

# Function to check if Kafka is running
check_kafka() {
    echo -e "${YELLOW}⏳ Checking Kafka connectivity...${NC}"
    if docker exec $KAFKA_CONTAINER kafka-broker-api-versions --bootstrap-server $KAFKA_BROKER > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Kafka is accessible${NC}"
        return 0
    else
        echo -e "${RED}❌ Cannot connect to Kafka${NC}"
        return 1
    fi
}

# Function to export topics
export_topics() {
    echo ""
    echo -e "${CYAN}📦 Exporting Kafka Topics...${NC}"
    
    mkdir -p $EXPORT_DIR/topics
    
    # Get list of topics
    TOPICS=$(docker exec $KAFKA_CONTAINER kafka-topics --bootstrap-server $KAFKA_BROKER --list 2>/dev/null | grep -v "^__" || true)
    
    if [ -z "$TOPICS" ]; then
        echo -e "${YELLOW}⚠️  No topics found to export${NC}"
        return
    fi
    
    echo "$TOPICS" > $EXPORT_DIR/topics/topic_list.txt
    echo -e "${GREEN}   Found $(echo "$TOPICS" | wc -l) topics${NC}"
    
    # Export each topic configuration
    for topic in $TOPICS; do
        echo -e "   Exporting topic: ${BLUE}$topic${NC}"
        docker exec $KAFKA_CONTAINER kafka-topics --bootstrap-server $KAFKA_BROKER \
            --describe --topic $topic > $EXPORT_DIR/topics/${topic}_config.txt 2>/dev/null || true
        
        # Get topic configurations
        docker exec $KAFKA_CONTAINER kafka-configs --bootstrap-server $KAFKA_BROKER \
            --entity-type topics --entity-name $topic --describe \
            > $EXPORT_DIR/topics/${topic}_settings.txt 2>/dev/null || true
    done
    
    echo -e "${GREEN}✅ Topics exported to: $EXPORT_DIR/topics/${NC}"
}

# Function to export consumer groups
export_consumer_groups() {
    echo ""
    echo -e "${CYAN}👥 Exporting Consumer Groups...${NC}"
    
    mkdir -p $EXPORT_DIR/consumer_groups
    
    # Get list of consumer groups
    GROUPS=$(docker exec $KAFKA_CONTAINER kafka-consumer-groups --bootstrap-server $KAFKA_BROKER --list 2>/dev/null || true)
    
    if [ -z "$GROUPS" ]; then
        echo -e "${YELLOW}⚠️  No consumer groups found to export${NC}"
        return
    fi
    
    echo "$GROUPS" > $EXPORT_DIR/consumer_groups/group_list.txt
    echo -e "${GREEN}   Found $(echo "$GROUPS" | wc -l) consumer groups${NC}"
    
    # Export each consumer group details
    for group in $GROUPS; do
        echo -e "   Exporting group: ${BLUE}$group${NC}"
        docker exec $KAFKA_CONTAINER kafka-consumer-groups --bootstrap-server $KAFKA_BROKER \
            --group $group --describe > $EXPORT_DIR/consumer_groups/${group}_details.txt 2>/dev/null || true
        
        # Export offsets
        docker exec $KAFKA_CONTAINER kafka-consumer-groups --bootstrap-server $KAFKA_BROKER \
            --group $group --describe --offsets \
            > $EXPORT_DIR/consumer_groups/${group}_offsets.txt 2>/dev/null || true
    done
    
    echo -e "${GREEN}✅ Consumer groups exported to: $EXPORT_DIR/consumer_groups/${NC}"
}

# Function to export broker configuration
export_broker_config() {
    echo ""
    echo -e "${CYAN}⚙️  Exporting Broker Configuration...${NC}"
    
    mkdir -p $EXPORT_DIR/broker
    
    # Get broker list
    docker exec $KAFKA_CONTAINER kafka-broker-api-versions --bootstrap-server $KAFKA_BROKER \
        > $EXPORT_DIR/broker/broker_info.txt 2>/dev/null || true
    
    # Get cluster info
    docker exec $KAFKA_CONTAINER kafka-metadata --bootstrap-server $KAFKA_BROKER \
        --snapshot /tmp/snapshot.txt 2>/dev/null || true
    
    echo -e "${GREEN}✅ Broker configuration exported to: $EXPORT_DIR/broker/${NC}"
}

# Function to create migration script
create_import_script() {
    echo ""
    echo -e "${CYAN}📝 Creating Import Script...${NC}"
    
    cat > $EXPORT_DIR/import_kafka.sh << 'EOF'
#!/bin/bash

# Kafka Import Script
# This script imports topics and consumer groups to a new Kafka cluster

set -e

KAFKA_BROKER="${KAFKA_BROKER:-localhost:9093}"
KAFKA_CONTAINER="${KAFKA_CONTAINER:-apisix-workshop-kafka}"
IMPORT_DIR="."

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${GREEN}🚀 Kafka Import Tool${NC}"
echo -e "${GREEN}====================${NC}"

# Import topics
if [ -f "$IMPORT_DIR/topics/topic_list.txt" ]; then
    echo -e "${CYAN}📦 Importing Topics...${NC}"
    
    while IFS= read -r topic; do
        [ -z "$topic" ] && continue
        
        echo -e "   Creating topic: ${BLUE}$topic${NC}"
        
        # Extract partition count and replication factor from config
        if [ -f "$IMPORT_DIR/topics/${topic}_config.txt" ]; then
            PARTITIONS=$(grep "PartitionCount:" "$IMPORT_DIR/topics/${topic}_config.txt" | awk '{print $2}' || echo "3")
            REPLICATION=$(grep "ReplicationFactor:" "$IMPORT_DIR/topics/${topic}_config.txt" | awk '{print $2}' || echo "1")
        else
            PARTITIONS=3
            REPLICATION=1
        fi
        
        docker exec $KAFKA_CONTAINER kafka-topics --bootstrap-server $KAFKA_BROKER \
            --create --topic $topic \
            --partitions $PARTITIONS \
            --replication-factor $REPLICATION \
            --if-not-exists 2>/dev/null || echo "   Topic $topic already exists or failed to create"
        
    done < "$IMPORT_DIR/topics/topic_list.txt"
    
    echo -e "${GREEN}✅ Topics imported${NC}"
fi

echo ""
echo -e "${GREEN}✅ Import completed!${NC}"
echo -e "${YELLOW}Note: Consumer group offsets cannot be automatically restored.${NC}"
echo -e "${YELLOW}Consumer groups will be recreated when consumers start.${NC}"
EOF
    
    chmod +x $EXPORT_DIR/import_kafka.sh
    echo -e "${GREEN}✅ Import script created: $EXPORT_DIR/import_kafka.sh${NC}"
}

# Function to create backup archive
create_backup_archive() {
    echo ""
    echo -e "${CYAN}📦 Creating Backup Archive...${NC}"
    
    ARCHIVE_NAME="kafka_backup_${TIMESTAMP}.tar.gz"
    tar -czf $ARCHIVE_NAME -C $(dirname $EXPORT_DIR) $(basename $EXPORT_DIR)
    
    echo -e "${GREEN}✅ Backup archive created: $ARCHIVE_NAME${NC}"
    echo -e "${GREEN}   Size: $(du -h $ARCHIVE_NAME | cut -f1)${NC}"
}

# Main export function
export_all() {
    echo -e "${MAGENTA}Starting full Kafka export...${NC}"
    
    if ! check_kafka; then
        echo -e "${RED}❌ Cannot proceed without Kafka connection${NC}"
        exit 1
    fi
    
    export_topics
    export_consumer_groups
    export_broker_config
    create_import_script
    create_backup_archive
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ Kafka Export Completed Successfully!${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}📁 Export Directory: $EXPORT_DIR${NC}"
    echo -e "${CYAN}📦 Backup Archive: kafka_backup_${TIMESTAMP}.tar.gz${NC}"
    echo ""
    echo -e "${YELLOW}To import on another server:${NC}"
    echo -e "  1. Copy the backup archive to the target server"
    echo -e "  2. Extract: tar -xzf kafka_backup_${TIMESTAMP}.tar.gz"
    echo -e "  3. Run: cd $(basename $EXPORT_DIR) && ./import_kafka.sh"
    echo ""
}

# Function to import from backup
import_all() {
    echo -e "${MAGENTA}Starting Kafka import...${NC}"
    
    if [ ! -f "$EXPORT_DIR/topics/topic_list.txt" ]; then
        echo -e "${RED}❌ No export data found in $EXPORT_DIR${NC}"
        exit 1
    fi
    
    if ! check_kafka; then
        echo -e "${RED}❌ Cannot proceed without Kafka connection${NC}"
        exit 1
    fi
    
    if [ -f "$EXPORT_DIR/import_kafka.sh" ]; then
        bash $EXPORT_DIR/import_kafka.sh
    else
        echo -e "${RED}❌ Import script not found${NC}"
        exit 1
    fi
}

# Parse command line arguments
case "${1:-export}" in
    export)
        export_all
        ;;
    import)
        import_all
        ;;
    topics)
        check_kafka && export_topics
        ;;
    groups)
        check_kafka && export_consumer_groups
        ;;
    *)
        echo "Usage: $0 {export|import|topics|groups}"
        echo ""
        echo "Commands:"
        echo "  export  - Export all Kafka data (default)"
        echo "  import  - Import Kafka data from export directory"
        echo "  topics  - Export only topics"
        echo "  groups  - Export only consumer groups"
        exit 1
        ;;
esac
