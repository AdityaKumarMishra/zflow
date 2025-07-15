# ZFlow Backup & Restore - Quick Reference Card

## 🚀 Quick Setup (One-time)
```bash
# Deploy complete system
sudo ./deploy-backup-system.sh

# Manual setup (if needed)
sudo mkdir -p /var/backups/zflow/{app,database,configurations,logs}
chmod +x *.sh
./setup-backup-cron.sh
```

## 📋 Daily Operations

### Check System Status
```bash
# Check backup status
./check-backups.sh

# Check application health
curl -s http://localhost:8080/healthcheck.jsp

# Check services
sudo systemctl status tomcat mysqld
```

### Manual Backup
```bash
# Create backup now
./backup-script.sh

# Verify backup
./verify-backup.sh zflow_backup_YYYYMMDD_HHMMSS
```

### Restore Operations
```bash
# List available backups
./restore-script.sh

# Restore specific backup
./restore-script.sh zflow_backup_YYYYMMDD_HHMMSS

# Emergency restore (latest)
./restore-script.sh $(ls -t /var/backups/zflow/*_complete.tar.gz | head -1 | sed 's/.*zflow_backup_\(.*\)_complete.tar.gz/zflow_backup_\1/')
```

## 🔧 Maintenance

### Weekly Tasks
```bash
# Clean old backups (7-day retention)
./cleanup-backups.sh

# Verify all backups
./verify-backup.sh zflow_backup_YYYYMMDD_HHMMSS

# Check disk space
df -h /var/backups/zflow
```

### Monitoring
```bash
# Watch backup logs
tail -f /var/log/zflow-backup.log

# Watch application logs
sudo tail -f /var/log/tomcat/catalina.out

# Check cron jobs
crontab -l
```

## 🚨 Emergency Procedures

### Application Down
```bash
# Check Tomcat
sudo systemctl status tomcat
sudo systemctl restart tomcat

# Test application
curl -s http://localhost:8080/healthcheck.jsp
```

### Database Issues
```bash
# Check MySQL
sudo systemctl status mysqld
sudo systemctl restart mysqld

# Test connection
mysql -u zflow -pzflow123 -e "SELECT 1;"
```

### Complete System Failure
```bash
# Stop services
sudo systemctl stop tomcat mysqld

# Restore from latest backup
./restore-script.sh $(ls -t /var/backups/zflow/*_complete.tar.gz | head -1 | sed 's/.*zflow_backup_\(.*\)_complete.tar.gz/zflow_backup_\1/')

# Start services
sudo systemctl start mysqld tomcat
```

## 📊 System Information

### Backup Location
- **Directory**: `/var/backups/zflow/`
- **Logs**: `/var/log/zflow-backup.log`
- **Scripts**: `/home/ec2-user/`

### Database Details
- **Database**: `zflow`
- **User**: `zflow`
- **Password**: `zflow123`
- **Host**: `localhost:3306`

### Application Details
- **URL**: `http://localhost:8080/`
- **Health Check**: `http://localhost:8080/healthcheck.jsp`
- **Version**: `http://localhost:8080/version.jsp`

### Automation Schedule
- **Daily Backup**: 2:00 AM
- **Retention**: 7 days
- **Verification**: Automatic after backup

## 🔍 Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Permission denied | `sudo chown -R ec2-user:ec2-user /var/backups/zflow` |
| Database connection failed | `sudo systemctl restart mysqld` |
| Application not accessible | `sudo systemctl restart tomcat` |
| Disk space full | `./cleanup-backups.sh` |
| Backup failed | Check `/var/log/zflow-backup.log` |

### Status Indicators

| Status | Meaning |
|--------|---------|
| ✅ SUCCESS | Operation completed successfully |
| ❌ FAILED | Operation failed - check logs |
| ⚠️ WARNING | Non-critical issue detected |
| ℹ️ INFO | Informational message |

## 📞 Support Commands

### System Health Check
```bash
# Complete health check
echo "=== System Health Check ==="
./check-backups.sh
curl -s http://localhost:8080/healthcheck.jsp
sudo systemctl status tomcat mysqld
df -h /var/backups/zflow
```

### Backup Verification
```bash
# Verify specific backup
./verify-backup.sh zflow_backup_YYYYMMDD_HHMMSS

# List all backups
ls -la /var/backups/zflow/*_complete.tar.gz
```

### Performance Check
```bash
# Check backup size
du -sh /var/backups/zflow

# Check application response time
time curl -s http://localhost:8080/healthcheck.jsp

# Check database performance
mysql -u zflow -pzflow123 -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'zflow';"
```

---

**Last Updated**: July 15, 2025  
**Version**: 1.0  
**For full documentation**: See `ZFlow_Backup_Restore_Automation_Guide.md` 