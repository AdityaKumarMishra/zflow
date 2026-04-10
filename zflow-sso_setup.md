# zflow Microsoft SSO Setup Guide

End-to-end instructions for enabling Microsoft (Azure AD / Entra ID) Single
Sign-On for the zflow web application running on Apache Tomcat behind an
IIS reverse proxy on Windows.

This guide is the result of a working setup at
`https://zflow26onwindows.zflow.io/zflow` and covers every layer that needs
to be configured: Azure, zflow, Tomcat, IIS, and the verification steps.

---

## 1. Architecture overview

```
   Browser
      |
      | HTTPS (443)
      v
   IIS  ──── reverse proxy (URL Rewrite) ────► Tomcat (HTTP, port 8080)
                                                  |
                                                  v
                                              zflow webapp
                                                  |
                                                  v
                                          login.microsoftonline.com
```

Key facts that drive the configuration:

- TLS terminates at **IIS**. Tomcat speaks plain HTTP on `localhost:8080`.
- IIS rewrites every request to `http://localhost:8080/...`. As a result,
  the `Host` header Tomcat sees would be `localhost` unless we tell IIS to
  forward the original host (via `X-Forwarded-Host`) and tell Tomcat to
  honor it.
- The OAuth callback URL Microsoft redirects to **must** match exactly the
  redirect URI registered in the Azure App Registration. Any mismatch (host,
  scheme, port, path) produces `AADSTS50011`.
- The browser must keep the same JSESSIONID cookie across the round-trip
  to login.microsoftonline.com and back. This requires the cookie to be
  `SameSite=None; Secure`.

---

## 2. Prerequisites

- A working zflow installation under `C:\zflow\tomcat` (Tomcat 9 running as
  the Windows service `Tomcat9`).
- IIS installed with the **URL Rewrite** module (and ideally the
  **Application Request Routing** module enabled as a proxy).
- A public DNS hostname pointing at the IIS server, e.g.
  `zflow26onwindows.zflow.io`.
- A valid TLS certificate bound to that hostname in IIS.
- An Azure tenant with permission to register applications.
- Administrator access to the Windows Server hosting zflow.

---

## 3. Azure AD (Entra ID) — App Registration

1. Sign in to <https://portal.azure.com>.
2. Go to **Microsoft Entra ID** → **App registrations** → **New
   registration**.
3. Fill in:
   - **Name:** `zflow SSO` (or any name you like).
   - **Supported account types:** typically *Accounts in this organizational
     directory only (single tenant)*.
   - **Redirect URI:** select platform **Web** and enter the exact public
     callback URL:
     ```
     https://<your-public-host>/zflow/sso
     ```
     For the reference deployment this is:
     ```
     https://zflow26onwindows.zflow.io/zflow/sso
     ```
4. Click **Register**.
5. From the app's **Overview** page record the following — you will paste
   them into zflow's config later:
   - **Application (client) ID** → this becomes `MS_CLIENTID`.
   - **Directory (tenant) ID** → this becomes `MS_TENANTID`.
6. Go to **Certificates & secrets** → **Client secrets** → **New client
   secret**. Give it a description and an expiry. **Copy the secret VALUE
   immediately** — you cannot view it again. This becomes `MS_CLIENTSECRET`.
7. Go to **API permissions** and ensure the following Microsoft Graph
   delegated permissions are present (they are added by default for new
   registrations):
   - `openid`
   - `profile`
   - `email`
   - `User.Read`

   Click **Grant admin consent** if your tenant requires it.
8. Go back to **Authentication**. Confirm the redirect URI is listed
   exactly as `https://<your-public-host>/zflow/sso`. Save.

> Common pitfall: typos in the redirect URI. Scheme (`https`), host, port
> (none for 443), and path (`/zflow/sso`) must all match exactly.

---

## 4. zflow application configuration

Edit `C:\zflow\tomcat\webapps\zflow\WEB-INF\classes\cfg\ZFlowConfig.properties`
and set the following keys (create the lines if they do not exist):

