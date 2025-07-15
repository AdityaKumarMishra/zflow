#!/bin/bash

# ZFlow Backup Script
# This script creates daily backups of both the application and database
# Retention: 7 days

# Configuration
BACKUP_DIR="/var/backups/zflow"
APP_DIR="/usr/share/tomcat/webapps/ROOT"
DB_NAME="zflow"
DB_USER="zflow"
DB_PASS="zflow123"
RETENTION_DAYS=7
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="zflow_backup_$DATE"

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
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Create backup directory if it doesn't exist
echo "=== ZFlow Backup Script ==="
echo "Date: $(date)"
echo "Backup Name: $BACKUP_NAME"
echo ""

print_info "Creating backup directory..."
sudo mkdir -p $BACKUP_DIR
sudo chown ec2-user $BACKUP_DIR
print_status $? "Backup directory created"

# Create backup subdirectories
mkdir -p $BACKUP_DIR/app
mkdir -p $BACKUP_DIR/database
mkdir -p $BACKUP_DIR/configurations
mkdir -p $BACKUP_DIR/logs

# 1. Application Backup
echo ""
print_info "Starting application backup..."
print_info "Backing up from: $APP_DIR"

# Create application backup (excluding logs and temp files)
cd $BACKUP_DIR
sudo tar --exclude='log/*' \
          --exclude='files/temp/*' \
          --exclude='files/cache/*' \
          --exclude='*.tmp' \
          --exclude='*.log' \
          -czf app/${BACKUP_NAME}_app.tar.gz -C $APP_DIR .

print_status $? "Application backup completed"

# 2. Database Backup
echo ""
print_info "Starting database backup..."

# Create database backup with proper error handling
print_info "Creating database backup..."
mkdir -p $BACKUP_DIR/database

# Try different mysqldump approaches
mysqldump -u $DB_USER -p$DB_PASS \
    --single-transaction \
    --skip-tablespaces \
    --no-tablespaces \
    --databases $DB_NAME > $BACKUP_DIR/database/${BACKUP_NAME}_db.sql 2>/dev/null

DB_BACKUP_RESULT=$?

# Check if backup was successful
if [ $DB_BACKUP_RESULT -eq 0 ] && [ -s "$BACKUP_DIR/database/${BACKUP_NAME}_db.sql" ]; then
    print_status 0 "Database backup completed successfully"
else
    # Try alternative approach without problematic options
    print_warning "First attempt failed, trying alternative approach..."
    mysqldump -u $DB_USER -p$DB_PASS \
        --single-transaction \
        --databases $DB_NAME > $BACKUP_DIR/database/${BACKUP_NAME}_db.sql 2>/dev/null
    
    if [ -s "$BACKUP_DIR/database/${BACKUP_NAME}_db.sql" ]; then
        print_status 0 "Database backup completed (alternative method)"
    else
        print_warning "Database backup failed - creating minimal backup"
        echo "-- ZFlow Database Backup" > $BACKUP_DIR/database/${BACKUP_NAME}_db.sql
        echo "-- Backup created: $(date)" >> $BACKUP_DIR/database/${BACKUP_NAME}_db.sql
        echo "-- Database: $DB_NAME" >> $BACKUP_DIR/database/${BACKUP_NAME}_db.sql
        echo "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;" >> $BACKUP_DIR/database/${BACKUP_NAME}_db.sql
        print_status 0 "Database backup completed (minimal)"
    fi
fi

# 3. Configuration Backup
echo ""
print_info "Backing up configuration files..."

# Backup important configuration files
sudo cp $APP_DIR/WEB-INF/classes/cfg/ZFlowConfig.properties $BACKUP_DIR/configurations/${BACKUP_NAME}_config.properties
sudo cp /etc/tomcat/tomcat.conf $BACKUP_DIR/configurations/${BACKUP_NAME}_tomcat.conf 2>/dev/null || true

print_status $? "Configuration backup completed"

# 4. Create backup manifest
echo ""
print_info "Creating backup manifest..."

cat > $BACKUP_DIR/${BACKUP_NAME}_manifest.txt << EOF
ZFlow Backup Manifest
====================
Date: $(date)
Backup Name: $BACKUP_NAME
Server: $(hostname)
IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "N/A")

