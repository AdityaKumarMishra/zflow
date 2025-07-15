#!/bin/bash

# ZFlow Backup Cron Setup Script
# This script sets up automated daily backups

# Configuration
BACKUP_SCRIPT="/home/ec2-user/backup-script.sh"
CRON_USER="ec2-user"
BACKUP_TIME="02:00"  # 2 AM daily

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

echo "=== ZFlow Backup Cron Setup ==="
echo "This will set up automated daily backups at $BACKUP_TIME"
echo ""

# 1. Copy backup script to user home
print_info "Copying backup script to user home..."
if [ ! -f "$BACKUP_SCRIPT" ] || [ "$(readlink -f backup-script.sh)" != "$(readlink -f $BACKUP_SCRIPT)" ]; then
    cp backup-script.sh $BACKUP_SCRIPT
fi
chmod +x $BACKUP_SCRIPT
print_status $? "Backup script copied and made executable"

# 2. Create backup directory
print_info "Creating backup directory..."
sudo mkdir -p /var/backups/zflow
sudo chown $CRON_USER:users /var/backups/zflow
print_status $? "Backup directory created"

# 3. Create log directory
print_info "Creating log directory..."
mkdir -p /home/$CRON_USER/backup-logs
print_status $? "Log directory created"

# 4. Set up cron job
print_info "Setting up cron job for daily backups..."

# Remove existing cron job if it exists
crontab -l 2>/dev/null | grep -v "backup-script.sh" | crontab -

# Add new cron job
(crontab -l 2>/dev/null; echo "0 2 * * * $BACKUP_SCRIPT >> /home/$CRON_USER/backup-logs/backup.log 2>&1") | crontab -

print_status $? "Cron job scheduled for daily backups at $BACKUP_TIME"

# 5. Create backup monitoring script
print_info "Creating backup monitoring script..."

cat > /home/$CRON_USER/check-backups.sh << 'EOF'
#!/bin/bash

# ZFlow Backup Monitoring Script
BACKUP_DIR="/var/backups/zflow"
LOG_FILE="/home/ec2-user/backup-logs/backup.log"
RETENTION_DAYS=7

echo "=== ZFlow Backup Status ==="
echo "Date: $(date)"
echo ""

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ Backup directory does not exist: $BACKUP_DIR"
    exit 1
fi

# List recent backups
echo "📁 Recent Backups:"
ls -lh $BACKUP_DIR/*_complete.tar.gz 2>/dev/null | tail -7 || echo "No backups found"

echo ""

# Check backup age
LATEST_BACKUP=$(ls -t $BACKUP_DIR/*_complete.tar.gz 2>/dev/null | head -1)
if [ -n "$LATEST_BACKUP" ]; then
    BACKUP_AGE=$(find $LATEST_BACKUP -printf '%AY-%Am-%Ad %AH:%AM\n' 2>/dev/null)
    echo "📅 Latest Backup: $(basename $LATEST_BACKUP)"
    echo "🕒 Backup Age: $BACKUP_AGE"
    
    # Check if backup is older than 24 hours
    BACKUP_AGE_HOURS=$(( ($(date +%s) - $(stat -c %Y $LATEST_BACKUP)) / 3600 ))
    if [ $BACKUP_AGE_HOURS -gt 24 ]; then
        echo "⚠️  WARNING: Latest backup is $BACKUP_AGE_HOURS hours old"
    else
        echo "✅ Backup is recent ($BACKUP_AGE_HOURS hours old)"
    fi
else
    echo "❌ No backups found"
fi

echo ""

# Check backup sizes
echo "📊 Backup Sizes:"
du -sh $BACKUP_DIR/*_complete.tar.gz 2>/dev/null | sort -hr | head -5 || echo "No backup files found"

echo ""

# Check log file
if [ -f "$LOG_FILE" ]; then
    echo "📋 Recent Log Entries:"
    tail -10 $LOG_FILE 2>/dev/null || echo "No log entries found"
else
    echo "❌ Log file not found: $LOG_FILE"
fi

echo ""

# Check disk space
echo "💾 Disk Space:"
df -h $BACKUP_DIR | tail -1

echo ""
echo "=== Backup Status Check Complete ==="
EOF

chmod +x /home/$CRON_USER/check-backups.sh
print_status $? "Backup monitoring script created"

# 6. Create backup cleanup script
print_info "Creating backup cleanup script..."

cat > /home/$CRON_USER/cleanup-backups.sh << 'EOF'
#!/bin/bash

# ZFlow Backup Cleanup Script
BACKUP_DIR="/var/backups/zflow"
RETENTION_DAYS=7

echo "=== ZFlow Backup Cleanup ==="
echo "Date: $(date)"
echo "Retention: $RETENTION_DAYS days"
echo ""

# Count files before cleanup
BEFORE_COUNT=$(find $BACKUP_DIR -name "zflow_backup_*" -type f | wc -l)
echo "Files before cleanup: $BEFORE_COUNT"

# Remove old backup files
find $BACKUP_DIR -name "zflow_backup_*" -type f -mtime +$RETENTION_DAYS -delete
find $BACKUP_DIR -name "zflow_backup_*" -type d -mtime +$RETENTION_DAYS -exec rm -rf {} + 2>/dev/null || true

# Count files after cleanup
AFTER_COUNT=$(find $BACKUP_DIR -name "zflow_backup_*" -type f | wc -l)
REMOVED=$((BEFORE_COUNT - AFTER_COUNT))

echo "Files after cleanup: $AFTER_COUNT"
echo "Files removed: $REMOVED"

echo ""
echo "=== Cleanup Complete ==="
EOF

chmod +x /home/$CRON_USER/cleanup-backups.sh
print_status $? "Backup cleanup script created"

# 7. Test backup script
print_info "Testing backup script..."
$BACKUP_SCRIPT > /dev/null 2>&1
if [ $? -eq 0 ]; then
    print_status 0 "Backup script test successful"
else
    print_status 1 "Backup script test failed - check manually"
fi

# 8. Final summary
echo ""
echo "=== Backup Setup Summary ==="
echo "✅ Backup script: $BACKUP_SCRIPT"
echo "✅ Backup directory: /var/backups/zflow"
echo "✅ Cron job: Daily at $BACKUP_TIME"
echo "✅ Log file: /home/$CRON_USER/backup-logs/backup.log"
echo "✅ Monitoring script: /home/$CRON_USER/check-backups.sh"
echo "✅ Cleanup script: /home/$CRON_USER/cleanup-backups.sh"
echo "✅ Retention: 7 days"
echo ""

echo "📋 Manual Commands:"
echo "• Run backup manually: $BACKUP_SCRIPT"
echo "• Check backup status: /home/$CRON_USER/check-backups.sh"
echo "• Clean old backups: /home/$CRON_USER/cleanup-backups.sh"
echo "• View cron jobs: crontab -l"
echo "• View backup logs: tail -f /home/$CRON_USER/backup-logs/backup.log"
echo ""

print_status 0 "Backup automation setup completed!"
echo ""
echo "Next steps:"
echo "1. Verify the first backup runs tomorrow at $BACKUP_TIME"
echo "2. Monitor backup logs for any issues"
echo "3. Test restore functionality if needed"
echo "4. Consider setting up backup monitoring alerts"
echo ""
echo "=== Setup Complete ===" 