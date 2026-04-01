# ZClaude — Developer Knowledge Transfer Document

**Date:** April 2026
**From:** Aditya
**To:** [Developer Name]
**Project:** ZClaude Extension System for ZFlow

---

## TABLE OF CONTENTS

1. [What is ZClaude?](#1-what-is-zclaude)
2. [Why was it built?](#2-why-was-it-built)
3. [System Architecture](#3-system-architecture)
4. [Server & Infrastructure](#4-server--infrastructure)
5. [Component 1: Java Extension SDK](#5-component-1-java-extension-sdk)
6. [Component 2: AI Chat Server (Python)](#6-component-2-ai-chat-server-python)
7. [Component 3: Chat UI (HTML/JS)](#7-component-3-chat-ui-htmljs)
8. [Component 4: Nginx Routing](#8-component-4-nginx-routing)
9. [How ZFlow Discovers Extensions](#9-how-zflow-discovers-extensions)
10. [The AI Tool-Use Loop](#10-the-ai-tool-use-loop)
11. [File Inventory — Every File and Its Purpose](#11-file-inventory--every-file-and-its-purpose)
12. [ZFlow APIs Available to Extensions](#12-zflow-apis-available-to-extensions)
13. [How to Make Changes](#13-how-to-make-changes)
14. [How to Deploy to a New Customer](#14-how-to-deploy-to-a-new-customer)
15. [Troubleshooting Guide](#15-troubleshooting-guide)
16. [Credentials & Access](#16-credentials--access)
17. [Key Decisions & Why](#17-key-decisions--why)

---

## 1. What is ZClaude?

ZClaude is a system that lets customers extend their deployed ZFlow application without source code access, Maven, or Java expertise.

It has two modes:

**Mode 1 — Manual (Terminal):**
Customer SSHs into server → writes a Java file → runs `build.sh` → extension is live.

**Mode 2 — AI-Assisted (Browser):**
Customer opens `https://zora.zmdm.net/zclaude` → types requirement in English → AI writes code, builds, deploys, tests automatically.

---

## 2. Why Was It Built?

**The problem:** ZFlow is a compiled Java WAR deployed on Tomcat. Customers get the WAR but not the source code. When they need customizations (custom API, workflow function, report), they must ask us to rebuild the WAR. This takes days/weeks.

**The solution:** A self-contained extension directory inside the deployed webapp. Java files compiled with `javac` against existing JARs. No Maven, no source code, no WAR rebuild.

**The AI layer:** Customers don't need to know Java. They describe what they want, Claude API writes the code using CLAUDE.md as its guide.

---

## 3. System Architecture

```
                    INTERNET
                       │
                       ▼
              ┌────────────────┐
              │   Nginx (443)  │  SSL termination + routing
              └───┬────┬────┬──┘
                  │    │    │
    /zclaude/*    │    │    │  /zflow/*          /*
                  │    │    │
         ┌────────┘    │    └────────┐
         ▼             │             ▼
  ┌──────────────┐     │     ┌──────────────┐
  │ ZClaude AI   │     │     │   Ask Zora   │
  │ Python/Flask │     │     │   Python     │
  │ Port 8002    │     │     │   Port 8001  │
  └──────┬───────┘     │     └──────────────┘
         │             │
         │ Calls       │
         ▼             ▼
  ┌──────────────┐  ┌──────────────────────────┐
  │ Claude API   │  │ ZFlow (Tomcat 9)         │
  │ (Anthropic)  │  │ Port 8080                │
  │ Sonnet 4     │  │                          │
  └──────────────┘  │ ┌──────────────────────┐ │
                    │ │ WEB-INF/lib/          │ │
  Python server     │ │  zbase-1.0.jar       │ │
  also writes to:   │ │  zcustom-1.0.jar     │ │
         │          │ │  zclaude.jar ◄────────┼─┼── built by build.sh
         ▼          │ │  ...137 other JARs   │ │
  ┌──────────────┐  │ └──────────────────────┘ │
  │ WEB-INF/     │  │                          │
  │ zclaude/     │  │ ┌──────────────────────┐ │
  │  src/*.java  │  │ │ MySQL 8.0            │ │
  │  build.sh    │  │ │ Database: zflow      │ │
  │  CLAUDE.md   │  │ │ 176 tables           │ │
  └──────────────┘  │ └──────────────────────┘ │
                    └──────────────────────────┘
```

---

## 4. Server & Infrastructure

### EC2 Instance

| Item | Value |
|------|-------|
| Instance ID | i-02882686850b260b0 |
| Name | "test for zora" |
| IP | 3.211.67.251 |
| OS | Ubuntu 24.04 LTS |
| Type | (check AWS console) |
| Region | us-east-1 |
| SSH Key | `zflow.pem` (in Aditya's Downloads) |

### SSH Access

```bash
ssh -i "zflow.pem" ubuntu@3.211.67.251
```

### Services Running

| Service | Command | Port |
|---------|---------|------|
| ZClaude AI | `sudo systemctl status zclaude` | 8002 |
| Tomcat/ZFlow | `sudo /opt/tomcat9/bin/startup.sh` | 8080 |
| Ask Zora | `sudo systemctl status ask-zora` | 8001 |
| Nginx | `sudo systemctl status nginx` | 80/443 |
| MySQL | `sudo systemctl status mysql` | 3306 |

### DNS

`zora.zmdm.net` → 3.211.67.251 (SSL via Let's Encrypt)

---

## 5. Component 1: Java Extension SDK

### Location

```
/opt/tomcat9/webapps/zflow/WEB-INF/zclaude/
├── build.sh                    # Build & deploy script
├── CLAUDE.md                   # AI guide (teaches Claude ZFlow APIs)
├── src/
│   └── com/zesati/
│       ├── controllers/        # REST API controllers
│       │   ├── ZClaudeController.java      # Main controller (8 endpoints)
│       │   └── CustomerDemoController.java  # Demo controller
│       ├── external/           # Workflow functions
│       │   └── HelloWorldFunction.java
│       ├── handler/            # Servlet handlers
│       │   └── ZClaudeHandler.java
│       └── claude/             # Utility classes
│           └── ZClaudeUtil.java
└── build/                      # Compiled output (auto-generated)
    ├── com/zesati/.../*.class
    └── zclaude.jar
```

### build.sh — What It Does

```
Step 1: rm -rf build/
Step 2: find src/ -name "*.java"
Step 3: javac -source 11 -target 11 \
          -cp WEB-INF/classes:WEB-INF/lib/*.jar:tomcat/lib/*.jar \
          -d build/ \
          [all .java files]
Step 4: cd build/ && jar cf zclaude.jar com/
Step 5: cp zclaude.jar ../lib/zclaude.jar
Step 6: shutdown.sh → sleep → startup.sh
```

Run it:
```bash
sudo /opt/tomcat9/webapps/zflow/WEB-INF/zclaude/build.sh          # full deploy
sudo /opt/tomcat9/webapps/zflow/WEB-INF/zclaude/build.sh compile  # compile only, no restart
```

### CLAUDE.md — Why It Matters

This file is loaded into the Claude API system prompt. It teaches the AI:

- What packages to use (`com.zesati.controllers`, `com.zesati.external`, etc.)
- How to write a `@RestController` extending `BaseController`
- How to write an `AbstractFunction` for workflows
- Available APIs: `DataService`, `ZSQL`, `WorkFlowService`, `CollabService`, `ZResource`
- Connection handling pattern (get → setCommit → work → commit → returnConnection in finally)
- The `SpecialFunctionTemplate.txt` pattern for workflow functions

**If you update ZFlow APIs, update CLAUDE.md too** — otherwise the AI will write incorrect code.

### Java Files Explained

#### ZClaudeController.java
The main REST controller. Endpoints:

| Endpoint | Auth | Purpose |
|----------|------|---------|
| GET /rest/zclaude/health | No | Health check + JVM stats |
| GET /rest/zclaude/hello | Yes | Greeting with user context |
| GET /rest/zclaude/status | Yes | System status (admin sees more) |
| POST /rest/zclaude/echo | Yes | Echo back posted JSON |
| GET /rest/zclaude/data/{cls} | Yes | Query data objects |
| GET /rest/zclaude/count/{cls} | Yes | Count data objects |
| POST /rest/zclaude/sql | Admin | Execute SELECT queries |
| GET /rest/zclaude/workflow/{id}/activities | Yes | List workflow activities |

Key patterns used:
- Extends `BaseController` → gives `getUser(request)`, `isAllowed()`
- Returns `Map<String, Object>` → Spring serializes to JSON
- Uses `LinkedHashMap<String, Object>` (not diamond `<>`) for Java 11 compat
- Uses `@RequestMapping` not `@GetMapping` (Spring 4.1.5)

#### HelloWorldFunction.java
Sample workflow ExternalFunction. Follows the `SpecialFunctionTemplate.txt` pattern:

```java
public class HelloWorldFunction extends AbstractFunction {
    public boolean execute(User usr, ZRootImpl activity, CollaborationImpl collab) {
        ZConnection conn = null;
        try {
            conn = ZResource.getConnection();
            conn.setCommit(false);
            // ... do work ...
            ZSQL.UpdateObjMetaDataFast(usr, conn, activity.getCoreData(), "FunctionStatus", "Successful");
            conn.Commit();
            return true;
        } catch (Exception e) {
            // ... rollback, set error status ...
            return false;
        } finally {
            ZResource.returnConnection(conn);  // ALWAYS in finally
        }
    }
}
```

#### ZClaudeHandler.java
Sample servlet handler extending `RequestHandler`. Has access to `session`, `cfg`, `meta` after `init()`.

#### ZClaudeUtil.java
Convenience wrappers: `executeQuery()`, `searchDataObjects()`, `getProcess()`, `log()`.

---

## 6. Component 2: AI Chat Server (Python)

### File: `/home/ubuntu/zclaude-server.py`

**Framework:** Flask
**Port:** 8002
**Python:** 3.12 (system) via `/home/ubuntu/venv/`
**Dependencies:** `flask`, `anthropic`

### Routes

| Route | Method | Purpose |
|-------|--------|---------|
| `/` | GET | Serves zclaude.html |
| `/api/chat` | POST | Send message, get AI response |
| `/api/reset` | POST | Clear conversation history |
| `/api/files` | GET | List Java files in src/ |
| `/api/health` | GET | Server status check |

### How `/api/chat` Works

```python
def chat():
    message = request.json["message"]
    # Calls chat_with_claude() which:
    #   1. Appends message to conversation_history[]
    #   2. Calls Claude API with:
    #      - model: claude-sonnet-4
    #      - system: SYSTEM_PROMPT (contains CLAUDE.md)
    #      - tools: 6 tool definitions
    #      - messages: conversation_history
    #   3. If Claude returns tool_use:
    #      - Execute the tool (write_file, run_build, etc.)
    #      - Send tool result back to Claude
    #      - Loop (max 10 iterations)
    #   4. If Claude returns text:
    #      - Return to browser
    return jsonify({"response": text, "tools_used": log})
```

### The 6 Tools

Each tool is a Python function that the server executes when Claude asks for it:

```python
def tool_list_files():
    # os.walk() over src/ directory
    # Returns: {"files": ["com/zesati/controllers/MyFile.java", ...]}

def tool_read_file(path):
    # open(SRC_DIR + path).read()
    # Security: checks realpath stays within SRC_DIR

def tool_write_file(path, content):
    # mkdir -p + open(path, "w").write(content)
    # Security: checks realpath stays within SRC_DIR

def tool_delete_file(path):
    # os.remove(SRC_DIR + path)

def tool_run_build():
    # subprocess.run(["sudo", "build.sh"], timeout=120)
    # Returns stdout + stderr + success/fail

def tool_test_endpoint(method, path, body=None):
    # curl http://localhost:8080/zflow{path}
    # If "Not logged in" → reports success (auth required = endpoint working)
```

### System Prompt Structure

```python
SYSTEM_PROMPT = f"""You are ZClaude — an AI assistant that builds ZFlow extensions.

## Rules
- When test_endpoint returns "Not logged in", that means success — don't retry
- Always put REST controllers in com.zesati.controllers
- Always put ExternalFunctions in com.zesati.external
- Use LinkedHashMap<String, Object> for Java 11 compat
- Use @RequestMapping not @GetMapping (Spring 4.1.5)
- After writing code, always run the build
...

## ZFlow SDK Reference
{load_claude_md()}   ← This loads the entire CLAUDE.md file
"""
```

### Systemd Service

File: `/etc/systemd/system/zclaude.service`

```ini
[Unit]
Description=ZClaude AI Extension Builder
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/ubuntu
Environment=ANTHROPIC_API_KEY=sk-ant-api03-...
ExecStart=/home/ubuntu/venv/bin/python /home/ubuntu/zclaude-server.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Commands:
```bash
sudo systemctl start zclaude
sudo systemctl stop zclaude
sudo systemctl restart zclaude
sudo systemctl status zclaude
sudo journalctl -u zclaude -n 50    # View logs
```

### API Key

The Anthropic API key is stored in the systemd service file. To update:

```bash
sudo vi /etc/systemd/system/zclaude.service
# Change the Environment=ANTHROPIC_API_KEY=... line
sudo systemctl daemon-reload
sudo systemctl restart zclaude
```

**Important:** Claude Pro subscription (claude.ai) is NOT the same as API credits (console.anthropic.com). They need API credits purchased separately at https://console.anthropic.com/settings/billing.

---

## 7. Component 3: Chat UI (HTML/JS)

### File: `/home/ubuntu/zclaude.html`

Single HTML file with embedded CSS and JS. No build system, no npm.

### Key Features
- Dark theme chat interface
- Left sidebar: file list (refreshes after builds)
- Center: chat messages with markdown rendering (uses `marked.js` CDN)
- Bottom: text input + send button
- Tool call badges (green for write, yellow for build, purple for test)
- Status bar showing connection state

### API Calls

All fetch calls use `API_BASE = '/zclaude'` prefix:

```javascript
fetch(API_BASE + '/api/chat', { method: 'POST', body: JSON.stringify({message}) })
fetch(API_BASE + '/api/files')
fetch(API_BASE + '/api/reset', { method: 'POST' })
fetch(API_BASE + '/api/health')
```

### To Modify the UI

Edit `/home/ubuntu/zclaude.html` directly on the server. No build step needed — Flask serves it directly. Just refresh the browser.

---

## 8. Component 4: Nginx Routing

### File: `/etc/nginx/sites-enabled/zora.zmdm.net`

```nginx
server {
    server_name zora.zmdm.net;

    # ZClaude AI Builder (port 8002)
    location /zclaude {
        proxy_pass http://127.0.0.1:8002/;
        proxy_read_timeout 300s;          # Long timeout for AI calls
        ...
    }
    location /zclaude/api/ {
        proxy_pass http://127.0.0.1:8002/api/;
        proxy_read_timeout 300s;
        ...
    }

    # ZFlow (port 8080)
    location /zflow/ {
        proxy_pass http://127.0.0.1:8080/zflow/;
        ...
    }

    # Ask Zora (port 8001) — default
    location / {
        proxy_pass http://127.0.0.1:8001;
        ...
    }

    # SSL (Let's Encrypt)
    listen 443 ssl;
    ssl_certificate /etc/letsencrypt/live/zora.zmdm.net/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/zora.zmdm.net/privkey.pem;
}
```

After editing:
```bash
sudo nginx -t                  # Test config
sudo systemctl reload nginx    # Apply changes
```

---

## 9. How ZFlow Discovers Extensions

### REST Controllers

ZFlow's `web.xml` maps `/rest/*` to Spring's `DispatcherServlet`:
```xml
<servlet-name>rest-dispatcher</servlet-name>
<url-pattern>/rest/*</url-pattern>
```

`rest-dispatcher-servlet.xml` configures component scanning:
```xml
<context:component-scan base-package="com.zesati.controllers" />
```

When Tomcat loads `zclaude.jar`, Spring scans it and finds any `@RestController` in `com.zesati.controllers`. The `@RequestMapping("/zclaude")` annotation registers the endpoint paths.

**Key:** Controller MUST be in `com.zesati.controllers` package. Other packages won't be scanned.

### Workflow ExternalFunctions

`WorkFlowService` loads functions by class name:
```java
Class.forName("com.zesati.external." + functionName)
```

Since `zclaude.jar` is in `WEB-INF/lib/`, it's on the classpath. `Class.forName` finds the class automatically.

**Key:** Function MUST be in `com.zesati.external` package and extend `AbstractFunction` or `AbstractFunctionWParams`.

### Servlet Handlers

`ZesatiControllerServlet` loads handlers via reflection from `com.zesati.handler` package. Same classpath mechanism.

---

## 10. The AI Tool-Use Loop

This is the core mechanism. When a user sends a message:

```
1. User: "Add an endpoint that returns overdue processes"
   │
   ▼
2. Python server sends to Claude API:
   - system prompt (CLAUDE.md)
   - tools (6 definitions)
   - messages (conversation history)
   │
   ▼
3. Claude responds: stop_reason = "tool_use"
   "I want to call list_files"
   │
   ▼
4. Python executes: tool_list_files()
   Returns: ["ZClaudeController.java", ...]
   │
   ▼
5. Python sends tool result back to Claude API
   │
   ▼
6. Claude responds: stop_reason = "tool_use"
   "I want to call write_file" + Java code
   │
   ▼
7. Python executes: tool_write_file(path, content)
   Writes .java file to disk
   │
   ▼
8. Python sends tool result back to Claude API
   │
   ▼
9. Claude responds: stop_reason = "tool_use"
   "I want to call run_build"
   │
   ▼
10. Python executes: subprocess.run(["sudo", "build.sh"])
    javac compiles → jar packages → cp to lib → restart Tomcat
    │
    ▼
11. Python sends build output back to Claude API
    │
    ▼
12. Claude responds: stop_reason = "tool_use"
    "I want to call test_endpoint"
    │
    ▼
13. Python executes: curl http://localhost:8080/zflow/rest/zclaude/overdue
    │
    ▼
14. Python sends test result back to Claude API
    │
    ▼
15. Claude responds: stop_reason = "end_turn"
    "Done! Your endpoint is live at /rest/zclaude/overdue..."
    │
    ▼
16. Python returns to browser:
    { "response": "Done!...", "tools_used": [...] }
```

**Each numbered step 2→3, 5→6, 8→9, etc. is a separate HTTP call to Claude API.**

A single user message typically makes **4-6 Claude API calls** (list → read → write → build → test → respond).

**Max iterations:** 10 (prevents infinite loops). If Claude hits this limit, user sees "Reached maximum iterations."

---

## 11. File Inventory — Every File and Its Purpose

### On the Server

| File | Path | Purpose | Modify when |
|------|------|---------|-------------|
| **zclaude-server.py** | /home/ubuntu/ | AI chat backend | Adding tools, changing models, fixing bugs |
| **zclaude.html** | /home/ubuntu/ | Chat UI | Changing layout, adding features |
| **zclaude.service** | /etc/systemd/system/ | Systemd service | Changing API key, restart behavior |
| **zora.zmdm.net** | /etc/nginx/sites-enabled/ | Nginx routing | Adding routes, changing ports |
| **build.sh** | WEB-INF/zclaude/ | Compile + deploy script | Changing Java version, paths |
| **CLAUDE.md** | WEB-INF/zclaude/ | AI guide to ZFlow APIs | When ZFlow APIs change |
| **ZClaudeController.java** | WEB-INF/zclaude/src/.../controllers/ | Main REST endpoints | Adding/changing base endpoints |
| **CustomerDemoController.java** | WEB-INF/zclaude/src/.../controllers/ | Demo endpoints | Demo purposes |
| **HelloWorldFunction.java** | WEB-INF/zclaude/src/.../external/ | Sample workflow function | Demo/template |
| **ZClaudeHandler.java** | WEB-INF/zclaude/src/.../handler/ | Sample handler | Demo/template |
| **ZClaudeUtil.java** | WEB-INF/zclaude/src/.../claude/ | Utility wrappers | Adding helpers |
| **zclaude.jar** | WEB-INF/lib/ | Compiled extensions | Auto-generated by build.sh |

### On Local Machine

| File | Path | Purpose |
|------|------|---------|
| zclaude-demo-script.md | /Users/aditya/Documents/Kris/ | Client demo script |
| zclaude-developer-kt.md | /Users/aditya/Documents/Kris/ | This KT document |
| zflow.pem | ~/Downloads/ | SSH key for server |

---

## 12. ZFlow APIs Available to Extensions

These are the APIs that extensions can use (documented in CLAUDE.md):

### Data Access

```java
// Query objects
Vector records = DataService.getDataObjects(usr, "ClassName", "WHERE clause", limit);
ZRootImpl obj = DataService.getDataObject(usr, "ClassName", "uniqueId");
long count = DataService.countDataObjects(usr, "ClassName", "WHERE clause");

// Create/update
ZRootImpl newObj = DataService.createObject(usr, hashtable);
DataService.updateObject(usr, obj, hashtable);
```

### Process/Workflow

```java
// Get process
CollaborationImpl collab = CollabService.getCollab(usr, processId);
ZRootImpl attrObj = collab.getAttrObject(usr, conn);

// Workflow
Vector activities = WorkFlowService.getActivities(usr, processId);
ZRootImpl current = WorkFlowService.getCurrentActivity(usr, processId);
```

### Database

```java
// Always use try/finally pattern:
ZConnection conn = null;
try {
    conn = ZResource.getConnection();
    conn.setCommit(false);
    Vector results = ZSQL.getQueryResults(usr, conn, "SELECT ...", 100, 0);
    conn.Commit();
} finally {
    ZResource.returnConnection(conn);  // CRITICAL — always in finally
}
```

### Config & Metadata

```java
CollabConfig cfg = ZResource.getConfig();
String value = cfg.getValue("CONFIG_KEY");

CollabMeta meta = ZResource.getMeta();
Vector attrs = meta.getClassAttrs("ClassName");
```

### Auth (in Controllers)

```java
User usr = getUser(request);           // From BaseController
boolean admin = usr.isAdminUser();
boolean allowed = isAllowed(request, usr, "Permission");
```

---

## 13. How to Make Changes

### Change the AI model

In `zclaude-server.py`, find:
```python
model="claude-sonnet-4-20250514"
```
Change to another model (e.g., `claude-haiku-4-5-20251001` for cheaper/faster).

Restart: `sudo systemctl restart zclaude`

### Add a new AI tool

In `zclaude-server.py`:

1. Add tool definition to `TOOLS` list:
```python
{
    "name": "my_new_tool",
    "description": "What it does",
    "input_schema": {
        "type": "object",
        "properties": { "param": { "type": "string" } },
        "required": ["param"]
    }
}
```

2. Add implementation:
```python
def tool_my_new_tool(param):
    # Do something
    return json.dumps({"result": "value"})
```

3. Add to `execute_tool()`:
```python
elif name == "my_new_tool":
    return tool_my_new_tool(input_data["param"])
```

4. Restart: `sudo systemctl restart zclaude`

### Update CLAUDE.md

When ZFlow APIs change, update:
```
/opt/tomcat9/webapps/zflow/WEB-INF/zclaude/CLAUDE.md
```

Then restart ZClaude server (it loads CLAUDE.md at startup):
```bash
sudo systemctl restart zclaude
```

### Add a new base Java extension

1. Create file in `WEB-INF/zclaude/src/com/zesati/[package]/`
2. Run `sudo /opt/tomcat9/webapps/zflow/WEB-INF/zclaude/build.sh`

### Change the UI

Edit `/home/ubuntu/zclaude.html` directly. No restart needed — just refresh browser.

### Change API key

```bash
sudo vi /etc/systemd/system/zclaude.service
# Edit: Environment=ANTHROPIC_API_KEY=sk-ant-...
sudo systemctl daemon-reload
sudo systemctl restart zclaude
```

---

## 14. How to Deploy to a New Customer

### Prerequisites on customer server
- Java 11+ (for javac)
- Tomcat 9 with ZFlow deployed
- Python 3.8+ with pip
- nginx (for SSL/routing)
- Anthropic API key

### Steps

**Step 1: Create the extension SDK**
```bash
ZFLOW_DIR=/path/to/webapps/zflow
mkdir -p $ZFLOW_DIR/WEB-INF/zclaude/src/com/zesati/{controllers,external,handler,claude}
```

Copy these files into `WEB-INF/zclaude/`:
- `build.sh` (update TOMCAT_HOME path if different)
- `CLAUDE.md`
- Sample Java files (optional)

```bash
chmod +x $ZFLOW_DIR/WEB-INF/zclaude/build.sh
```

**Step 2: Set up the AI server**
```bash
# Install dependencies
pip3 install flask anthropic

# Copy files
cp zclaude-server.py /home/ubuntu/
cp zclaude.html /home/ubuntu/

# Update paths in zclaude-server.py if Tomcat is in different location:
# ZCLAUDE_DIR = "/path/to/webapps/zflow/WEB-INF/zclaude"
```

**Step 3: Create systemd service**
```bash
sudo tee /etc/systemd/system/zclaude.service << EOF
[Unit]
Description=ZClaude AI Extension Builder
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/ubuntu
Environment=ANTHROPIC_API_KEY=sk-ant-CUSTOMER-KEY-HERE
ExecStart=/path/to/python /home/ubuntu/zclaude-server.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable zclaude
sudo systemctl start zclaude
```

**Step 4: Configure nginx**

Add to the site config:
```nginx
location /zclaude {
    proxy_pass http://127.0.0.1:8002/;
    proxy_read_timeout 300s;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
location /zclaude/api/ {
    proxy_pass http://127.0.0.1:8002/api/;
    proxy_read_timeout 300s;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

```bash
sudo nginx -t && sudo systemctl reload nginx
```

**Step 5: Test**
```bash
# Health check
curl http://localhost:8002/api/health

# Build test
sudo /path/to/webapps/zflow/WEB-INF/zclaude/build.sh compile

# Open in browser
https://customer-domain/zclaude
```

---

## 15. Troubleshooting Guide

### ZClaude chat says "Server unreachable"

```bash
# Check if service is running
sudo systemctl status zclaude

# If not running, check why
sudo journalctl -u zclaude -n 50

# Common fix: restart
sudo systemctl restart zclaude
```

### ZClaude chat says "API Credits Required"

Customer needs to buy API credits:
- Go to https://console.anthropic.com/settings/billing
- Add payment method
- Buy credits ($5 minimum)

### Build fails with compilation error

```bash
# Check the error
sudo /opt/tomcat9/webapps/zflow/WEB-INF/zclaude/build.sh compile 2>&1

# Common causes:
# - Wrong import (class doesn't exist in zbase-1.0.jar)
# - Syntax error in Java
# - Wrong package declaration
```

### Endpoint returns "Not logged in"

This is expected for authenticated endpoints. User must:
1. Login at /zflow/nui/login.jsp first
2. Then access the endpoint in same browser

OR use session-based curl:
```bash
curl -c cookies.txt -d 'command=login&userid=admin@zflow.io&paswd=ZFlowAdmin2026!&language=en&country=US' http://localhost:8080/zflow/servlet/zapp
curl -b cookies.txt http://localhost:8080/zflow/rest/zclaude/hello
```

### Tomcat won't start after build

```bash
# Check logs
sudo tail -100 /opt/tomcat9/logs/catalina.out

# If zclaude.jar is causing issues, remove it
sudo rm /opt/tomcat9/webapps/zflow/WEB-INF/lib/zclaude.jar
sudo /opt/tomcat9/bin/startup.sh

# Fix the Java code, then rebuild
sudo /opt/tomcat9/webapps/zflow/WEB-INF/zclaude/build.sh
```

### Nginx returns 502 Bad Gateway

```bash
# Check if target service is running
curl http://localhost:8002/api/health   # ZClaude
curl http://localhost:8080/zflow/       # Tomcat

# Restart the dead service
sudo systemctl restart zclaude
# or
sudo /opt/tomcat9/bin/startup.sh
```

### AI keeps retrying test_endpoint in loop

This was a bug we fixed. If it happens again, the issue is in `zclaude-server.py`:
- Check that `test_endpoint` returns a `"note"` field when it gets "Not logged in"
- Check the system prompt has the rule about not retrying

### MySQL connection error on Tomcat start

```bash
# Check DB config
sudo grep 'DB_' /opt/tomcat9/webapps/zflow/WEB-INF/classes/cfg/ZFlowConfig.properties

# Test connection
mysql -u zdbuser -p'ZFlow2026pass' zflow -e 'SELECT 1;'
```

---

## 16. Credentials & Access

| Item | Value |
|------|-------|
| **Server SSH** | `ssh -i zflow.pem ubuntu@3.211.67.251` |
| **ZClaude UI** | https://zora.zmdm.net/zclaude |
| **ZFlow Login** | https://zora.zmdm.net/zflow/nui/login.jsp |
| **ZFlow Admin Email** | admin@zflow.io |
| **ZFlow Admin Password** | ZFlowAdmin2026! |
| **Health Check** | https://zora.zmdm.net/zflow/rest/zclaude/health |
| **MySQL User** | zdbuser |
| **MySQL Password** | ZFlow2026pass |
| **MySQL Database** | zflow (176 tables) |
| **Anthropic API Key** | In systemd service file (sk-ant-api03-AqSCZ2...) |
| **Anthropic Console** | https://console.anthropic.com |
| **EC2 Instance** | i-02882686850b260b0 (us-east-1) |
| **SSH Key File** | zflow.pem (Aditya's Downloads) |

---

## 17. Key Decisions & Why

| Decision | Why |
|----------|-----|
| **javac instead of Maven** | Customers don't have Maven. javac is available with any JDK. |
| **Separate zclaude.jar instead of classes/ dir** | JARs in WEB-INF/lib/ are automatically on the classpath. Clean separation from core code. |
| **Python for AI server instead of Java** | Faster to develop, Anthropic SDK works well in Python, independent of Tomcat (Tomcat restart doesn't kill the AI server). |
| **Flask instead of FastAPI** | Already installed in the server's venv. Simple, sufficient. |
| **Claude Sonnet instead of Opus** | Cheaper ($3 vs $15 per million tokens), fast enough for code generation, good at tool_use. |
| **System prompt with full CLAUDE.md** | Claude needs the complete API reference to write correct ZFlow code. The 8K+ token system prompt is worth it. |
| **run_build uses sudo** | build.sh needs to write to WEB-INF/lib/ (owned by root) and restart Tomcat. The systemd service runs as root. |
| **LegacyCookieProcessor in context.xml** | ZFlow sets cookie values with spaces. Tomcat 9's default RFC 6265 parser rejects them. |
| **conversation_history in memory** | Simple. Single-user demo system. For production, would need per-session storage. |
| **Max 10 tool iterations** | Prevents infinite loops if Claude gets confused (e.g., retrying failed auth). |

---

## Questions for KT Session

Use these to verify understanding:

1. Where does `zclaude.jar` end up after build.sh runs?
2. Why must controllers be in `com.zesati.controllers` package?
3. What happens if compilation fails — does it break the running app?
4. How many Claude API calls does a single user message typically trigger?
5. Where is the Anthropic API key stored?
6. What's the difference between Claude Pro and API credits?
7. If you update CLAUDE.md, what do you need to restart?
8. How would you add a 7th tool to the AI server?
