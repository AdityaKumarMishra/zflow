# SSL/HTTPS Setup Guide for ZFlow on Windows Server (IIS + Tomcat)

This guide provides step-by-step instructions to configure HTTPS/SSL on a Windows Server using IIS as a reverse proxy with a wildcard certificate, forwarding traffic to Apache Tomcat.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Prerequisites](#2-prerequisites)
3. [Step 1: Install IIS and Required Modules](#step-1-install-iis-and-required-modules)
4. [Step 2: Import the SSL Certificate](#step-2-import-the-ssl-certificate)
5. [Step 3: Configure IIS HTTPS Binding](#step-3-configure-iis-https-binding)
6. [Step 4: Configure IIS Reverse Proxy to Tomcat](#step-4-configure-iis-reverse-proxy-to-tomcat)
7. [Step 5: Configure HTTP to HTTPS Redirect](#step-5-configure-http-to-https-redirect)
8. [Step 6: Start Tomcat Service](#step-6-start-tomcat-service)
9. [Step 7: Verify the Setup](#step-7-verify-the-setup)
10. [Step 8: DNS Configuration](#step-8-dns-configuration)
11. [Step 9: Firewall Configuration](#step-9-firewall-configuration)
12. [Troubleshooting](#troubleshooting)
13. [Certificate Renewal](#certificate-renewal)
14. [Quick Reference Commands](#quick-reference-commands)

---

## 1. Architecture Overview

```
                         Internet
                            |
                    [ DNS: *.zflow.io ]
                            |
                   +--------v--------+
                   |   Windows Server |
                   |                  |
  Port 80 (HTTP)  --> IIS ----+----> Redirect to HTTPS
  Port 443 (HTTPS)--> IIS ----)----> Reverse Proxy ----> Tomcat (Port 8080)
                   |          |                           |
                   |   SSL Termination            ZFlow Application
                   |   (Wildcard Cert)
                   +------------------+
```

**How it works:**
- **IIS** listens on ports 80 (HTTP) and 443 (HTTPS)
- **SSL/TLS termination** happens at IIS using the wildcard certificate
- All **HTTP requests** are redirected to **HTTPS** (301 Permanent Redirect)
- IIS acts as a **reverse proxy**, forwarding HTTPS requests to **Tomcat** on `localhost:8080`
- **Tomcat** runs the ZFlow application and only handles plain HTTP internally

---

## 2. Prerequisites

Before starting, ensure you have:

| Requirement | Details |
|---|---|
| **Windows Server** | Windows Server 2016, 2019, or 2022 |
| **Administrator Access** | You must be logged in as Administrator |
| **SSL Certificate** | A `.pfx` file (e.g., `zflowwildcard.pfx`) with the certificate password |
| **Apache Tomcat** | Installed (e.g., at `C:\ZFlow\tomcat\`) |
| **ZFlow Application** | Deployed in Tomcat's webapps directory |
| **Domain Name** | A domain pointing to your server (e.g., `zflow26onwindows.zflow.io`) |

### About the Certificate File (.pfx)

- A `.pfx` (PKCS#12) file contains both the **SSL certificate** and the **private key**
- Wildcard certificates (e.g., `*.zflow.io`) cover all subdomains of a domain
- Example: `*.zflow.io` covers `zflow26onwindows.zflow.io`, `app.zflow.io`, `test.zflow.io`, etc.
- The `.pfx` file is typically **password-protected** - you will need this password during import

---

## Step 1: Install IIS and Required Modules

### 1.1 Install IIS via PowerShell

Open **PowerShell as Administrator** and run:

```powershell
# Install IIS with management tools
Install-WindowsFeature -Name Web-Server -IncludeManagementTools

# Verify IIS is installed
Get-WindowsFeature -Name Web-Server
```

### 1.2 Install URL Rewrite Module

The URL Rewrite module is required for reverse proxy and HTTP-to-HTTPS redirect rules.

**Download and install:**
1. Download **URL Rewrite Module 2.1** from Microsoft:
   - https://www.iis.net/downloads/microsoft/url-rewrite
2. Run the installer (`.msi` file)
3. Follow the installation wizard

**Or install via command line (if you have WebPI installed):**

```powershell
# Using Web Platform Installer
WebpiCmd.exe /Install /Products:UrlRewrite2
```

### 1.3 Install Application Request Routing (ARR)

ARR is required for the reverse proxy functionality.

**Download and install:**
1. Download **Application Request Routing 3.0** from Microsoft:
   - https://www.iis.net/downloads/microsoft/application-request-routing
2. Run the installer
3. Follow the installation wizard

**Or install via command line:**

```powershell
WebpiCmd.exe /Install /Products:ARRv3_0
```

### 1.4 Enable ARR Proxy

After installing ARR, enable the proxy feature:

```powershell
# Enable proxy in ARR
Set-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' `
    -Filter 'system.webServer/proxy' `
    -Name 'enabled' -Value 'True'
```

**Or via IIS Manager (GUI):**
1. Open **IIS Manager** (`inetmgr`)
2. Click on the **server name** (top level, not a site)
3. Double-click **Application Request Routing Cache**
4. Click **Server Proxy Settings** in the right panel
5. Check **Enable proxy**
6. Click **Apply**

---

## Step 2: Import the SSL Certificate

### 2.1 Import via PowerShell (Recommended)

```powershell
# Replace with your actual certificate path and password
$certPath = "C:\Users\Administrator\Desktop\zflowwildcard.pfx"
$certPassword = ConvertTo-SecureString -String "YOUR_PASSWORD_HERE" -AsPlainText -Force

# Import the certificate into the Local Machine certificate store
$cert = Import-PfxCertificate `
    -FilePath $certPath `
    -CertStoreLocation Cert:\LocalMachine\My `
    -Password $certPassword

# Display the imported certificate details
$cert | Format-Table Thumbprint, Subject, NotAfter -AutoSize

# IMPORTANT: Note down the Thumbprint - you will need it in the next step
Write-Host "Certificate Thumbprint: $($cert.Thumbprint)" -ForegroundColor Green
```

**Example Output:**
```
Thumbprint                               Subject       NotAfter
----------                               -------       --------
F4BD93B3623A7B0DE28B9B466F22306FE2065D08 CN=*.zflow.io 6/6/2026 4:46:03 AM

Certificate Thumbprint: F4BD93B3623A7B0DE28B9B466F22306FE2065D08
```

### 2.2 Import via IIS Manager (GUI Alternative)

1. Open **IIS Manager** (`inetmgr`)
2. Click on the **server name** in the left panel
3. Double-click **Server Certificates** in the center panel
4. Click **Import...** in the right Actions panel
5. Browse to your `.pfx` file
6. Enter the certificate password
7. Select certificate store: **Personal**
8. Click **OK**

### 2.3 Verify the Certificate is Imported

```powershell
# List all certificates in the Local Machine store
Get-ChildItem Cert:\LocalMachine\My | Format-Table Thumbprint, Subject, NotAfter -AutoSize
```

You should see your wildcard certificate (e.g., `CN=*.zflow.io`) in the list.

---

## Step 3: Configure IIS HTTPS Binding

### 3.1 Configure via PowerShell (Recommended)

```powershell
Import-Module WebAdministration

# --- Variables (CHANGE THESE) ---
$siteName      = "Default Web Site"
$hostName      = "zflow26onwindows.zflow.io"    # Your specific subdomain
$thumbprint    = "F4BD93B3623A7B0DE28B9B466F22306FE2065D08"  # From Step 2

# --- Remove existing HTTPS binding (if any) ---
Remove-WebBinding -Name $siteName -Protocol https -Port 443 -ErrorAction SilentlyContinue

# --- Create new HTTPS binding with SNI ---
# SslFlags=1 enables Server Name Indication (SNI)
# SNI allows multiple HTTPS sites on the same IP address
New-WebBinding -Name $siteName `
    -Protocol https `
    -Port 443 `
    -HostHeader $hostName `
    -SslFlags 1

# --- Bind the SSL certificate to the site ---
# Remove any old SSL bindings first
Get-ChildItem -Path 'IIS:\SslBindings\*' -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue

# Create the new SSL binding
New-Item -Path "IIS:\SslBindings\!443!$hostName" `
    -Thumbprint $thumbprint `
    -SSLFlags 1

# --- Verify the binding ---
Get-WebBinding -Name $siteName | Format-Table protocol, bindingInformation -AutoSize
```

**Expected Output:**
```
protocol bindingInformation
-------- ------------------
http     *:80:
https    *:443:zflow26onwindows.zflow.io
```

> **Note:** You may see a warning: *"Binding host name 'zflow26onwindows.zflow.io' is not equals to certificate subject name '*.zflow.io'"*. This is safe to ignore - the wildcard certificate `*.zflow.io` is valid for all subdomains including `zflow26onwindows.zflow.io`. Browsers will accept it without any issues.

### 3.2 Configure via IIS Manager (GUI Alternative)

1. Open **IIS Manager** (`inetmgr`)
2. Expand the server name > **Sites** > **Default Web Site**
3. Click **Bindings...** in the right Actions panel
4. Click **Add...**
5. Fill in:
   - **Type:** https
   - **IP Address:** All Unassigned
   - **Port:** 443
   - **Host name:** `zflow26onwindows.zflow.io`
   - **Require Server Name Indication:** Checked
   - **SSL certificate:** Select your wildcard certificate from the dropdown
6. Click **OK**
7. Click **Close**

---

## Step 4: Configure IIS Reverse Proxy to Tomcat

Create a `web.config` file in the IIS site root directory to set up the reverse proxy rules.

### 4.1 Create/Edit web.config

The file should be located at: `C:\inetpub\wwwroot\web.config`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <system.webServer>
        <rewrite>
            <rules>
                <!-- Rule 1: Redirect HTTP to HTTPS -->
                <rule name="HTTP to HTTPS" stopProcessing="true">
                    <match url="(.*)" />
                    <conditions>
                        <add input="{HTTPS}" pattern="^OFF$" />
                    </conditions>
                    <action type="Redirect" url="https://{HTTP_HOST}/{R:1}" redirectType="Permanent" />
                </rule>

                <!-- Rule 2: Reverse Proxy to Tomcat -->
                <rule name="ReverseProxyToTomcat" stopProcessing="true">
                    <match url="(.*)" />
                    <action type="Rewrite" url="http://localhost:8080/{R:1}" />
                </rule>
            </rules>
        </rewrite>
    </system.webServer>
</configuration>
```

**How the rules work:**
1. **HTTP to HTTPS rule** - If the request comes in on HTTP (port 80), redirect it to HTTPS with a 301 permanent redirect
2. **Reverse Proxy rule** - Forward all HTTPS requests to Tomcat running on `localhost:8080`

> **Important:** The `stopProcessing="true"` attribute ensures that once a rule matches, no further rules are processed. The HTTP-to-HTTPS rule must come BEFORE the reverse proxy rule.

---

## Step 5: Configure HTTP to HTTPS Redirect

This is already handled in the `web.config` file from Step 4 (Rule 1: "HTTP to HTTPS"). 

Make sure the HTTP binding exists on port 80:

```powershell
# Verify HTTP binding exists
Get-WebBinding -Name "Default Web Site" -Protocol http

# If missing, add it:
New-WebBinding -Name "Default Web Site" -Protocol http -Port 80
```

---

## Step 6: Start Tomcat Service

### 6.1 Start Tomcat

```powershell
# Start the Tomcat service
Start-Service Tomcat9

# Verify it is running
Get-Service Tomcat9 | Format-Table Name, DisplayName, Status
```

**Expected Output:**
```
Name     DisplayName                Status
----     -----------                ------
Tomcat9  Apache Tomcat 9.0 Tomcat9  Running
```

### 6.2 Set Tomcat to Start Automatically

Ensure Tomcat starts automatically when the server boots:

```powershell
Set-Service -Name Tomcat9 -StartupType Automatic
```

### 6.3 Verify Tomcat is Listening

```powershell
netstat -ano | findstr ":8080"
```

You should see Tomcat listening on port 8080:
```
TCP    0.0.0.0:8080    0.0.0.0:0    LISTENING    4656
```

---

## Step 7: Verify the Setup

### 7.1 Test Tomcat Directly (HTTP on port 8080)

```powershell
# Test Tomcat is responding
Invoke-WebRequest -Uri "http://localhost:8080/" -UseBasicParsing -TimeoutSec 10 | Select-Object StatusCode
```

Expected: `StatusCode: 200`

### 7.2 Test HTTPS Locally

```bash
# Using curl with hostname resolution override
curl -k --resolve "zflow26onwindows.zflow.io:443:127.0.0.1" https://zflow26onwindows.zflow.io/
```

Expected: HTTP 200 with ZFlow page content.

### 7.3 Test HTTP to HTTPS Redirect

```bash
# This should return a 301 redirect to HTTPS
curl -s -o /dev/null -w "%{http_code}" http://localhost/
```

Expected: `301`

### 7.4 Test from External Browser

1. Open a web browser on another machine
2. Navigate to `https://zflow26onwindows.zflow.io`
3. Verify:
   - The page loads without SSL warnings
   - The browser shows a padlock icon
   - Clicking the padlock shows the wildcard certificate `*.zflow.io`

---

## Step 8: DNS Configuration

For external users to access the site, DNS must point your domain to the server's public IP.

### 8.1 Find Your Server's Public IP

```powershell
# If on AWS EC2
Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/public-ipv4"

# Or use a public service
Invoke-RestMethod -Uri "https://api.ipify.org"
```

### 8.2 Configure DNS Records

In your DNS provider (e.g., Cloudflare, Route 53, GoDaddy), create:

| Type | Name | Value | TTL |
|---|---|---|---|
| A | `zflow26onwindows.zflow.io` | `YOUR_SERVER_PUBLIC_IP` | 300 |

Or if using a wildcard DNS record:

| Type | Name | Value | TTL |
|---|---|---|---|
| A | `*.zflow.io` | `YOUR_SERVER_PUBLIC_IP` | 300 |

### 8.3 Verify DNS Resolution

```bash
nslookup zflow26onwindows.zflow.io
```

---

## Step 9: Firewall Configuration

### 9.1 Windows Firewall

Ensure ports 80 and 443 are open in Windows Firewall:

```powershell
# Allow HTTPS (port 443) inbound
New-NetFirewallRule -DisplayName "HTTPS Inbound" `
    -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow

# Allow HTTP (port 80) inbound (for redirect)
New-NetFirewallRule -DisplayName "HTTP Inbound" `
    -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow
```

### 9.2 AWS Security Group (if on AWS)

If running on AWS EC2, ensure the Security Group allows:

| Type | Protocol | Port Range | Source |
|---|---|---|---|
| HTTPS | TCP | 443 | 0.0.0.0/0 |
| HTTP | TCP | 80 | 0.0.0.0/0 |

> **Note:** Do NOT open port 8080 externally. Tomcat should only be accessible internally via IIS reverse proxy.

---

## Troubleshooting

### Issue: Browser shows "Connection not secure" or SSL warning

**Possible causes:**
- Certificate not imported correctly
- Wrong certificate bound to the site
- Certificate expired

**Fix:**
```powershell
# Check certificate details and expiry
Get-ChildItem Cert:\LocalMachine\My | Format-Table Thumbprint, Subject, NotAfter -AutoSize

# Verify the binding
Get-WebBinding -Name "Default Web Site" | Format-Table protocol, bindingInformation -AutoSize
```

### Issue: ERR_CONNECTION_REFUSED on HTTPS

**Possible causes:**
- IIS not running
- HTTPS binding missing
- Port 443 blocked by firewall

**Fix:**
```powershell
# Check if IIS is running
Get-Service W3SVC | Format-Table Name, Status

# Start IIS if stopped
Start-Service W3SVC

# Verify port 443 is listening
netstat -ano | findstr ":443"
```

### Issue: 502 Bad Gateway or 503 Service Unavailable

**Possible causes:**
- Tomcat is not running
- Tomcat not listening on port 8080
- ARR proxy not enabled

**Fix:**
```powershell
# Check Tomcat status
Get-Service Tomcat9 | Format-Table Name, Status

# Start Tomcat if stopped
Start-Service Tomcat9

# Verify Tomcat is listening on 8080
netstat -ano | findstr ":8080"

# Verify ARR proxy is enabled
Get-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' `
    -Filter 'system.webServer/proxy' -Name 'enabled'
```

### Issue: HTTP to HTTPS redirect not working

**Possible causes:**
- URL Rewrite module not installed
- web.config rules missing or incorrect

**Fix:**
```powershell
# Check if URL Rewrite module is installed
Get-WebGlobalModule | Where-Object { $_.Name -like "*Rewrite*" }

# Verify web.config exists and has correct rules
Get-Content C:\inetpub\wwwroot\web.config
```

### Issue: Page loads but shows IIS default page instead of ZFlow

**Possible causes:**
- Reverse proxy rule not working
- ZFlow not deployed in Tomcat

**Fix:**
```powershell
# Test Tomcat directly
Invoke-WebRequest -Uri "http://localhost:8080/" -UseBasicParsing | Select-Object StatusCode

# Check if ZFlow is deployed
ls C:\ZFlow\tomcat\webapps\
```

### Useful Log Locations

| Log | Location |
|---|---|
| IIS Logs | `C:\inetpub\logs\LogFiles\` |
| Tomcat Logs | `C:\ZFlow\tomcat\logs\` |
| Windows Event Log | Event Viewer > Windows Logs > System |
| Failed Request Tracing | Enable in IIS Manager for detailed error info |

---

## Certificate Renewal

Wildcard certificates typically expire after 1-2 years. Follow these steps to renew:

### 1. Obtain the new `.pfx` certificate file

### 2. Import the new certificate

```powershell
$newCertPath = "C:\path\to\new\certificate.pfx"
$newCertPassword = ConvertTo-SecureString -String "NEW_PASSWORD" -AsPlainText -Force

$newCert = Import-PfxCertificate `
    -FilePath $newCertPath `
    -CertStoreLocation Cert:\LocalMachine\My `
    -Password $newCertPassword

Write-Host "New Thumbprint: $($newCert.Thumbprint)"
```

### 3. Update the IIS binding with the new certificate

```powershell
$siteName   = "Default Web Site"
$hostName   = "zflow26onwindows.zflow.io"
$newThumb   = "NEW_CERTIFICATE_THUMBPRINT_HERE"

# Remove old SSL binding
Get-ChildItem -Path 'IIS:\SslBindings\*' | Remove-Item

# Create new SSL binding with updated certificate
New-Item -Path "IIS:\SslBindings\!443!$hostName" `
    -Thumbprint $newThumb `
    -SSLFlags 1
```

### 4. Remove the old (expired) certificate

```powershell
$oldThumb = "OLD_CERTIFICATE_THUMBPRINT_HERE"
Remove-Item -Path "Cert:\LocalMachine\My\$oldThumb"
```

### 5. Verify

```powershell
# Check the new certificate is bound
Get-ChildItem 'IIS:\SslBindings' | Format-Table Host, Port, Store -AutoSize
```

---

## Quick Reference Commands

```powershell
# ========== STATUS CHECKS ==========

# Check IIS status
Get-Service W3SVC | Format-Table Name, Status

# Check Tomcat status
Get-Service Tomcat9 | Format-Table Name, Status

# View all IIS site bindings
Import-Module WebAdministration
Get-WebBinding | Format-Table siteName, protocol, bindingInformation -AutoSize

# List installed certificates
Get-ChildItem Cert:\LocalMachine\My | Format-Table Thumbprint, Subject, NotAfter -AutoSize

# Check what's listening on which ports
netstat -ano | findstr ":80 :443 :8080"

# ========== START / STOP SERVICES ==========

# Start/Stop IIS
Start-Service W3SVC
Stop-Service W3SVC

# Start/Stop Tomcat
Start-Service Tomcat9
Stop-Service Tomcat9

# Restart IIS (full reset)
iisreset

# ========== TESTING ==========

# Test Tomcat directly
curl http://localhost:8080/

# Test HTTPS with hostname
curl -k --resolve "zflow26onwindows.zflow.io:443:127.0.0.1" https://zflow26onwindows.zflow.io/

# Check SSL certificate from command line
openssl s_client -connect zflow26onwindows.zflow.io:443 -servername zflow26onwindows.zflow.io
```

---

## Summary of What Was Configured

| Component | Configuration |
|---|---|
| **IIS - HTTP Binding** | `*:80:` (all hostnames, port 80) |
| **IIS - HTTPS Binding** | `*:443:zflow26onwindows.zflow.io` (SNI enabled) |
| **SSL Certificate** | `*.zflow.io` wildcard (Thumbprint: `F4BD93B3...`) |
| **Certificate Expiry** | June 6, 2026 |
| **Reverse Proxy** | IIS forwards to `http://localhost:8080/` |
| **HTTP Redirect** | All HTTP requests redirect to HTTPS (301) |
| **Tomcat** | Listening on `localhost:8080`, startup type: Automatic |
| **web.config Location** | `C:\inetpub\wwwroot\web.config` |

---

*Document created: April 3, 2026*
*Server: zflow26onwindows.zflow.io*
