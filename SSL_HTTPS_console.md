# SSL/HTTPS Setup Guide - Windows Console (GUI) Steps

Complete step-by-step guide to configure HTTPS/SSL on Windows Server using IIS Manager and Windows Console tools. No PowerShell required - everything done via GUI.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Step 1: Install IIS Web Server Role](#step-1-install-iis-web-server-role)
3. [Step 2: Install URL Rewrite Module](#step-2-install-url-rewrite-module)
4. [Step 3: Install Application Request Routing (ARR)](#step-3-install-application-request-routing-arr)
5. [Step 4: Enable ARR Proxy in IIS](#step-4-enable-arr-proxy-in-iis)
6. [Step 5: Import SSL Certificate (.pfx)](#step-5-import-ssl-certificate-pfx)
7. [Step 6: Bind HTTPS to IIS Site](#step-6-bind-https-to-iis-site)
8. [Step 7: Configure Reverse Proxy and HTTPS Redirect](#step-7-configure-reverse-proxy-and-https-redirect)
9. [Step 8: Start Tomcat Service](#step-8-start-tomcat-service)
10. [Step 9: Configure Firewall](#step-9-configure-firewall)
11. [Step 10: Verify Everything](#step-10-verify-everything)
12. [Troubleshooting via Console](#troubleshooting-via-console)
13. [Certificate Renewal via Console](#certificate-renewal-via-console)

---

## 1. Prerequisites

Before you start, make sure you have:

- Windows Server 2016 / 2019 / 2022
- Administrator login access
- SSL Certificate file (`.pfx` format) copied to the Desktop (e.g., `zflowwildcard.pfx`)
- Certificate password
- Apache Tomcat installed (e.g., at `C:\ZFlow\tomcat\`)
- ZFlow application deployed in Tomcat

---

## Step 1: Install IIS Web Server Role

### 1.1 Open Server Manager

```
Start Menu > Server Manager
```

Or press `Win + R`, type `servermanager`, press Enter.

### 1.2 Add Roles and Features

1. In Server Manager, click **Manage** (top-right menu bar)
2. Click **Add Roles and Features**
3. Click **Next** on the "Before you begin" page

### 1.3 Select Installation Type

1. Select **Role-based or feature-based installation**
2. Click **Next**

### 1.4 Select Server

1. Select your local server from the list
2. Click **Next**

### 1.5 Select Server Roles

1. Scroll down and check **Web Server (IIS)**
2. A popup appears: "Add features that are required for Web Server (IIS)?"
3. Click **Add Features**
4. Click **Next**

### 1.6 Select Features

1. No additional features needed - click **Next**

### 1.7 Web Server Role (IIS) - Role Services

Make sure these are checked:

```
[x] Web Server
    [x] Common HTTP Features
        [x] Default Document
        [x] Directory Browsing
        [x] HTTP Errors
        [x] Static Content
    [x] Health and Diagnostics
        [x] HTTP Logging
    [x] Performance
        [x] Static Content Compression
    [x] Security
        [x] Request Filtering
[x] Management Tools
    [x] IIS Management Console
```

Click **Next**.

### 1.8 Confirm and Install

1. Click **Install**
2. Wait for installation to complete (2-5 minutes)
3. Click **Close**

### 1.9 Verify IIS is Running

1. Open a browser on the server
2. Go to `http://localhost`
3. You should see the **IIS Welcome Page**

---

## Step 2: Install URL Rewrite Module

This module is required for HTTP-to-HTTPS redirect and reverse proxy rules.

### 2.1 Download

1. Open a browser on the server
2. Go to: **https://www.iis.net/downloads/microsoft/url-rewrite**
3. Click **Install this extension** or download the `.msi` installer
4. Choose the correct version:
   - **x64** for 64-bit Windows (most common)
   - **x86** for 32-bit Windows

### 2.2 Install

1. Double-click the downloaded `.msi` file
2. Accept the license agreement
3. Click **Install**
4. Click **Finish**

> **Note:** If IIS Manager is open, close and reopen it after installing this module.

---

## Step 3: Install Application Request Routing (ARR)

ARR enables IIS to act as a reverse proxy to forward requests to Tomcat.

### 3.1 Download

1. Open a browser on the server
2. Go to: **https://www.iis.net/downloads/microsoft/application-request-routing**
3. Download the **ARR 3.0** installer (`.msi`)

### 3.2 Install

1. Double-click the downloaded `.msi` file
2. Accept the license agreement
3. Click **Install**
4. Click **Finish**

> **Note:** Close and reopen IIS Manager after installing.

---

## Step 4: Enable ARR Proxy in IIS

### 4.1 Open IIS Manager

```
Start Menu > type "IIS" > click "Internet Information Services (IIS) Manager"
```

Or press `Win + R`, type `inetmgr`, press Enter.

### 4.2 Enable Proxy

1. In the left panel (Connections), click the **server name** (top-level node, e.g., `EC2AMAZ-7EDM7F1`)
   - **IMPORTANT:** Click the SERVER name, NOT "Sites" or "Default Web Site"
2. In the center panel, scroll down to the **IIS** section
3. Double-click **Application Request Routing Cache**

   ```
   +------------------------------------------+
   |  Application Request Routing Cache        |
   |  [icon]                                   |
   +------------------------------------------+
   ```

4. In the right panel (Actions), click **Server Proxy Settings...**
5. Check the box: **Enable proxy**

   ```
   [x] Enable proxy
   ```

6. Click **Apply** in the right panel

---

## Step 5: Import SSL Certificate (.pfx)

You have two methods. Use whichever is more convenient.

### Method A: Import via IIS Manager (Recommended)

#### 5A.1 Open IIS Manager

```
Win + R > inetmgr > Enter
```

#### 5A.2 Open Server Certificates

1. In the left panel, click the **server name** (top-level node)
2. In the center panel, double-click **Server Certificates**

   ```
   +------------------------------------------+
   |  Server Certificates                      |
   |  [icon]                                   |
   +------------------------------------------+
   ```

#### 5A.3 Import the Certificate

1. In the right panel (Actions), click **Import...**
2. In the Import Certificate dialog:

   ```
   +-----------------------------------------------+
   |  Import Certificate                            |
   |                                                |
   |  Certificate file (.pfx):                      |
   |  [ C:\Users\Administrator\Desktop\             |
   |    zflowwildcard.pfx                ] [...]    |
   |                                                |
   |  Password:                                     |
   |  [ ******** ]                                  |
   |                                                |
   |  [x] Allow this certificate to be exported     |
   |                                                |
   |  Certificate store:                            |
   |  [ Personal          v ]                       |
   |                                                |
   |         [ OK ]     [ Cancel ]                  |
   +-----------------------------------------------+
   ```

   - **Certificate file:** Click `...` (Browse) > Navigate to Desktop > Select `zflowwildcard.pfx`
   - **Password:** Enter the certificate password (e.g., `zesati`)
   - **Allow this certificate to be exported:** Check this box
   - **Certificate store:** Select `Personal`

3. Click **OK**

#### 5A.4 Verify Import

You should now see the certificate listed in Server Certificates:

```
+--------------------------------------------------------------------+
| Name              | Issued To   | Issued By   | Expiration Date    |
|--------------------------------------------------------------------|
| *.zflow.io        | *.zflow.io  | CA Name     | 6/6/2026           |
+--------------------------------------------------------------------+
```

---

### Method B: Import via MMC (Microsoft Management Console)

Use this method if IIS Manager import doesn't work.

#### 5B.1 Open MMC

```
Win + R > mmc > Enter
```

#### 5B.2 Add Certificate Snap-in

1. Click **File** > **Add/Remove Snap-in...** (or press `Ctrl + M`)
2. In the left panel, select **Certificates**
3. Click **Add >**
4. Select **Computer account**
5. Click **Next**
6. Select **Local computer**
7. Click **Finish**
8. Click **OK**

#### 5B.3 Import Certificate

1. In the left panel, expand: **Certificates (Local Computer)** > **Personal**
2. Right-click **Certificates** (under Personal)
3. Click **All Tasks** > **Import...**

   ```
   Certificates (Local Computer)
   └── Personal
       └── Certificates  <-- Right-click here
           └── All Tasks > Import...
   ```

4. The Certificate Import Wizard opens:
   - Click **Next**
   - **File name:** Click **Browse** > Change file type filter to `Personal Information Exchange (*.pfx;*.p12)` > Navigate to Desktop > Select `zflowwildcard.pfx`
   - Click **Next**
   - **Password:** Enter the certificate password
   - Check **Mark this key as exportable**
   - Click **Next**
   - **Certificate Store:** Select `Place all certificates in the following store` > **Personal**
   - Click **Next**
   - Click **Finish**
5. You should see: **"The import was successful."**

#### 5B.4 Verify in MMC

Expand **Personal** > **Certificates**. You should see:

```
Issued To: *.zflow.io
Issued By: (your CA)
Expiration Date: 6/6/2026
```

---

## Step 6: Bind HTTPS to IIS Site

### 6.1 Open IIS Manager

```
Win + R > inetmgr > Enter
```

### 6.2 Open Site Bindings

1. In the left panel, expand: **Server Name** > **Sites**
2. Click **Default Web Site**
3. In the right panel (Actions), click **Bindings...**

   ```
   Actions
   --------
   Edit Site
     Bindings...     <-- Click this
     Basic Settings...
     Limits...
   ```

### 6.3 View Current Bindings

You will see the Site Bindings dialog:

```
+----------------------------------------------------------+
|  Site Bindings                                           |
|                                                          |
|  Type    | Host Name | Port | IP Address | Binding Info  |
|  --------|-----------|------|------------|---------------|
|  http    |           | 80   | *          |               |
|                                                          |
|  [ Add... ]  [ Edit... ]  [ Remove ]  [ Close ]         |
+----------------------------------------------------------+
```

### 6.4 Add HTTPS Binding

1. Click **Add...**
2. Fill in the Add Site Binding dialog:

   ```
   +-------------------------------------------------------+
   |  Add Site Binding                                      |
   |                                                        |
   |  Type:         [ https          v ]                    |
   |  IP address:   [ All Unassigned v ]                    |
   |  Port:         [ 443 ]                                 |
   |  Host name:    [ zflow26onwindows.zflow.io ]           |
   |                                                        |
   |  [x] Require Server Name Indication                    |
   |                                                        |
   |  SSL certificate: [ *.zflow.io           v ] [ View ]  |
   |                                                        |
   |           [ OK ]       [ Cancel ]                      |
   +-------------------------------------------------------+
   ```

   - **Type:** Select `https`
   - **IP address:** Leave as `All Unassigned`
   - **Port:** `443`
   - **Host name:** Type your full domain: `zflow26onwindows.zflow.io`
   - **Require Server Name Indication:** CHECK this box
     - Once checked, the SSL certificate dropdown becomes available
   - **SSL certificate:** Select `*.zflow.io` from the dropdown
     - Click **View** to verify it shows the correct wildcard certificate details

3. Click **OK**

### 6.5 Verify Bindings

Your Site Bindings should now show:

```
+----------------------------------------------------------+
|  Type    | Host Name                     | Port | IP     |
|  --------|-------------------------------|------|--------|
|  http    |                               | 80   | *      |
|  https   | zflow26onwindows.zflow.io     | 443  | *      |
+----------------------------------------------------------+
```

4. Click **Close**

> **Note:** Keep the HTTP binding on port 80 - it is needed for the HTTP-to-HTTPS redirect to work.

---

## Step 7: Configure Reverse Proxy and HTTPS Redirect

### 7.1 Open Notepad as Administrator

```
Start Menu > type "Notepad" > Right-click Notepad > Run as administrator
```

### 7.2 Create / Edit web.config

1. In Notepad, click **File** > **Open**
2. Navigate to: `C:\inetpub\wwwroot\`
3. Change the file type filter (bottom-right) from `Text Documents (*.txt)` to `All Files (*.*)`
4. If `web.config` exists, open it. If not, we will create a new one.

### 7.3 Paste the Following Content

Delete any existing content and paste this:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <system.webServer>
        <rewrite>
            <rules>
                <rule name="HTTP to HTTPS" stopProcessing="true">
                    <match url="(.*)" />
                    <conditions>
                        <add input="{HTTPS}" pattern="^OFF$" />
                    </conditions>
                    <action type="Redirect" url="https://{HTTP_HOST}/{R:1}" redirectType="Permanent" />
                </rule>
                <rule name="ReverseProxyToTomcat" stopProcessing="true">
                    <match url="(.*)" />
                    <action type="Rewrite" url="http://localhost:8080/{R:1}" />
                </rule>
            </rules>
        </rewrite>
    </system.webServer>
</configuration>
```

### 7.4 Save the File

1. Click **File** > **Save As**
2. Navigate to: `C:\inetpub\wwwroot\`
3. **File name:** `web.config`
   - **IMPORTANT:** Make sure the file name is exactly `web.config` (not `web.config.txt`)
   - If the "Save as type" dropdown says "Text Documents (*.txt)", change it to **All Files (*.*)**
4. **Encoding:** Select `UTF-8`
5. Click **Save**

### 7.5 What These Rules Do

```
User types: http://zflow26onwindows.zflow.io
    |
    v
Rule 1: "HTTP to HTTPS"
    - Detects HTTP (not HTTPS)
    - Redirects browser to: https://zflow26onwindows.zflow.io
    - Browser follows redirect automatically
    |
    v
Rule 2: "ReverseProxyToTomcat"
    - Takes the HTTPS request
    - Forwards it internally to: http://localhost:8080/
    - Tomcat processes the request
    - Response flows back through IIS to the user
```

---

## Step 8: Start Tomcat Service

### 8.1 Open Services Console

```
Win + R > services.msc > Enter
```

### 8.2 Find Tomcat Service

1. Scroll down the list to find **Apache Tomcat 9.0 Tomcat9**
   - Or press `A` key repeatedly to jump to services starting with "A"

   ```
   +----------------------------------------------------------------+
   | Name                              | Status  | Startup Type     |
   |----------------------------------------------------------------|
   | ...                               |         |                  |
   | Apache Tomcat 9.0 Tomcat9         | Stopped | Manual           |
   | ...                               |         |                  |
   +----------------------------------------------------------------+
   ```

### 8.3 Start the Service

1. Right-click **Apache Tomcat 9.0 Tomcat9**
2. Click **Start**
3. Wait for the status to change to **Running**

### 8.4 Set Automatic Startup

So Tomcat starts automatically when the server reboots:

1. Right-click **Apache Tomcat 9.0 Tomcat9**
2. Click **Properties**
3. Change **Startup type** to **Automatic**

   ```
   +--------------------------------------------+
   |  Apache Tomcat 9.0 Tomcat9 Properties       |
   |                                             |
   |  Service name:  Tomcat9                     |
   |  Startup type:  [ Automatic       v ]       |
   |  Service status: Running                    |
   |                                             |
   |  [ Start ] [ Stop ] [ Pause ] [ Resume ]   |
   |                                             |
   |       [ OK ]  [ Cancel ]  [ Apply ]         |
   +--------------------------------------------+
   ```

4. Click **Apply** > **OK**

### 8.5 Verify Tomcat is Running

1. Open a browser on the server
2. Go to: `http://localhost:8080`
3. You should see the ZFlow application (or Tomcat default page)

---

## Step 9: Configure Firewall

### 9.1 Open Windows Firewall

```
Win + R > wf.msc > Enter
```

This opens **Windows Defender Firewall with Advanced Security**.

### 9.2 Create Rule for HTTPS (Port 443)

1. In the left panel, click **Inbound Rules**
2. In the right panel, click **New Rule...**
3. **Rule Type:** Select **Port** > Click **Next**
4. **Protocol and Ports:**
   - Select **TCP**
   - Select **Specific local ports:** Type `443`
   - Click **Next**

   ```
   ( ) All local ports
   (x) Specific local ports: [ 443 ]
   ```

5. **Action:** Select **Allow the connection** > Click **Next**
6. **Profile:** Check all three:

   ```
   [x] Domain
   [x] Private
   [x] Public
   ```

   Click **Next**

7. **Name:** Type `HTTPS Inbound (Port 443)`
8. Click **Finish**

### 9.3 Create Rule for HTTP (Port 80)

Repeat the same steps above but with:
- **Port:** `80`
- **Name:** `HTTP Inbound (Port 80)`

### 9.4 Verify Rules

In Inbound Rules, you should now see:

```
+----------------------------------------------------------+
| Name                        | Enabled | Action | Port    |
|----------------------------------------------------------+
| HTTPS Inbound (Port 443)   | Yes     | Allow  | 443     |
| HTTP Inbound (Port 80)     | Yes     | Allow  | 80      |
+----------------------------------------------------------+
```

### 9.5 AWS / Azure / Cloud Firewall (If Applicable)

If your server is on a cloud provider, you also need to open ports in the cloud firewall:

**AWS (Security Groups):**
1. Go to AWS Console > EC2 > Security Groups
2. Select the security group attached to your instance
3. Click **Edit inbound rules**
4. Add rules:

   ```
   Type     | Protocol | Port | Source
   ---------|----------|------|----------
   HTTPS    | TCP      | 443  | 0.0.0.0/0
   HTTP     | TCP      | 80   | 0.0.0.0/0
   ```

5. Click **Save rules**

**Azure (NSG):**
1. Go to Azure Portal > Network Security Groups
2. Add inbound rules for ports 80 and 443

> **IMPORTANT:** Do NOT open port 8080 in any firewall. Tomcat should only be accessed internally by IIS.

---

## Step 10: Verify Everything

### 10.1 Check IIS is Running

1. Open **IIS Manager** (`Win + R > inetmgr`)
2. Click **Default Web Site** in the left panel
3. Check the right panel - it should show:

   ```
   Manage Website
     Start    (greyed out if already running)
     Stop
     Restart
   
   Browse Website
     Browse *:80 (http)
     Browse *:443 (https)
   ```

### 10.2 Test from Server Browser

1. Open a browser on the server
2. Test these URLs in order:

**Test 1 - Tomcat Direct:**
```
URL:      http://localhost:8080
Expected: ZFlow application loads
```

**Test 2 - HTTPS via IIS:**
```
URL:      https://zflow26onwindows.zflow.io
Expected: ZFlow application loads with padlock icon
```

**Test 3 - HTTP Redirect:**
```
URL:      http://zflow26onwindows.zflow.io
Expected: Automatically redirects to https://zflow26onwindows.zflow.io
```

### 10.3 Check Certificate in Browser

1. Go to `https://zflow26onwindows.zflow.io`
2. Click the **padlock icon** in the address bar
3. Click **Certificate** or **Connection is secure**
4. Verify:

   ```
   Issued to:    *.zflow.io
   Issued by:    (your Certificate Authority)
   Valid from:   (start date)
   Valid to:     6/6/2026
   ```

### 10.4 Test from External Machine

1. On another computer or phone, open a browser
2. Go to `https://zflow26onwindows.zflow.io`
3. The page should load without any SSL warnings
4. The padlock icon should be visible

---

## Troubleshooting via Console

### Problem: "This site can't be reached" / Connection refused

**Check 1: Is IIS running?**
1. Open Services (`Win + R > services.msc`)
2. Find **World Wide Web Publishing Service** (W3SVC)
3. Status should be **Running**
4. If stopped, right-click > **Start**

**Check 2: Is the binding correct?**
1. Open IIS Manager > Default Web Site > Bindings
2. Verify HTTPS binding on port 443 exists

**Check 3: Is the firewall blocking?**
1. Open `wf.msc`
2. Check Inbound Rules for ports 80 and 443

---

### Problem: "Your connection is not private" / SSL Error

**Check 1: Correct certificate?**
1. IIS Manager > Server Name > Server Certificates
2. Verify `*.zflow.io` certificate is listed and not expired

**Check 2: Certificate bound correctly?**
1. IIS Manager > Default Web Site > Bindings
2. Click the HTTPS binding > Edit
3. Verify SSL certificate shows `*.zflow.io`

**Check 3: Hostname matches?**
- The hostname in the binding must be a subdomain of `zflow.io`
- Example: `zflow26onwindows.zflow.io` matches `*.zflow.io`

---

### Problem: 502 Bad Gateway / 503 Service Unavailable

This means IIS is working but cannot reach Tomcat.

**Check 1: Is Tomcat running?**
1. Open Services (`services.msc`)
2. Find **Apache Tomcat 9.0 Tomcat9**
3. Status should be **Running**
4. If stopped, right-click > **Start**

**Check 2: Is Tomcat on port 8080?**
1. Open browser: `http://localhost:8080`
2. Should show ZFlow or Tomcat page

**Check 3: Is ARR Proxy enabled?**
1. IIS Manager > Server Name > Application Request Routing Cache
2. Click Server Proxy Settings
3. Verify **Enable proxy** is checked

---

### Problem: Page loads but shows IIS Default Page (not ZFlow)

**Check 1: Is the reverse proxy rule working?**
1. Open `C:\inetpub\wwwroot\web.config` in Notepad
2. Verify the `ReverseProxyToTomcat` rule exists
3. Verify the URL points to `http://localhost:8080/{R:1}`

**Check 2: Is URL Rewrite installed?**
1. Open IIS Manager > Server Name
2. Look for **URL Rewrite** in the center panel
3. If missing, install the URL Rewrite module (Step 2)

---

### Problem: HTTP not redirecting to HTTPS

**Check 1: web.config has redirect rule?**
1. Open `C:\inetpub\wwwroot\web.config`
2. Verify the "HTTP to HTTPS" rule exists

**Check 2: HTTP binding exists?**
1. IIS Manager > Default Web Site > Bindings
2. Must have an HTTP binding on port 80

---

### Where to Find Logs

| Log | How to Access |
|---|---|
| **IIS Logs** | File Explorer > `C:\inetpub\logs\LogFiles\W3SVC1\` |
| **Tomcat Logs** | File Explorer > `C:\ZFlow\tomcat\logs\` |
| **Event Viewer** | `Win + R > eventvwr.msc` > Windows Logs > System |
| **Failed Requests** | Enable in IIS Manager > Default Web Site > Failed Request Tracing Rules |

---

## Certificate Renewal via Console

When the certificate is about to expire, follow these steps to renew.

### 1. Get the New .pfx File

Obtain the renewed `.pfx` certificate file from your certificate provider. Copy it to the Desktop.

### 2. Import New Certificate

1. Open **IIS Manager** (`inetmgr`)
2. Click **Server Name** > **Server Certificates**
3. Click **Import...** in the right panel
4. Browse to the new `.pfx` file
5. Enter the password
6. Click **OK**

### 3. Update the Binding

1. Go to **Default Web Site** > **Bindings...**
2. Select the **https** binding
3. Click **Edit...**
4. In the **SSL certificate** dropdown, select the **new** certificate
5. Click **OK**
6. Click **Close**

### 4. Remove Old Certificate (Optional)

1. Go to Server Name > **Server Certificates**
2. Select the old (expired) certificate
3. Click **Remove** in the right panel

### 5. Verify

1. Open browser > `https://zflow26onwindows.zflow.io`
2. Click padlock > Certificate
3. Verify the new expiration date

---

## Complete Setup Checklist

Use this checklist when setting up at a client site:

```
PRE-SETUP
[ ] Windows Server accessible with Administrator login
[ ] .pfx certificate file copied to Desktop
[ ] Certificate password available
[ ] Tomcat installed with ZFlow deployed
[ ] Domain name decided (e.g., clientname.zflow.io)
[ ] DNS pointing to server IP (or will be configured after)

INSTALLATION
[ ] Step 1:  IIS Web Server role installed via Server Manager
[ ] Step 2:  URL Rewrite module installed
[ ] Step 3:  Application Request Routing (ARR) installed
[ ] Step 4:  ARR Proxy enabled in IIS Manager
[ ] Step 5:  SSL certificate imported via IIS Manager > Server Certificates
[ ] Step 6:  HTTPS binding added (port 443 + hostname + SNI + certificate)
[ ] Step 7:  web.config created at C:\inetpub\wwwroot\ with redirect and proxy rules
[ ] Step 8:  Tomcat service started and set to Automatic startup
[ ] Step 9:  Firewall rules added for ports 80 and 443
[ ] Step 9b: Cloud firewall (AWS/Azure) updated if applicable

VERIFICATION
[ ] http://localhost:8080 shows ZFlow (Tomcat direct)
[ ] https://yourdomain.zflow.io loads with padlock (HTTPS working)
[ ] http://yourdomain.zflow.io redirects to HTTPS (redirect working)
[ ] External browser loads the site without SSL warnings
[ ] Certificate details show correct wildcard and expiry date

POST-SETUP
[ ] Note certificate expiry date for renewal reminder
[ ] Document the server IP, domain, and configuration for client records
```

---

## Quick Navigation Reference

| Task | Where to Go |
|---|---|
| Open IIS Manager | `Win + R` > `inetmgr` |
| Open Services | `Win + R` > `services.msc` |
| Open Firewall | `Win + R` > `wf.msc` |
| Open Server Manager | `Win + R` > `servermanager` |
| Open Certificate Manager | `Win + R` > `certlm.msc` |
| Open Event Viewer | `Win + R` > `eventvwr.msc` |
| Open Notepad as Admin | Start > type Notepad > right-click > Run as administrator |
| IIS site root folder | `C:\inetpub\wwwroot\` |
| IIS log files | `C:\inetpub\logs\LogFiles\W3SVC1\` |
| Tomcat folder | `C:\ZFlow\tomcat\` |
| Tomcat logs | `C:\ZFlow\tomcat\logs\` |
| web.config file | `C:\inetpub\wwwroot\web.config` |

---

## Summary

| Component | Value |
|---|---|
| **Domain** | zflow26onwindows.zflow.io |
| **SSL Certificate** | *.zflow.io (wildcard) |
| **Certificate File** | zflowwildcard.pfx |
| **IIS HTTP Port** | 80 (redirects to HTTPS) |
| **IIS HTTPS Port** | 443 (SSL termination) |
| **Tomcat Port** | 8080 (internal only) |
| **Reverse Proxy** | IIS (443) --> Tomcat (8080) |
| **web.config** | C:\inetpub\wwwroot\web.config |

---

*Document created: April 3, 2026*
*For ZFlow HTTPS/SSL setup on Windows Server with IIS and Tomcat*
