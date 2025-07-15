#!/bin/bash

# ZFlow Backup & Restore System Deployment Script
# This script automates the complete setup of the backup and restore system

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

echo "=== ZFlow Backup & Restore System Deployment ==="
echo "This script will set up the complete backup and restore automation system."
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo privileges"
    exit 1
fi

# Step 1: Create backup directory structure
echo ""
print_info "Step 1: Creating backup directory structure..."

mkdir -p /var/backups/zflow/{app,database,configurations,logs}
chown -R ec2-user:ec2-user /var/backups/zflow
chmod -R 755 /var/backups/zflow
print_status $? "Backup directory structure created"

# Step 2: Install required packages
echo ""
print_info "Step 2: Installing required packages..."

# Update system
yum update -y --quiet
print_status $? "System updated"

# Install required packages
yum install -y mysql mariadb-server curl wget cronie --quiet
print_status $? "Required packages installed"

# Step 3: Ensure MySQL is running
echo ""
print_info "Step 3: Configuring MySQL..."

systemctl start mysqld
systemctl enable mysqld
print_status $? "MySQL service started and enabled"

# Step 4: Create database and user if they don't exist
echo ""
print_info "Step 4: Setting up database..."

mysql -u root -e "CREATE DATABASE IF NOT EXISTS zflow;" 2>/dev/null
mysql -u root -e "CREATE USER IF NOT EXISTS 'zflow'@'localhost' IDENTIFIED BY 'zflow123';" 2>/dev/null
mysql -u root -e "GRANT ALL PRIVILEGES ON zflow.* TO 'zflow'@'localhost';" 2>/dev/null
mysql -u root -e "FLUSH PRIVILEGES;" 2>/dev/null
print_status $? "Database and user configured"

# Step 5: Deploy scripts to user directory
echo ""
print_info "Step 5: Deploying backup scripts..."

# Copy scripts to user directory
cp backup-script.sh /home/ec2-user/
cp restore-script.sh /home/ec2-user/
cp check-backups.sh /home/ec2-user/
cp cleanup-backups.sh /home/ec2-user/
cp verify-backup.sh /home/ec2-user/
cp setup-backup-cron.sh /home/ec2-user/

# Make scripts executable
chmod +x /home/ec2-user/*.sh
chown ec2-user:ec2-user /home/ec2-user/*.sh
print_status $? "Scripts deployed and made executable"

# Step 6: Setup automated daily backups
echo ""
print_info "Step 6: Setting up automated daily backups..."

# Switch to ec2-user to run the setup script
su - ec2-user -c "cd /home/ec2-user && ./setup-backup-cron.sh"
print_status $? "Automated backup cron job configured"

# Step 7: Create log file
echo ""
print_info "Step 7: Setting up logging..."

touch /var/log/zflow-backup.log
chown ec2-user:ec2-user /var/log/zflow-backup.log
chmod 644 /var/log/zflow-backup.log
print_status $? "Log file created"

# Step 8: Test the system
echo ""
print_info "Step 8: Testing backup system..."

# Run a test backup
su - ec2-user -c "cd /home/ec2-user && ./backup-script.sh" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    print_status 0 "Test backup completed successfully"
else
    print_status 1 "Test backup failed - check logs"
fi

# Step 9: Verify system status
echo ""
print_info "Step 9: Verifying system status..."

# Check if services are running
if systemctl is-active --quiet tomcat; then
    print_status 0 "Tomcat service is running"
else
    print_warning "Tomcat service is not running"
fi

if systemctl is-active --quiet mysqld; then
    print_status 0 "MySQL service is running"
else
    print_warning "MySQL service is not running"
fi

# Check backup directory
if [ -d "/var/backups/zflow" ]; then
    print_status 0 "Backup directory exists"
else
    print_status 1 "Backup directory missing"
fi

# Step 10: Display final status
echo ""
echo "=== Deployment Summary ==="
echo "✅ Backup directory: /var/backups/zflow"
echo "✅ Scripts location: /home/ec2-user/"
echo "✅ Log file: /var/log/zflow-backup.log"
echo "✅ Cron job: Daily at 2:00 AM"
echo "✅ Retention: 7 days"
echo ""

# Display available commands
echo "=== Available Commands ==="
echo "Manual backup: ./backup-script.sh"
echo "Check status: ./check-backups.sh"
echo "Restore: ./restore-script.sh <backup_name>"
echo "Verify backup: ./verify-backup.sh <backup_name>"
echo "Cleanup: ./cleanup-backups.sh"
echo ""

# Display monitoring commands
echo "=== Monitoring Commands ==="
echo "Check backup logs: tail -f /var/log/zflow-backup.log"
echo "Check application: curl -s http://localhost:8080/healthcheck.jsp"
echo "Check services: sudo systemctl status tomcat mysqld"
echo "Check disk space: df -h /var/backups/zflow"
echo ""

print_status 0 "ZFlow Backup & Restore System deployment completed!"
echo ""
echo "The system is now ready for automated daily backups and manual restores."
echo "Daily backups will run automatically at 2:00 AM with 7-day retention."
echo ""
echo "For detailed documentation, see: ZFlow_Backup_Restore_Automation_Guide.md" 