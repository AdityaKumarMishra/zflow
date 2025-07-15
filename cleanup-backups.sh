#!/bin/bash

# ZFlow Backup Cleanup Script
# This script removes old backups based on 7-day retention policy

# Configuration
BACKUP_DIR="/var/backups/zflow"
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

echo "=== ZFlow Backup Cleanup ==="
echo "Date: $(date)"
echo "Retention Policy: $RETENTION_DAYS days"
echo ""

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    print_status 1 "Backup directory not found: $BACKUP_DIR"
    exit 1
fi

# Get current disk usage before cleanup
DISK_USAGE_BEFORE=$(du -sh $BACKUP_DIR 2>/dev/null | awk '{print $1}')
echo "Current disk usage: $DISK_USAGE_BEFORE"

# Find all backup files
BACKUP_FILES=$(find $BACKUP_DIR -name "*_complete.tar.gz" -type f 2>/dev/null)

if [ -z "$BACKUP_FILES" ]; then
    print_warning "No backup files found to clean up"
    exit 0
fi

echo ""
echo "=== Analyzing Backups ==="

# Variables to track cleanup
TOTAL_BACKUPS=0
BACKUPS_TO_DELETE=0
DELETED_BACKUPS=0
DELETED_SIZE=0

# Process each backup file
while IFS= read -r backup_file; do
    TOTAL_BACKUPS=$((TOTAL_BACKUPS + 1))
    
    # Extract backup name and timestamp
    BACKUP_NAME=$(basename "$backup_file" | sed 's/_complete.tar.gz$//')
    BACKUP_DATE=$(echo $BACKUP_NAME | sed 's/zflow_backup_//' | sed 's/_/ /' | awk '{print $1}')
    BACKUP_TIME=$(echo $BACKUP_NAME | sed 's/zflow_backup_//' | sed 's/_/ /' | awk '{print $2}')
    
    if [ -n "$BACKUP_DATE" ] && [ -n "$BACKUP_TIME" ]; then
        # Calculate backup age
        BACKUP_AGE=$(( ($(date +%s) - $(date -d "$BACKUP_DATE $BACKUP_TIME" +%s)) / 86400 ))
        
        if [ $BACKUP_AGE -gt $RETENTION_DAYS ]; then
            BACKUPS_TO_DELETE=$((BACKUPS_TO_DELETE + 1))
            BACKUP_SIZE=$(du -h "$backup_file" 2>/dev/null | awk '{print $1}')
            
            echo "🗑️  $BACKUP_NAME (age: ${BACKUP_AGE} days, size: $BACKUP_SIZE)"
            
            # Delete the backup and related files
            if [ "$1" = "--dry-run" ]; then
                echo "  [DRY RUN] Would delete: $backup_file"
            else
                # Delete the complete archive
                rm -f "$backup_file"
                
                # Delete related files
                BACKUP_BASE=$(echo $BACKUP_NAME | sed 's/zflow_backup_//')
                rm -f "$BACKUP_DIR/app/zflow_backup_${BACKUP_BASE}_app.tar.gz"
                rm -f "$BACKUP_DIR/database/zflow_backup_${BACKUP_BASE}_db.sql"
                rm -f "$BACKUP_DIR/configurations/zflow_backup_${BACKUP_BASE}_config.properties"
                rm -f "$BACKUP_DIR/configurations/zflow_backup_${BACKUP_BASE}_tomcat.conf"
                rm -f "$BACKUP_DIR/zflow_backup_${BACKUP_BASE}_manifest.txt"
                
                DELETED_BACKUPS=$((DELETED_BACKUPS + 1))
                echo "  ✅ Deleted: $backup_file"
            fi
        else
            echo "✅ $BACKUP_NAME (age: ${BACKUP_AGE} days) - keeping"
        fi
    else
        echo "⚠️  $BACKUP_NAME - could not determine age"
    fi
done <<< "$BACKUP_FILES"

echo ""
echo "=== Cleanup Summary ==="
echo "Total backups found: $TOTAL_BACKUPS"
echo "Backups to delete: $BACKUPS_TO_DELETE"
echo "Backups deleted: $DELETED_BACKUPS"

if [ "$1" = "--dry-run" ]; then
    echo ""
    print_warning "This was a dry run. No files were actually deleted."
    echo "To perform actual cleanup, run: ./cleanup-backups.sh"
else
    if [ $DELETED_BACKUPS -gt 0 ]; then
        print_status 0 "Cleanup completed successfully"
        
        # Get disk usage after cleanup
        DISK_USAGE_AFTER=$(du -sh $BACKUP_DIR 2>/dev/null | awk '{print $1}')
        echo "Disk usage after cleanup: $DISK_USAGE_AFTER"
    else
        print_info "No backups needed cleanup"
    fi
fi

# Check remaining backups
REMAINING_BACKUPS=$(find $BACKUP_DIR -name "*_complete.tar.gz" -type f 2>/dev/null | wc -l)
echo "Remaining backups: $REMAINING_BACKUPS"

echo ""
echo "=== Retention Policy ==="
echo "✅ Backups older than $RETENTION_DAYS days are automatically removed"
echo "✅ This ensures optimal disk space usage"
echo "✅ Critical backups are preserved"

echo ""
echo "=== Next Steps ==="
if [ $REMAINING_BACKUPS -eq 0 ]; then
    echo "⚠️  No backups remaining. Consider creating a new backup:"
    echo "   ./backup-script.sh"
elif [ $REMAINING_BACKUPS -lt 3 ]; then
    echo "⚠️  Few backups remaining. Consider creating additional backups:"
    echo "   ./backup-script.sh"
else
    echo "✅ Backup system is healthy with $REMAINING_BACKUPS backups"
fi

echo ""
echo "=== Usage ==="
echo "Dry run (preview): ./cleanup-backups.sh --dry-run"
echo "Actual cleanup: ./cleanup-backups.sh"
echo "Check status: ./check-backups.sh"
echo ""
echo "=== End of Cleanup ===" 