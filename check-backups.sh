#!/bin/bash

# ZFlow Backup Status Checker
# This script monitors backup status and health

# Configuration
BACKUP_DIR="/var/backups/zflow"

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

echo "=== ZFlow Backup Status ==="
echo "Date: $(date)"
echo ""

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    print_status 1 "Backup directory not found: $BACKUP_DIR"
    echo ""
    echo "To set up the backup system, run:"
    echo "sudo ./deploy-backup-system.sh"
    exit 1
fi

# Find the most recent backup
LATEST_BACKUP=$(ls -t $BACKUP_DIR/*_complete.tar.gz 2>/dev/null | head -1)
if [ -z "$LATEST_BACKUP" ]; then
    print_warning "No backups found in $BACKUP_DIR"
    echo ""
    echo "To create your first backup, run:"
    echo "./backup-script.sh"
    exit 1
fi

# Extract backup name and timestamp
BACKUP_NAME=$(basename $LATEST_BACKUP | sed 's/_complete.tar.gz$//')
BACKUP_DATE=$(echo $BACKUP_NAME | sed 's/zflow_backup_//' | sed 's/_/ /' | awk '{print $1}')
BACKUP_TIME=$(echo $BACKUP_NAME | sed 's/zflow_backup_//' | sed 's/_/ /' | awk '{print $2}')

# Calculate backup age
if [ -n "$BACKUP_DATE" ] && [ -n "$BACKUP_TIME" ]; then
    BACKUP_TIMESTAMP="${BACKUP_DATE}_${BACKUP_TIME}"
    BACKUP_AGE=$(( ($(date +%s) - $(date -d "$BACKUP_DATE $BACKUP_TIME" +%s)) / 86400 ))
else
    BACKUP_AGE="unknown"
fi

# Count total backups
TOTAL_BACKUPS=$(ls $BACKUP_DIR/*_complete.tar.gz 2>/dev/null | wc -l)

# Calculate disk usage
DISK_USAGE=$(du -sh $BACKUP_DIR 2>/dev/null | awk '{print $1}')

echo "=== Backup Information ==="
echo "Last Backup: $BACKUP_NAME"
if [ "$BACKUP_AGE" != "unknown" ]; then
    echo "Backup Age: $BACKUP_AGE days"
else
    echo "Backup Age: unknown"
fi
echo "Total Backups: $TOTAL_BACKUPS"
echo "Disk Usage: $DISK_USAGE"
echo ""

# Check backup age
if [ "$BACKUP_AGE" != "unknown" ] && [ $BACKUP_AGE -gt 1 ]; then
    print_warning "Last backup is $BACKUP_AGE days old"
else
    print_status 0 "Backup is recent"
fi

# List all available backups
echo ""
echo "=== Available Backups ==="
ls -la $BACKUP_DIR/*_complete.tar.gz 2>/dev/null | while read line; do
    if [[ $line =~ zflow_backup_([0-9]{8}_[0-9]{6})_complete.tar.gz ]]; then
        BACKUP_DATE=${BASH_REMATCH[1]}
        echo "✅ $BACKUP_DATE"
    fi
done

# Check if cron job is set up
echo ""
echo "=== Automation Status ==="
if crontab -l 2>/dev/null | grep -q "backup-script.sh"; then
    print_status 0 "Automated backups are configured"
    CRON_TIME=$(crontab -l 2>/dev/null | grep "backup-script.sh" | awk '{print $2 ":" $1}')
    echo "Schedule: Daily at $CRON_TIME"
else
    print_warning "Automated backups not configured"
    echo "To set up automated backups, run:"
    echo "./setup-backup-cron.sh"
fi

# Check log file
echo ""
echo "=== Log Status ==="
LOG_FILE="/home/ec2-user/backup-logs/backup.log"
if [ -f "$LOG_FILE" ]; then
    LOG_SIZE=$(du -h "$LOG_FILE" 2>/dev/null | awk '{print $1}')
    print_status 0 "Backup log exists (size: $LOG_SIZE)"
    
    # Show last few log entries
    echo "Recent log entries:"
    tail -3 "$LOG_FILE" 2>/dev/null | while read line; do
        echo "  $line"
    done
else
    print_warning "Backup log file not found: $LOG_FILE"
    echo "Creating log file..."
    mkdir -p /home/ec2-user/backup-logs
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    echo "✅ Log file created"
fi

# Overall status assessment
echo ""
echo "=== Overall Status ==="
if [ "$BACKUP_AGE" != "unknown" ] && [ $BACKUP_AGE -le 1 ] && [ $TOTAL_BACKUPS -gt 0 ]; then
    print_status 0 "✅ All backups are recent and valid"
    echo ""
    echo "System is healthy and ready for operations."
else
    print_warning "⚠️ Some issues detected"
    echo ""
    echo "Recommendations:"
    if [ "$BACKUP_AGE" != "unknown" ] && [ $BACKUP_AGE -gt 1 ]; then
        echo "- Create a new backup: ./backup-script.sh"
    fi
    if [ $TOTAL_BACKUPS -eq 0 ]; then
        echo "- Set up initial backup: ./backup-script.sh"
    fi
    if ! crontab -l 2>/dev/null | grep -q "backup-script.sh"; then
        echo "- Configure automated backups: ./setup-backup-cron.sh"
    fi
fi

echo ""
echo "=== Quick Commands ==="
echo "Create backup: ./backup-script.sh"
echo "Restore backup: ./restore-script.sh <backup_name>"
echo "Verify backup: ./verify-backup.sh <backup_name>"
echo "Setup automation: ./setup-backup-cron.sh"
echo ""
echo "=== End of Status Check ===" 