```properties
# Public base URL of the zflow webapp — used to build the OAuth redirect_uri
LINK_BASE=https://<your-public-host>/zflow

# Microsoft / Azure AD SSO
MS_CLIENTID=<Application (client) ID from step 3>
MS_TENANTID=<Directory (tenant) ID from step 3>
MS_CLIENTSECRET=<client secret VALUE from step 3>
```

For the reference deployment:

```properties
LINK_BASE=https://zflow26onwindows.zflow.io/zflow
MS_CLIENTID=f9b8a907-a7a5-4c43-8be1-78d43f73a18f
MS_TENANTID=2c6dc040-47bb-4a6c-8ae3-42841907f789
MS_CLIENTSECRET=<your secret>
```

Notes:

- `LINK_BASE` must be the externally reachable URL, **not** a `localhost`
  URL. The zflow login JSP builds the OAuth redirect URI as
  `${LINK_BASE}/sso`, so this value directly determines what redirect URI
  Microsoft receives.
- zflow supports storing `MS_CLIENTSECRET` either as plain text or in its
  encrypted form (`AESENC:...`). If your installation already has secrets
  stored as `AESENC:...`, use the zflow admin UI or the encryption utility
  shipped with zflow to encrypt the new value rather than pasting plain
  text.
- The relevant code that reads these values is in
  `webapps/zflow/nui/sso_login.jsp` (lines ~75-79). The redirect URI sent
  to Microsoft is constructed as:
  ```
  redirect_uri = URLEncoder.encode(LINK_BASE + "/sso", "UTF-8")
  ```
- The callback is handled by the servlet
  `com.zesati.security.sso.SSOServlet`, mapped to `/sso` in
  `WEB-INF/web.xml`.

---

## 5. Tomcat configuration

Two changes are required in Tomcat. Both deal with the fact that Tomcat
sits behind an IIS reverse proxy.

### 5.1 Make Tomcat aware of the public scheme and host

Edit `C:\zflow\tomcat\conf\server.xml`. Inside the `<Host name="localhost"
…>` element add (or update) a `RemoteIpValve`:

```xml
<Valve className="org.apache.catalina.valves.RemoteIpValve"
       protocolHeader="X-Forwarded-Proto"
       remoteIpHeader="X-Forwarded-For"
       hostHeader="X-Forwarded-Host" />
```

What each attribute does:

- `protocolHeader="X-Forwarded-Proto"` — when IIS forwards
  `X-Forwarded-Proto: https`, Tomcat treats the request as HTTPS. This
  makes `request.isSecure()` return `true`, which in turn causes the
  session cookie to be marked `Secure` (mandatory for `SameSite=None`).
- `remoteIpHeader="X-Forwarded-For"` — preserves the real client IP for
  audit logs.
- `hostHeader="X-Forwarded-Host"` — Tomcat will use the value of
  `X-Forwarded-Host` for `request.getServerName()` instead of the
  literal `localhost` that IIS sends. Without this, anywhere zflow falls
  back to deriving a URL from the request, it produces a `localhost` URL
  — which is the most common cause of `AADSTS50011`.

### 5.2 Allow the JSESSIONID cookie to survive cross-site OAuth redirects

Edit `C:\zflow\tomcat\webapps\zflow\META-INF\context.xml` and replace the
`CookieProcessor` element with the RFC 6265 processor that supports
`SameSite`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Context>
  <WatchedResource>WEB-INF/web.xml</WatchedResource>
  <WatchedResource>WEB-INF/tomcat-web.xml</WatchedResource>
  <WatchedResource>${catalina.base}/conf/web.xml</WatchedResource>
  <CookieProcessor className="org.apache.tomcat.util.http.Rfc6265CookieProcessor"
                   sameSiteCookies="none" />