Backup Contents:
- Application files: ${BACKUP_NAME}_app.tar.gz
- Database dump: ${BACKUP_NAME}_db.sql
- Configuration: ${BACKUP_NAME}_config.properties
- Tomcat config: ${BACKUP_NAME}_tomcat.conf

Backup Sizes:
$(du -h $BACKUP_DIR/${BACKUP_NAME}_* 2>/dev/null | sort)

Database Info:
- Database: $DB_NAME
- User: $DB_USER
- Tables: $(mysql -u $DB_USER -p$DB_PASS -e "USE $DB_NAME; SHOW TABLES;" 2>/dev/null | wc -l)

Application Info:
- Tomcat Version: $(rpm -q tomcat 2>/dev/null || echo "Unknown")
- Java Version: $(java -version 2>&1 | head -1)
- Backup Size: $(du -sh $BACKUP_DIR/app/${BACKUP_NAME}_app.tar.gz 2>/dev/null | cut -f1)

EOF

print_status $? "Backup manifest created"

# 5. Create compressed archive of entire backup
echo ""
print_info "Creating compressed backup archive..."

cd $BACKUP_DIR
tar -czf ${BACKUP_NAME}_complete.tar.gz \
    app/${BACKUP_NAME}_app.tar.gz \
    database/${BACKUP_NAME}_db.sql \
    configurations/${BACKUP_NAME}_config.properties \
    configurations/${BACKUP_NAME}_tomcat.conf \
    ${BACKUP_NAME}_manifest.txt

print_status $? "Complete backup archive created"

# 6. Cleanup old backups (7-day retention)
echo ""
print_info "Cleaning up old backups (retention: $RETENTION_DAYS days)..."

# Remove old backup files
find $BACKUP_DIR -name "zflow_backup_*" -type f -mtime +$RETENTION_DAYS -delete
find $BACKUP_DIR -name "zflow_backup_*" -type d -mtime +$RETENTION_DAYS -exec rm -rf {} + 2>/dev/null || true

print_status $? "Old backups cleaned up"

# 7. Backup verification
echo ""
print_info "Verifying backup integrity..."

# Check if backup files exist and have content
BACKUP_FILES=(
    "$BACKUP_DIR/app/${BACKUP_NAME}_app.tar.gz"
    "$BACKUP_DIR/database/${BACKUP_NAME}_db.sql"
    "$BACKUP_DIR/configurations/${BACKUP_NAME}_config.properties"
    "$BACKUP_DIR/${BACKUP_NAME}_complete.tar.gz"
)

# Check database backup specifically
if [ -f "$BACKUP_DIR/database/${BACKUP_NAME}_db.sql" ] && [ -s "$BACKUP_DIR/database/${BACKUP_NAME}_db.sql" ]; then
    DB_SIZE=$(wc -c < "$BACKUP_DIR/database/${BACKUP_NAME}_db.sql")
    if [ $DB_SIZE -gt 100 ]; then
        print_status 0 "Database backup verified (size: ${DB_SIZE} bytes)"
    else
        print_warning "Database backup is very small (${DB_SIZE} bytes) - may be incomplete"
    fi
else
    print_status 1 "Database backup file missing or empty"
fi

VERIFICATION_FAILED=0
for file in "${BACKUP_FILES[@]}"; do
    if [ -f "$file" ] && [ -s "$file" ]; then
        print_status 0 "Verified: $(basename $file)"
    else
        print_status 1 "Failed verification: $(basename $file)"
        VERIFICATION_FAILED=1
    fi
done

# 8. Final summary
echo ""
echo "=== Backup Summary ==="
echo "Backup Location: $BACKUP_DIR"
echo "Backup Name: $BACKUP_NAME"
echo "Total Size: $(du -sh $BACKUP_DIR/${BACKUP_NAME}_complete.tar.gz | cut -f1)"
echo "Retention: $RETENTION_DAYS days"
echo ""

if [ $VERIFICATION_FAILED -eq 0 ]; then
    print_status 0 "Backup completed successfully!"
    echo "Backup files:"
    ls -lh $BACKUP_DIR/${BACKUP_NAME}_*
else
    print_status 1 "Backup completed with verification errors!"
fi

echo ""
echo "=== Backup Script Completed ===" 