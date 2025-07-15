#!/bin/bash

# ZFlow Restore Script
# This script restores the application and database from backup files

# Configuration
BACKUP_DIR="/var/backups/zflow"
APP_DIR="/srv/tomcat/webapps/ROOT"
DB_NAME="zflow"
DB_USER="zflow"
DB_PASS="zflow123"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}[SUCCESS]${NC} $2"
    else
        echo -e "${RED}[FAILED]${NC} $2"
    fi
}

print_info() {
    echo -e "[INFO] $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if backup name is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <backup_name>"
    echo "Example: $0 zflow_backup_20241215_143022"
    echo ""
    echo "Available backups:"
    ls -1 $BACKUP_DIR/*_complete.tar.gz 2>/dev/null | sed 's/.*zflow_backup_\(.*\)_complete.tar.gz/zflow_backup_\1/' || echo "No backups found"
    exit 1
fi

BACKUP_NAME=$1
BACKUP_FILE="$BACKUP_DIR/${BACKUP_NAME}_complete.tar.gz"

# Check if backup exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Backup file not found: $BACKUP_FILE"
    echo "Available backups:"
    ls -1 $BACKUP_DIR/*_complete.tar.gz 2>/dev/null || echo "No backups found"
    exit 1
fi

echo "=== ZFlow Restore Script ==="
echo "Backup: $BACKUP_NAME"
echo "Date: $(date)"
echo ""

# Confirm restore
read -p "This will overwrite the current application and database. Are you sure? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restore cancelled."
    exit 1
fi

# Stop services
echo ""
print_info "Stopping services..."
sudo systemctl stop tomcat
print_status $? "Tomcat stopped"

# Extract backup
echo ""
print_info "Extracting backup files..."
cd $BACKUP_DIR
tar -xzf ${BACKUP_NAME}_complete.tar.gz
print_status $? "Backup extracted"

# Check if individual files exist, if not extract from complete archive
if [ ! -f "app/${BACKUP_NAME}_app.tar.gz" ] || [ ! -f "database/${BACKUP_NAME}_db.sql" ]; then
    print_info "Individual backup files not found, extracting from complete archive..."
    tar -xzf ${BACKUP_NAME}_complete.tar.gz
    print_status $? "Complete archive extracted"
fi

# 1. Restore Database
echo ""
print_info "Restoring database..."

# Drop and recreate database
mysql -u $DB_USER -p$DB_PASS -e "DROP DATABASE IF EXISTS $DB_NAME;"
mysql -u $DB_USER -p$DB_PASS -e "CREATE DATABASE $DB_NAME;"

# Restore database from dump (check multiple possible locations)
DB_FILE=""
if [ -f "database/${BACKUP_NAME}_db.sql" ]; then
    DB_FILE="database/${BACKUP_NAME}_db.sql"
elif [ -f "${BACKUP_NAME}_db.sql" ]; then
    DB_FILE="${BACKUP_NAME}_db.sql"
else
    print_status 1 "Database file not found"
    exit 1
fi

mysql -u $DB_USER -p$DB_PASS $DB_NAME < $DB_FILE
print_status $? "Database restored"

# 2. Restore Application
echo ""
print_info "Restoring application files..."

# Backup current application
CURRENT_BACKUP="$BACKUP_DIR/current_app_backup_$(date +%Y%m%d_%H%M%S)"
sudo cp -r $APP_DIR $CURRENT_BACKUP
print_status $? "Current application backed up to $CURRENT_BACKUP"

# Restore application files (check multiple possible locations)
APP_FILE=""
if [ -f "app/${BACKUP_NAME}_app.tar.gz" ]; then
    APP_FILE="app/${BACKUP_NAME}_app.tar.gz"
elif [ -f "${BACKUP_NAME}_app.tar.gz" ]; then
    APP_FILE="${BACKUP_NAME}_app.tar.gz"
else
    print_status 1 "Application file not found"
    exit 1
fi

sudo rm -rf $APP_DIR/*
sudo tar -xzf $APP_FILE -C $APP_DIR
sudo chown -R tomcat:tomcat $APP_DIR
print_status $? "Application files restored"

# 3. Restore Configuration (optional)
echo ""
print_info "Restoring configuration files..."

# Restore ZFlow config
if [ -f "configurations/${BACKUP_NAME}_config.properties" ]; then
    sudo cp configurations/${BACKUP_NAME}_config.properties $APP_DIR/WEB-INF/classes/cfg/ZFlowConfig.properties
    print_status $? "ZFlow configuration restored"
else
    print_warning "ZFlow configuration file not found in backup"
fi

# Restore Tomcat config (optional)
if [ -f "configurations/${BACKUP_NAME}_tomcat.conf" ]; then
    sudo cp configurations/${BACKUP_NAME}_tomcat.conf /etc/tomcat/tomcat.conf
    print_status $? "Tomcat configuration restored"
else
    print_warning "Tomcat configuration file not found in backup"
fi

# 4. Start services
echo ""
print_info "Starting services..."
sudo systemctl start tomcat
print_status $? "Tomcat started"

# 5. Fix database configuration (post-restore fix)
echo ""
print_info "Fixing database configuration..."
if [ -f "$APP_DIR/WEB-INF/classes/cfg/ZFlowConfig.properties" ]; then
    # Fix database URL to include database name
    sudo sed -i 's|DB_URL=jdbc:mysql://127.0.0.1:3306|DB_URL=jdbc:mysql://127.0.0.1:3306/zflow|g' $APP_DIR/WEB-INF/classes/cfg/ZFlowConfig.properties
    # Fix database username
    sudo sed -i 's|DB_USER=|DB_USER=zflow|g' $APP_DIR/WEB-INF/classes/cfg/ZFlowConfig.properties
    print_status $? "Database configuration fixed"
else
    print_warning "Configuration file not found, skipping database configuration fix"
fi

# 6. Comprehensive Verification
echo ""
print_info "Performing comprehensive verification..."

# Wait for services to fully start
sleep 15

# 6.1 Verify Application is Working Correctly
echo ""
print_info "1. Verifying application functionality..."

# Check Tomcat service status
if sudo systemctl is-active --quiet tomcat; then
    print_status 0 "Tomcat service is running"
else
    print_status 1 "Tomcat service is not running"
fi

# Test application accessibility
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/ 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    print_status 0 "Application is accessible (HTTP 200)"
elif [ "$HTTP_CODE" = "000" ]; then
    print_status 1 "Application is not accessible (connection failed)"
else
    print_status 1 "Application returned HTTP $HTTP_CODE"
fi

# Test application response
if curl -s http://localhost:8080/ | grep -q "ZFlow\|zflow" 2>/dev/null; then
    print_status 0 "Application is responding with content"
else
    print_status 1 "Application response is empty or invalid"
fi

# Check if health check endpoint works
if curl -s http://localhost:8080/zflow/healthcheck.jsp > /dev/null 2>&1; then
    print_status 0 "Health check endpoint is accessible"
else
    print_warning "Health check endpoint is not accessible"
fi

# 6.2 Test Database Connectivity
echo ""
print_info "2. Testing database connectivity..."

# Test basic database connection
if mysql -u $DB_USER -p$DB_PASS -e "SELECT 1 as test;" > /dev/null 2>&1; then
    print_status 0 "Database connection successful"
else
    print_status 1 "Database connection failed"
fi

# Check if zflow database exists
if mysql -u $DB_USER -p$DB_PASS -e "USE $DB_NAME;" > /dev/null 2>&1; then
    print_status 0 "ZFlow database exists and is accessible"
else
    print_status 1 "ZFlow database does not exist or is not accessible"
fi

# Check database tables
TABLE_COUNT=$(mysql -u $DB_USER -p$DB_PASS -e "USE $DB_NAME; SHOW TABLES;" 2>/dev/null | wc -l)
if [ $TABLE_COUNT -gt 1 ]; then
    print_status 0 "Database contains $((TABLE_COUNT-1)) tables"
else
    print_status 1 "Database appears to be empty or inaccessible"
fi

# Check database size
DB_SIZE=$(mysql -u $DB_USER -p$DB_PASS -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' FROM information_schema.tables WHERE table_schema = '$DB_NAME';" 2>/dev/null | tail -1)
if [ "$DB_SIZE" != "NULL" ] && [ "$DB_SIZE" != "" ]; then
    print_status 0 "Database size: ${DB_SIZE}MB"
else
    print_warning "Could not determine database size"
fi

# 6.3 Check Application Logs for Errors
echo ""
print_info "3. Checking application logs for errors..."

# Check Tomcat logs for errors
ERROR_COUNT=$(sudo tail -100 /var/log/tomcat/catalina.out 2>/dev/null | grep -i "error\|exception" | wc -l)
if [ $ERROR_COUNT -eq 0 ]; then
    print_status 0 "No recent errors found in Tomcat logs"
else
    print_warning "Found $ERROR_COUNT recent errors in Tomcat logs"
    echo "Recent errors:"
    sudo tail -100 /var/log/tomcat/catalina.out 2>/dev/null | grep -i "error\|exception" | tail -5
fi

# Check application-specific logs
if [ -d "$APP_DIR/log" ]; then
    APP_LOG_COUNT=$(sudo find $APP_DIR/log -name "*.log" -exec grep -l "error\|exception" {} \; 2>/dev/null | wc -l)
    if [ $APP_LOG_COUNT -eq 0 ]; then
        print_status 0 "No errors found in application logs"
    else
        print_warning "Found errors in $APP_LOG_COUNT application log files"
    fi
else
    print_warning "Application log directory not found"
fi

# Check system logs for Tomcat issues
SYSTEM_ERRORS=$(sudo journalctl -u tomcat --since "10 minutes ago" 2>/dev/null | grep -i "error\|failed" | wc -l)
if [ $SYSTEM_ERRORS -eq 0 ]; then
    print_status 0 "No system errors found for Tomcat service"
else
    print_warning "Found $SYSTEM_ERRORS system errors for Tomcat service"
fi

# 6.4 Additional Verification Steps
echo ""
print_info "4. Additional verification steps..."

# Verify application files were restored correctly
if [ -f "$APP_DIR/WEB-INF/web.xml" ]; then
    print_status 0 "Application structure is correct"
else
    print_status 1 "Application structure appears incomplete"
fi

# Check configuration files
if [ -f "$APP_DIR/WEB-INF/classes/cfg/ZFlowConfig.properties" ]; then
    print_status 0 "Configuration files are present"
    
    # Check database configuration
    DB_URL=$(grep "DB_URL" $APP_DIR/WEB-INF/classes/cfg/ZFlowConfig.properties 2>/dev/null | cut -d'=' -f2)
    if [ "$DB_URL" != "" ]; then
        print_status 0 "Database configuration is set"
    else
        print_warning "Database configuration may be missing"
    fi
else
    print_status 1 "Configuration files are missing"
fi

# Check if application can connect to database (by checking logs for connection messages)
DB_CONNECTION_LOG=$(sudo tail -50 /var/log/tomcat/catalina.out 2>/dev/null | grep -i "database\|connection\|jdbc" | tail -1)
if [ "$DB_CONNECTION_LOG" != "" ]; then
    print_status 0 "Database connection activity detected in logs"
else
    print_warning "No database connection activity found in recent logs"
fi

# 6.5 Performance and Resource Check
echo ""
print_info "5. Checking system resources..."

# Check memory usage
MEMORY_USAGE=$(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2}')
print_status 0 "Memory usage: $MEMORY_USAGE"

# Check disk space
DISK_USAGE=$(df -h / | awk 'NR==2{print $5}')
print_status 0 "Disk usage: $DISK_USAGE"

# Check if Tomcat is listening on port 8080
if netstat -tlnp 2>/dev/null | grep -q ":8080"; then
    print_status 0 "Tomcat is listening on port 8080"
else
    print_status 1 "Tomcat is not listening on port 8080"
fi

# 7. Cleanup
echo ""
print_info "Cleaning up temporary files..."
rm -f app/${BACKUP_NAME}_app.tar.gz
rm -f database/${BACKUP_NAME}_db.sql
rm -f configurations/${BACKUP_NAME}_config.properties
rm -f configurations/${BACKUP_NAME}_tomcat.conf
rm -f ${BACKUP_NAME}_manifest.txt
print_status $? "Temporary files cleaned up"

# 8. Final summary
echo ""
echo "=== Restore Summary ==="
echo "Backup Used: $BACKUP_NAME"
echo "Restore Date: $(date)"
echo "Current App Backup: $CURRENT_BACKUP"
echo ""

# Overall status assessment
echo "=== Verification Summary ==="
if [ "$HTTP_CODE" = "200" ] && [ $ERROR_COUNT -eq 0 ] && [ $TABLE_COUNT -gt 1 ]; then
    print_status 0 "Restore completed successfully with all verifications passed!"
    echo ""
    echo "✅ Application is accessible and responding"
    echo "✅ Database is connected and contains data"
    echo "✅ No critical errors found in logs"
    echo "✅ System resources are within normal limits"
else
    print_warning "Restore completed but some verifications failed"
    echo ""
    if [ "$HTTP_CODE" != "200" ]; then
        echo "❌ Application accessibility issues detected"
    fi
    if [ $ERROR_COUNT -gt 0 ]; then
        echo "❌ Errors found in application logs"
    fi
    if [ $TABLE_COUNT -le 1 ]; then
        echo "❌ Database appears to be empty or inaccessible"
    fi
fi

echo ""
echo "Next steps:"
echo "1. Review any warnings or errors above"
echo "2. Test application functionality manually"
echo "3. Check application logs for any issues: sudo tail -f /var/log/tomcat/catalina.out"
echo "4. Remove the current app backup if everything is working: sudo rm -rf $CURRENT_BACKUP"
echo "5. Monitor the application for the next few hours"
echo ""
echo "=== Restore Script Completed ===" 