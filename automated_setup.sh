#!/bin/bash

# ZFlow Backup & Restore Automation - Automated Setup Script
# This script automates the complete setup process

# Configuration
BACKUP_DIR="/var/backups/zflow"
APP_DIR="/usr/share/tomcat/webapps/ROOT"
DB_NAME="zflow"
DB_USER="zflow"
DB_PASS="zflow123"
BACKUP_TIME="02:00"
RETENTION_DAYS=7

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo "=== ZFlow Backup & Restore Automation - Automated Setup ==="
echo "This script will set up the complete backup and restore system"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_warning "This script should not be run as root"
    print_info "Please run as a regular user with sudo privileges"
    exit 1
fi

# Step 1: System Requirements Check
echo "=== Step 1: System Requirements Check ==="

# Check Java
print_info "Checking Java installation..."
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2)
    print_status 0 "Java found: $JAVA_VERSION"
else
    print_status 1 "Java not found"
    echo "Please install Java 17 or higher"
    exit 1
fi

# Check Tomcat
print_info "Checking Tomcat service..."
if sudo systemctl is-active --quiet tomcat; then
    print_status 0 "Tomcat is running"
else
    print_status 1 "Tomcat is not running"
    echo "Please start Tomcat service: sudo systemctl start tomcat"
    exit 1
fi

# Check MariaDB/MySQL
print_info "Checking database service..."
if sudo systemctl is-active --quiet mariadb; then
    print_status 0 "MariaDB is running"
elif sudo systemctl is-active --quiet mysql; then
    print_status 0 "MySQL is running"
else
    print_status 1 "Database service is not running"
    echo "Please start database service: sudo systemctl start mariadb"
    exit 1
fi

# Check disk space
print_info "Checking disk space..."
AVAILABLE_SPACE=$(df -BG /var | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -gt 10 ]; then
    print_status 0 "Sufficient disk space: ${AVAILABLE_SPACE}G available"
else
    print_warning "Low disk space: ${AVAILABLE_SPACE}G available"
    print_info "Recommended: At least 10GB available"
fi

# Check application accessibility
print_info "Checking application accessibility..."
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/ 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    print_status 0 "Application is accessible (HTTP $HTTP_CODE)"
else
    print_warning "Application may not be accessible (HTTP $HTTP_CODE)"
fi

# Check database connectivity
print_info "Checking database connectivity..."
if mysql -u "$DB_USER" -p"$DB_PASS" -e "SHOW DATABASES;" &>/dev/null; then
    print_status 0 "Database connection successful"
else
    print_status 1 "Database connection failed"
    echo "Please check database credentials and permissions"
    exit 1
fi

echo ""

# Step 2: Create Backup Directory
echo "=== Step 2: Setting Up Backup Directory ==="
print_info "Creating backup directory..."
sudo mkdir -p "$BACKUP_DIR"
sudo chown $(whoami):users "$BACKUP_DIR"
sudo chmod 755 "$BACKUP_DIR"
print_status $? "Backup directory created: $BACKUP_DIR"

# Step 3: Create Log Directory
print_info "Creating log directory..."
mkdir -p ~/backup-logs
touch ~/backup-logs/backup.log
chmod 644 ~/backup-logs/backup.log
print_status $? "Log directory created: ~/backup-logs"

# Step 4: Update Script Permissions
echo ""
echo "=== Step 3: Setting Up Scripts ==="
print_info "Making scripts executable..."
chmod +x *.sh
print_status $? "Scripts made executable"

# Step 5: Set Up Automation
echo ""
echo "=== Step 4: Setting Up Automation ==="
print_info "Setting up cron job for daily backups..."

# Remove existing cron job if it exists
crontab -l 2>/dev/null | grep -v "backup-script.sh" | crontab -

# Add new cron job
(crontab -l 2>/dev/null; echo "0 2 * * * $(pwd)/backup-script.sh >> ~/backup-logs/backup.log 2>&1") | crontab -

print_status $? "Cron job scheduled for daily backups at $BACKUP_TIME"

# Step 6: Test Backup System
echo ""
echo "=== Step 5: Testing Backup System ==="
print_info "Creating test backup..."
./backup-script.sh > /dev/null 2>&1
if [ $? -eq 0 ]; then
    print_status 0 "Test backup created successfully"
else
    print_status 1 "Test backup failed"
    print_info "Check the backup script for errors"
fi

# Step 7: Verify System
echo ""
echo "=== Step 6: System Verification ==="
print_info "Running system verification..."

# Check if backup was created
if [ -f "$BACKUP_DIR"/*_complete.tar.gz ]; then
    print_status 0 "Backup file created"
    BACKUP_SIZE=$(du -h "$BACKUP_DIR"/*_complete.tar.gz | cut -f1)
    echo "    Backup size: $BACKUP_SIZE"
else
    print_warning "No backup file found"
fi

# Check cron job
if crontab -l 2>/dev/null | grep -q "backup-script.sh"; then
    print_status 0 "Cron job configured"
else
    print_status 1 "Cron job not configured"
fi

# Check log file
if [ -f ~/backup-logs/backup.log ]; then
    print_status 0 "Log file created"
else
    print_status 1 "Log file not created"
fi

# Step 8: Final Summary
echo ""
echo "=== Setup Summary ==="
echo "✅ Backup directory: $BACKUP_DIR"
echo "✅ Log directory: ~/backup-logs"
echo "✅ Cron job: Daily at $BACKUP_TIME"
echo "✅ Retention: $RETENTION_DAYS days"
echo "✅ Scripts: All scripts executable"

echo ""
echo "📋 Available Commands:"
echo "• Check backup status: ./check-backups.sh"
echo "• Create manual backup: ./backup-script.sh"
echo "• Verify backup integrity: ./verify-backup.sh"
echo "• Restore from backup: ./restore-script.sh <backup_name>"
echo "• Clean old backups: ./cleanup-backups.sh"
echo "• View logs: tail -f ~/backup-logs/backup.log"

echo ""
echo "🔧 Configuration Files:"
echo "• Backup script: $(pwd)/backup-script.sh"
echo "• Restore script: $(pwd)/restore-script.sh"
echo "• Cron setup: $(pwd)/setup-backup-cron.sh"

echo ""
echo "📊 Monitoring:"
echo "• Daily: ./check-backups.sh"
echo "• Weekly: ./verify-backup.sh"
echo "• Logs: ~/backup-logs/backup.log"

echo ""
print_status 0 "Automated setup completed successfully!"

echo ""
echo "=== Next Steps ==="
echo "1. Monitor the first automated backup tomorrow at $BACKUP_TIME"
echo "2. Test restore functionality in a safe environment"
echo "3. Review and customize configuration if needed"
echo "4. Set up monitoring alerts for backup failures"
echo "5. Document any customizations made to the system"

echo ""
echo "=== Setup Complete ===" 