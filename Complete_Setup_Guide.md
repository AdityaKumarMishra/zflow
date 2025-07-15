# ZFlow Backup & Restore Automation - Complete Setup Guide

## Table of Contents
1. [System Requirements](#system-requirements)
2. [Pre-Installation Checklist](#pre-installation-checklist)
3. [Installation Steps](#installation-steps)
4. [Configuration](#configuration)
5. [Testing](#testing)
6. [Monitoring](#monitoring)
7. [Troubleshooting](#troubleshooting)
8. [Maintenance](#maintenance)
9. [Security Considerations](#security-considerations)
10. [Emergency Procedures](#emergency-procedures)

---

## System Requirements

### Hardware Requirements
- **CPU**: 2+ cores recommended
- **RAM**: 4GB minimum, 8GB recommended
- **Storage**: 50GB+ available space for backups
- **Network**: Stable internet connection

### Software Requirements
- **Operating System**: Linux (RHEL/CentOS/Amazon Linux/SUSE)
- **Java**: OpenJDK 17 or higher
- **Web Server**: Apache Tomcat 9+
- **Database**: MariaDB 10.5+ or MySQL 8.0+
- **Shell**: Bash 4.0+
- **Utilities**: tar, gzip, curl, wget

### Application Requirements
- **ZFlow Application**: Deployed and running
- **Database**: zflow database created
- **User**: Non-root user with sudo privileges

---

## Pre-Installation Checklist

### ✅ Verify System Components
```bash
# Check Java version
java -version

# Check Tomcat status
sudo systemctl status tomcat

# Check MariaDB/MySQL status
sudo systemctl status mariadb

# Check available disk space
df -h

# Check user permissions
whoami
sudo -l
```

### ✅ Verify Application Status
```bash
# Check if application is accessible
curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/

# Check application directory
ls -la /usr/share/tomcat/webapps/ROOT/

# Check database connectivity
mysql -u zflow -pzflow123 -e 'SHOW DATABASES;'
```

### ✅ Required Information
- [ ] Database credentials (username/password)
- [ ] Application directory path
- [ ] Tomcat service name
- [ ] Backup retention period (default: 7 days)
- [ ] Backup schedule (default: 2:00 AM daily)

---

## Installation Steps

### Step 1: Download and Extract
```bash
# Navigate to user home directory
cd ~

# Download the automation package (if not already present)
# wget <download-url> -O ZFlow_Backup_Restore_System.zip

# Extract the package
unzip ZFlow_Backup_Restore_System.zip

# Navigate to extracted directory
cd ZFlow_Backup_Restore_Clean

# Make scripts executable
chmod +x *.sh
```

### Step 2: Review Configuration
```bash
# Check the configuration in backup-script.sh
grep -n "BACKUP_DIR\|DB_NAME\|DB_USER\|DB_PASS\|APP_DIR" backup-script.sh

# Verify paths match your system
echo "Current application directory: /usr/share/tomcat/webapps/ROOT"
echo "Current database name: zflow"
echo "Current database user: zflow"
```

### Step 3: Update Configuration (if needed)
If your system uses different paths or credentials, edit the configuration in `backup-script.sh`:

```bash
# Edit the backup script
nano backup-script.sh

# Update these variables if needed:
# BACKUP_DIR="/var/backups/zflow"
# APP_DIR="/usr/share/tomcat/webapps/ROOT"
# DB_NAME="zflow"
# DB_USER="zflow"
# DB_PASS="zflow123"
```

### Step 4: Set Up Automation
```bash
# Run the setup script
./setup-backup-cron.sh
```

### Step 5: Test the System
```bash
# Test backup creation
./backup-script.sh

# Test backup verification
./verify-backup.sh

# Test backup status check
./check-backups.sh
```

---

## Configuration

### Backup Configuration
The system uses these default settings:

| Setting | Default Value | Description |
|---------|---------------|-------------|
| Backup Directory | `/var/backups/zflow` | Where backups are stored |
| Application Directory | `/usr/share/tomcat/webapps/ROOT` | ZFlow application files |
| Database Name | `zflow` | MariaDB/MySQL database |
| Database User | `zflow` | Database username |
| Database Password | `zflow123` | Database password |
| Retention Period | 7 days | How long to keep backups |
| Backup Schedule | 2:00 AM daily | Cron schedule |
| Log File | `/home/ec2-user/backup-logs/backup.log` | Backup operation logs |

### Customizing Configuration
To change any settings:

1. **Edit backup-script.sh**:
```bash
nano backup-script.sh
# Update the configuration variables at the top
```

2. **Edit setup-backup-cron.sh**:
```bash
nano setup-backup-cron.sh
# Update BACKUP_TIME variable for different schedule
```

3. **Re-run setup**:
```bash
./setup-backup-cron.sh
```

---

## Testing

### Test 1: Manual Backup
```bash
# Create a test backup
./backup-script.sh

# Check the backup was created
ls -la /var/backups/zflow/

# Verify backup integrity
./verify-backup.sh
```

### Test 2: Backup Status
```bash
# Check backup status
./check-backups.sh

# Expected output should show:
# ✅ Backup directory exists
# ✅ Recent backup found
# ✅ Backup is recent
# ✅ Disk usage is acceptable
```

### Test 3: Restore Test (Optional)
```bash
# Create a test backup first
./backup-script.sh

# Get the backup name
BACKUP_NAME=$(ls -t /var/backups/zflow/*_complete.tar.gz | head -1 | sed 's/.*\///' | sed 's/_complete.tar.gz//')

# Test restore (this will overwrite current application)
./restore-script.sh $BACKUP_NAME
```

### Test 4: Automation Test
```bash
# Check if cron job is set up
crontab -l

# Check log file
tail -f /home/ec2-user/backup-logs/backup.log

# Manually trigger a backup to test automation
./backup-script.sh
```

---

## Monitoring

### Daily Monitoring
```bash
# Check backup status daily
./check-backups.sh

# Check log file for errors
tail -20 /home/ec2-user/backup-logs/backup.log

# Check disk space
df -h /var/backups/zflow
```

### Weekly Monitoring
```bash
# Clean old backups (automatic, but can be run manually)
./cleanup-backups.sh

# Verify all backups
./verify-backup.sh

# Check system resources
free -h
df -h
```

### Monitoring Commands Reference

| Command | Purpose | Frequency |
|---------|---------|-----------|
| `./check-backups.sh` | Quick status check | Daily |
| `./verify-backup.sh` | Deep integrity check | Weekly |
| `tail -f backup-logs/backup.log` | Monitor live operations | As needed |
| `crontab -l` | Check automation status | Weekly |
| `df -h /var/backups/zflow` | Check disk usage | Daily |

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: Permission Denied
```bash
# Error: Permission denied when running scripts
# Solution: Make scripts executable
chmod +x *.sh
```

#### Issue 2: Backup Directory Not Found
```bash
# Error: Backup directory does not exist
# Solution: Create backup directory
sudo mkdir -p /var/backups/zflow
sudo chown ec2-user:users /var/backups/zflow
```

#### Issue 3: Database Connection Failed
```bash
# Error: Cannot connect to database
# Solution: Check database credentials and service
sudo systemctl status mariadb
mysql -u zflow -pzflow123 -e 'SHOW DATABASES;'
```

#### Issue 4: Tomcat Service Not Running
```bash
# Error: Cannot access application
# Solution: Start Tomcat service
sudo systemctl start tomcat
sudo systemctl enable tomcat
```

#### Issue 5: Disk Space Full
```bash
# Error: No space left on device
# Solution: Clean old backups
./cleanup-backups.sh
# Or manually remove old backups
find /var/backups/zflow -name "*.tar.gz" -mtime +7 -delete
```

#### Issue 6: Cron Job Not Working
```bash
# Error: Automated backups not running
# Solution: Check and fix cron setup
crontab -l
./setup-backup-cron.sh
```

### Log Analysis
```bash
# Check backup logs for errors
grep -i error /home/ec2-user/backup-logs/backup.log

# Check system logs
sudo journalctl -u tomcat --since "1 hour ago"
sudo journalctl -u mariadb --since "1 hour ago"
```

### Emergency Recovery
If the backup system fails completely:

1. **Stop automation**:
```bash
crontab -r
```

2. **Manual backup**:
```bash
./backup-script.sh
```

3. **Check system status**:
```bash
./check-backups.sh
```

---

## Maintenance

### Regular Maintenance Tasks

#### Monthly Tasks
```bash
# 1. Update system packages
sudo yum update -y

# 2. Check backup integrity
./verify-backup.sh

# 3. Review log files
tail -100 /home/ec2-user/backup-logs/backup.log

# 4. Check disk space
df -h
```

#### Quarterly Tasks
```bash
# 1. Test full restore process
./backup-script.sh
BACKUP_NAME=$(ls -t /var/backups/zflow/*_complete.tar.gz | head -1 | sed 's/.*\///' | sed 's/_complete.tar.gz//')
./restore-script.sh $BACKUP_NAME

# 2. Review and update retention policy
# Edit cleanup-backups.sh if needed

# 3. Check system performance
top
free -h
df -h
```

### Backup Rotation
The system automatically keeps backups for 7 days. To change this:

1. Edit `cleanup-backups.sh`
2. Change `RETENTION_DAYS=7` to desired number
3. Re-run setup: `./setup-backup-cron.sh`

---

## Security Considerations

### File Permissions
```bash
# Ensure proper permissions
sudo chown ec2-user:users /var/backups/zflow
chmod 755 /var/backups/zflow
chmod 644 /home/ec2-user/backup-logs/backup.log
```

### Database Security
```bash
# Use strong database passwords
# Change default password after setup
mysql -u root -p
ALTER USER 'zflow'@'localhost' IDENTIFIED BY 'new_strong_password';
FLUSH PRIVILEGES;
```

### Network Security
```bash
# Ensure backups are not accessible via web
# Check firewall rules
sudo firewall-cmd --list-all

# Restrict backup directory access
sudo chmod 750 /var/backups/zflow
```

### Log Security
```bash
# Rotate log files to prevent disk space issues
sudo logrotate /etc/logrotate.conf
```

---

## Emergency Procedures

### Complete System Failure
If the entire system fails:

1. **Stop all services**:
```bash
sudo systemctl stop tomcat
sudo systemctl stop mariadb
```

2. **Restore from latest backup**:
```bash
# Find latest backup
LATEST_BACKUP=$(ls -t /var/backups/zflow/*_complete.tar.gz | head -1)
BACKUP_NAME=$(basename $LATEST_BACKUP _complete.tar.gz)

# Restore
./restore-script.sh $BACKUP_NAME
```

3. **Verify restoration**:
```bash
./verify-backup.sh
curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/
```

### Database Corruption
If database is corrupted:

1. **Stop application**:
```bash
sudo systemctl stop tomcat
```

2. **Restore database only**:
```bash
# Extract database backup
cd /var/backups/zflow
tar -xzf ${BACKUP_NAME}_complete.tar.gz database/${BACKUP_NAME}_db.sql

# Restore database
mysql -u zflow -pzflow123 zflow < database/${BACKUP_NAME}_db.sql
```

3. **Restart application**:
```bash
sudo systemctl start tomcat
```

### Application File Corruption
If application files are corrupted:

1. **Stop application**:
```bash
sudo systemctl stop tomcat
```

2. **Restore application files**:
```bash
# Extract application backup
cd /var/backups/zflow
tar -xzf ${BACKUP_NAME}_complete.tar.gz app/${BACKUP_NAME}_app.tar.gz

# Restore application
sudo tar -xzf app/${BACKUP_NAME}_app.tar.gz -C /usr/share/tomcat/webapps/ROOT/
```

3. **Restart application**:
```bash
sudo systemctl start tomcat
```

---

## Quick Reference Commands

### Daily Operations
```bash
# Check backup status
./check-backups.sh

# Create manual backup
./backup-script.sh

# View recent logs
tail -20 /home/ec2-user/backup-logs/backup.log
```

### Weekly Operations
```bash
# Verify backup integrity
./verify-backup.sh

# Clean old backups
./cleanup-backups.sh

# Check system resources
df -h /var/backups/zflow
```

### Emergency Operations
```bash
# Stop automation
crontab -r

# Manual restore
./restore-script.sh <backup_name>

# Check system status
./check-backups.sh
```

---

## Support and Documentation

### Files Included
- `backup-script.sh` - Main backup script
- `restore-script.sh` - Restore script
- `verify-backup.sh` - Backup verification
- `check-backups.sh` - Status monitoring
- `cleanup-backups.sh` - Cleanup utility
- `setup-backup-cron.sh` - Automation setup
- `deploy-backup-system.sh` - Complete deployment
- `README.md` - Quick overview
- `ZFlow_Backup_Restore_Automation_Guide.md` - Detailed guide
- `Quick_Reference_Card.md` - Quick commands

### Getting Help
1. Check this documentation first
2. Review log files: `/home/ec2-user/backup-logs/backup.log`
3. Run diagnostic commands: `./check-backups.sh`
4. Test individual components manually

### Version Information
- **Version**: 1.0
- **Last Updated**: July 2025
- **Compatibility**: Linux (RHEL/CentOS/Amazon Linux/SUSE)
- **Requirements**: Tomcat 9+, MariaDB 10.5+, Java 17+

---

## Conclusion

This automation system provides comprehensive backup and restore capabilities for ZFlow applications. With proper setup and monitoring, it ensures data protection and system recovery capabilities.

**Remember**: Always test your backup and restore procedures in a safe environment before relying on them in production.

For additional support or questions, refer to the individual script documentation or system logs. 