</Context>
```

Why this is required:

- The OAuth flow stores the random `state` value in the user's HTTP
  session before redirecting to Microsoft. When Microsoft redirects the
  browser back to `/zflow/sso`, the SSOServlet must find the same session
  to validate `state`.
- Modern browsers default cookies to `SameSite=Lax`, which **suppresses**
  cookies on cross-site redirects from third-party origins
  (login.microsoftonline.com → your site). The result: a brand-new empty
  session is created on the callback, `stateDataInSession` is `null`, and
  the SSOServlet throws "Failed to validate data received from
  Authorization service - could not validate state".
- Setting `sameSiteCookies="none"` tells Tomcat to add `SameSite=None` to
  every cookie it issues. Browsers require `SameSite=None` cookies to
  also be `Secure`; this is satisfied automatically because the
  `RemoteIpValve` (5.1) makes Tomcat treat the request as HTTPS.
- The legacy default `LegacyCookieProcessor` does **not** support
  `SameSite` at all and must be replaced.

### 5.3 Apply the changes

Restart the Tomcat service so both files are reloaded:

```cmd
net stop Tomcat9
net start Tomcat9
```

Tomcat will reload `ZFlowConfig.properties`, `server.xml`, and
`META-INF/context.xml` on startup. Verify the service started cleanly:

```cmd
sc query Tomcat9
```

and check `C:\zflow\tomcat\logs\zflow\zflowlog.log` for the line
`zflow: Initialization completed`.

---

## 6. IIS reverse proxy configuration

The reference deployment uses IIS with **URL Rewrite** to forward all
traffic to Tomcat. The site is bound to `https://<your-public-host>` on
port 443 with a TLS certificate.

The required rewrite rules live in the site's `web.config` (or can be
edited via **IIS Manager → URL Rewrite**):

```xml
<system.webServer>
  <rewrite>
    <rules>

      <!-- Force HTTPS -->
      <rule name="HTTP to HTTPS" stopProcessing="true">
        <match url="(.*)" />
        <conditions>
          <add input="{HTTPS}" pattern="^OFF$" />
        </conditions>
        <action type="Redirect" url="https://{HTTP_HOST}/{R:1}"
                redirectType="Permanent" />
      </rule>

      <!-- Reverse proxy to Tomcat, preserving the original host & scheme -->
      <rule name="ReverseProxyToTomcat" stopProcessing="true">
        <match url="(.*)" />
        <serverVariables>
          <set name="HTTP_X_FORWARDED_PROTO" value="https" />
          <set name="HTTP_X_FORWARDED_HOST"  value="{HTTP_HOST}" />
        </serverVariables>
        <action type="Rewrite" url="http://localhost:8080/{R:1}" />
      </rule>

    </rules>
  </rewrite>
</system.webServer>
```

Key points:

- The two `<set>` lines inject the `X-Forwarded-Proto` and
  `X-Forwarded-Host` headers that the Tomcat `RemoteIpValve` (5.1)
  consumes.
- For IIS to allow setting arbitrary `HTTP_*` server variables, you must
  first add them to the **Allowed Server Variables** list at the IIS
  server-root level (IIS Manager → server name → URL Rewrite → View Server
  Variables → Add):
  - `HTTP_X_FORWARDED_PROTO`
  - `HTTP_X_FORWARDED_HOST`
- After editing, run `iisreset` (or restart the site).

If you ever change these and start seeing `localhost` in Microsoft error
messages or in the redirect URI, that almost always means
`X-Forwarded-Host` is not being forwarded — re-check this section.

---

## 7. Verification

1. Open a fresh browser window (or clear cookies for the site) and go to
   `https://<your-public-host>/zflow`.
2. Click **Sign in with Microsoft**. The browser should redirect to
   `login.microsoftonline.com`.
3. Sign in with your Microsoft account.
4. The browser should redirect back to
   `https://<your-public-host>/zflow/sso?code=...&state=...` and then
   land on the zflow main page logged in.

While testing, tail these logs:

- `C:\zflow\tomcat\logs\zflow\zflowlog.log` — application-level SSO
  events. On a successful sign-in you will see lines like:
  ```
  SSOServlet, uri:https://<host>/zflow/sso authCode: ... state: ...
  validateState, state:...
  ```
  with **no** "Failed to validate" error.
- `C:\zflow\tomcat\logs\localhost_access_log.YYYY-MM-DD.txt` — should
  show `GET /zflow/sso?code=... 302 -` followed by a 200/302 chain into
  the application, **not** a 404 or 500 on `/zflow/sso`.

---

