# ZFlow Backup & Restore Automation Guide

## Table of Contents
1. [Overview](#overview)
2. [System Requirements](#system-requirements)
3. [Installation](#installation)
4. [Backup System](#backup-system)
5. [Restore System](#restore-system)
6. [Automation Setup](#automation-setup)
7. [Monitoring & Maintenance](#monitoring--maintenance)
8. [Troubleshooting](#troubleshooting)
9. [Scripts Reference](#scripts-reference)

## Overview

This guide provides complete documentation for automating ZFlow application backup and restore operations. The system includes:

- **Daily automated backups** with 7-day retention
- **Automated recovery** with comprehensive verification
- **Database and application backup**
- **Configuration backup**
- **Health monitoring and alerts**

## System Requirements

### Prerequisites
- Linux server (tested on Amazon Linux 2, RHEL/CentOS 7+)
- Tomcat 9+ installed and running
- MySQL/MariaDB 5.7+ installed and running
- ZFlow application deployed
- Root/sudo access
- 10GB+ free disk space for backups

### Application Structure
```
/srv/tomcat/webapps/ROOT/          # ZFlow application directory
/var/log/tomcat/                   # Tomcat logs
/var/backups/zflow/                # Backup storage directory
```

### Database Configuration
- Database: `zflow`
- User: `zflow`
- Password: `zflow123`
- Host: `localhost:3306`

## Installation

### Step 1: Create Backup Directory Structure

```bash
# Create backup directory
sudo mkdir -p /var/backups/zflow
sudo chown ec2-user:ec2-user /var/backups/zflow
sudo chmod 755 /var/backups/zflow

# Create subdirectories
mkdir -p /var/backups/zflow/{app,database,configurations,logs}
```

### Step 2: Install Required Tools

```bash
# Update system
sudo yum update -y

# Install required packages
sudo yum install -y mysql mariadb-server curl wget

# Ensure MySQL is running
sudo systemctl start mysqld
sudo systemctl enable mysqld
```

### Step 3: Deploy Scripts

Copy all scripts to `/home/ec2-user/` and make them executable:

```bash
chmod +x backup-script.sh
chmod +x restore-script.sh
chmod +x check-backups.sh
chmod +x cleanup-backups.sh
chmod +x verify-backup.sh
chmod +x setup-backup-cron.sh
```

## Backup System

### Manual Backup

```bash
# Run backup manually
./backup-script.sh

# Check backup status
./check-backups.sh

# Verify backup integrity
./verify-backup.sh
```

### Automated Daily Backup

```bash
# Setup automated daily backups at 2 AM
./setup-backup-cron.sh
```

### Backup Contents

Each backup includes:
- **Application files** (`app/` directory)
- **Database dump** (`database/` directory)
- **Configuration files** (`configurations/` directory)
- **Complete archive** (compressed tar.gz)
- **Manifest file** (backup details)

### Backup Naming Convention

```
zflow_backup_YYYYMMDD_HHMMSS_complete.tar.gz
zflow_backup_YYYYMMDD_HHMMSS_app.tar.gz
zflow_backup_YYYYMMDD_HHMMSS_db.sql
zflow_backup_YYYYMMDD_HHMMSS_config.properties
zflow_backup_YYYYMMDD_HHMMSS_tomcat.conf
zflow_backup_YYYYMMDD_HHMMSS_manifest.txt
```

## Restore System

### Manual Restore

```bash
# List available backups
./restore-script.sh

# Restore specific backup
./restore-script.sh zflow_backup_20250715_100100
```

### Automated Recovery

The restore script includes:
- **Pre-restore backup** of current application
- **Database restoration**
- **Application file restoration**
- **Configuration restoration**
- **Automatic database configuration fixing**
- **Service restart**
- **Verification checks**

### Restore Process

1. **Confirmation prompt** (safety check)
2. **Stop Tomcat service**
3. **Extract backup files**
4. **Restore database** (drop/create/import)
5. **Backup current application** (safety)
6. **Restore application files**
7. **Restore configuration files**
8. **Fix database configuration** (automatic)
9. **Start Tomcat service**
10. **Verify restore** (health check + database)
11. **Cleanup temporary files**

## Automation Setup

### Daily Backup Automation

```bash
# Setup cron job for daily backups at 2 AM
./setup-backup-cron.sh
```

This creates a cron job that:
- Runs daily at 2:00 AM
- Creates complete backup
- Verifies backup integrity
- Cleans up old backups (7-day retention)
- Logs all activities

### Cron Job Details

```bash
# View cron jobs
crontab -l

# Expected output:
# 0 2 * * * /home/ec2-user/backup-script.sh >> /var/log/zflow-backup.log 2>&1
```

### Monitoring Setup

```bash
# Check backup status
./check-backups.sh

# Verify recent backup
./verify-backup.sh

# Clean up old backups
./cleanup-backups.sh
```

## Monitoring & Maintenance

### Daily Monitoring

```bash
# Check backup status
./check-backups.sh

# Expected output:
# === ZFlow Backup Status ===
# Last Backup: zflow_backup_20250715_100100 (2025-07-15 10:01:00)
# Backup Age: 0 days
# Total Backups: 11
# Disk Usage: 568MB
# Status: ✅ All backups are recent and valid
```

### Weekly Maintenance

```bash
# Clean up old backups (keep 7 days)
./cleanup-backups.sh

# Verify all backups
./verify-backup.sh

# Check disk space
df -h /var/backups/zflow
```

### Log Monitoring

```bash
# Check backup logs
tail -f /var/log/zflow-backup.log

# Check application logs
sudo tail -f /var/log/tomcat/catalina.out
```

## Troubleshooting

### Common Issues

#### 1. Backup Fails - Permission Issues
```bash
# Fix permissions
sudo chown -R ec2-user:ec2-user /var/backups/zflow
sudo chmod -R 755 /var/backups/zflow
```

#### 2. Database Connection Fails
```bash
# Check MySQL status
sudo systemctl status mysqld

# Restart MySQL
sudo systemctl restart mysqld

# Test connection
mysql -u zflow -pzflow123 -e "SELECT 1;"
```

#### 3. Restore Fails - Application Not Accessible
```bash
# Check Tomcat status
sudo systemctl status tomcat

# Restart Tomcat
sudo systemctl restart tomcat

# Test application
curl -s http://localhost:8080/healthcheck.jsp
```

#### 4. Disk Space Issues
```bash
# Check disk space
df -h

# Clean up old backups
./cleanup-backups.sh

# Check backup directory size
du -sh /var/backups/zflow
```

### Emergency Recovery

```bash
# Stop all services
sudo systemctl stop tomcat mysqld

# Restore from latest backup
./restore-script.sh $(ls -t /var/backups/zflow/*_complete.tar.gz | head -1 | sed 's/.*zflow_backup_\(.*\)_complete.tar.gz/zflow_backup_\1/')

# Start services
sudo systemctl start mysqld tomcat
```

## Scripts Reference

### backup-script.sh

**Purpose**: Creates complete backup of ZFlow application and database

**Usage**:
```bash
./backup-script.sh
```

**Features**:
- Creates timestamped backup
- Backs up application files
- Exports database
- Backs up configuration files
- Creates compressed archive
- Generates manifest file
- Verifies backup integrity

### restore-script.sh

**Purpose**: Restores ZFlow application and database from backup

**Usage**:
```bash
./restore-script.sh <backup_name>
```

**Features**:
- Lists available backups
- Confirms restore operation
- Creates safety backup
- Restores database and application
- Fixes configuration automatically
- Verifies restore success
- Provides detailed summary

### check-backups.sh

**Purpose**: Monitors backup status and health

**Usage**:
```bash
./check-backups.sh
```

**Features**:
- Shows last backup time
- Lists all available backups
- Reports disk usage
- Validates backup integrity
- Provides status summary

### verify-backup.sh

**Purpose**: Verifies backup file integrity

**Usage**:
```bash
./verify-backup.sh <backup_name>
```

**Features**:
- Validates backup archive
- Checks file structure
- Verifies database dump
- Reports verification status

### cleanup-backups.sh

**Purpose**: Removes old backups (7-day retention)

**Usage**:
```bash
./cleanup-backups.sh
```

**Features**:
- Removes backups older than 7 days
- Reports cleanup actions
- Maintains retention policy

### setup-backup-cron.sh

**Purpose**: Sets up automated daily backups

**Usage**:
```bash
./setup-backup-cron.sh
```

**Features**:
- Creates cron job for daily backups
- Sets up logging
- Configures 2 AM schedule

## Configuration Files

### Database Configuration
File: `/srv/tomcat/webapps/ROOT/WEB-INF/classes/cfg/ZFlowConfig.properties`

```properties
DB_URL=jdbc:mysql://127.0.0.1:3306/zflow
DB_USER=zflow
DB_PASSWD=Encoded:0A267424B320F7B6
```

### Backup Configuration
Directory: `/var/backups/zflow/`

```
/var/backups/zflow/
├── app/                    # Application backups
├── database/              # Database dumps
├── configurations/        # Configuration backups
├── logs/                 # Backup logs
└── *.tar.gz             # Complete archives
```

## Security Considerations

### File Permissions
```bash
# Secure backup directory
sudo chmod 750 /var/backups/zflow
sudo chown root:root /var/backups/zflow
```

### Database Security
```bash
# Use strong passwords
# Limit database user privileges
# Regular security updates
```

### Network Security
```bash
# Firewall configuration
# VPN access for remote management
# Encrypted backups (optional)
```

## Performance Optimization

### Backup Performance
- Use SSD storage for backups
- Compress backups (already implemented)
- Parallel processing for large files
- Incremental backups (future enhancement)

### Restore Performance
- Pre-warm database after restore
- Monitor application startup time
- Optimize database queries
- Use connection pooling

## Disaster Recovery Plan

### Recovery Time Objectives (RTO)
- **Full Restore**: 5-10 minutes
- **Database Only**: 2-3 minutes
- **Application Only**: 1-2 minutes

### Recovery Point Objectives (RPO)
- **Daily Backups**: 24-hour maximum data loss
- **Real-time**: Consider database replication for zero data loss

### Recovery Procedures

#### Complete System Failure
1. Restore from latest backup
2. Verify application functionality
3. Check database connectivity
4. Monitor application logs

#### Database Corruption
1. Stop application
2. Restore database only
3. Restart application
4. Verify data integrity

#### Application Issues
1. Restore application files
2. Restart Tomcat
3. Verify application health
4. Check configuration

## Maintenance Schedule

### Daily
- Monitor backup completion
- Check application health
- Review error logs

### Weekly
- Verify all backups
- Clean up old backups
- Check disk space
- Review performance

### Monthly
- Test restore procedures
- Update documentation
- Review security settings
- Performance optimization

## Support and Contact

### Log Files
- Backup logs: `/var/log/zflow-backup.log`
- Application logs: `/var/log/tomcat/catalina.out`
- System logs: `/var/log/messages`

### Monitoring Commands
```bash
# Check system status
./check-backups.sh
sudo systemctl status tomcat mysqld
df -h /var/backups/zflow

# Test application
curl -s http://localhost:8080/healthcheck.jsp
```

### Emergency Contacts
- System Administrator: [Contact Info]
- Database Administrator: [Contact Info]
- Application Support: [Contact Info]

---

**Version**: 1.0  
**Last Updated**: July 15, 2025  
**Compatibility**: ZFlow 2.5+, Tomcat 9+, MySQL 5.7+ 