## 8. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `AADSTS50011: redirect URI ... does not match` and the URI shown contains `localhost` | Tomcat is producing a `localhost` URL because (a) `LINK_BASE` is not set or empty, or (b) IIS isn't forwarding `X-Forwarded-Host`, or (c) Tomcat's `RemoteIpValve` lacks `hostHeader="X-Forwarded-Host"`. | Re-check sections **4**, **5.1**, and **6**. Restart Tomcat after any change to `ZFlowConfig.properties`. |
| `AADSTS50011` and the URI shown contains the correct host but is missing from Azure | The exact callback URL is not registered in the Azure app. | In Azure → App Registration → **Authentication**, add the exact `https://<host>/zflow/sso` value as a **Web** redirect URI and Save. |
| Tomcat returns `404 Not Found` on `/zflow/sso`, but `zflowlog.log` shows `Failed to validate data received from Authorization service - could not validate state` and `New session created` | The browser dropped the JSESSIONID cookie on the cross-site redirect from Microsoft. The cookie isn't `SameSite=None; Secure`. | Apply section **5.2** (`Rfc6265CookieProcessor` with `sameSiteCookies="none"`) and ensure the `RemoteIpValve` from 5.1 is in place so Tomcat sees the request as HTTPS. Restart Tomcat. |
| Redirect loop between zflow and Microsoft | `LINK_BASE` mismatch with the registered redirect URI (e.g. trailing slash, http vs https). | Make `LINK_BASE` and the Azure-registered redirect URI byte-identical apart from the `/sso` suffix that zflow appends. |
| Login works in Edge/IE but fails in Chrome/Firefox | Almost always the `SameSite` cookie issue (5.2). | Same fix as the 404/state-validation row above. |
| `MS_CLIENTSECRET` rejected by Microsoft | The secret was rotated or expired in Azure, or you copied the secret **ID** instead of the **VALUE**. | In Azure → App Registration → **Certificates & secrets**, generate a new client secret, copy its **Value** (only shown once), and update `MS_CLIENTSECRET`. Restart Tomcat. |
| `ZFlowConfig.properties` edits have no effect | Tomcat reads the file at startup; it does not hot-reload. | Restart the `Tomcat9` service. |

Useful diagnostic commands:

```cmd
:: Service status
sc query Tomcat9

:: Recent SSO activity
findstr /C:"SSOServlet" C:\zflow\tomcat\logs\zflow\zflowlog.log

:: Recent /sso HTTP responses
findstr /C:"/zflow/sso" C:\zflow\tomcat\logs\localhost_access_log.*.txt
```

---

## 9. Files touched by this setup (cheat sheet)

| File | Purpose |
|---|---|
| Azure portal — App Registration | Client/Tenant IDs, client secret, redirect URI |
| `C:\zflow\tomcat\webapps\zflow\WEB-INF\classes\cfg\ZFlowConfig.properties` | `LINK_BASE`, `MS_CLIENTID`, `MS_TENANTID`, `MS_CLIENTSECRET` |
| `C:\zflow\tomcat\conf\server.xml` | `RemoteIpValve` with `hostHeader="X-Forwarded-Host"` |
| `C:\zflow\tomcat\webapps\zflow\META-INF\context.xml` | `Rfc6265CookieProcessor` + `sameSiteCookies="none"` |
| IIS site `web.config` (URL Rewrite) | HTTPS redirect + reverse proxy with `X-Forwarded-Proto` / `X-Forwarded-Host` |
| Tomcat service | Restart after every config change above |

---

## 10. Optional: also enabling Okta or Google SSO

The same login JSP (`webapps/zflow/nui/sso_login.jsp`) supports Okta and
Google in addition to Microsoft. The configuration keys are:

- **Okta:** `OKTA_URL`, `OKTA_CLIENTID` — callback path is `/zflow/oktasso`,
  servlet `com.zesati.security.oktasso.OktaSSOServlet`.
- **Google Workspace:** `GSUITE=true`, `GOOGLE_CLIENTID` — uses Google's
  JS button, no server-side redirect URI to register beyond the standard
  Google OAuth client config.

The Tomcat (sections 5.1, 5.2) and IIS (section 6) steps in this guide
apply identically to those providers — the cookie/host fixes are not
Microsoft-specific.
