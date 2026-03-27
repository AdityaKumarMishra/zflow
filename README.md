# ZClaude Demo Script — Client Presentation

**Duration:** 15-20 minutes
**Presenter:** [Your Name]
**Audience:** Client team (technical + business)

---

## OPENING (2 minutes)

### What to say:

> "Today I want to show you something we've built that solves a problem every ZFlow customer faces.
>
> When you deploy ZFlow at a customer site, the customer always wants customizations — a custom API, a custom workflow function, a report endpoint. Today, to do that, they need:
>
> - Access to our full source code
> - Maven, JDK, an IDE
> - A Java developer
> - Rebuild the entire WAR file
> - Redeploy to Tomcat
>
> That's expensive, slow, and risky. Most customers can't do it.
>
> **ZClaude changes that completely.** The customer opens a browser, describes what they want in plain English, and the AI writes the code, compiles it, deploys it, and tests it — in under 60 seconds. No source code. No Maven. No Java developer needed."

---

## PART 1: THE PROBLEM (2 minutes)

### What to say:

> "Let me show you the traditional way first. Here's what a ZFlow deployment looks like on a customer server."

### What to show:

SSH into the server and show:

```
ssh -i "zflow.pem" ubuntu@3.211.67.251
```

```
ls /opt/tomcat9/webapps/zflow/WEB-INF/lib/
```

> "See these JAR files? This is a compiled application. There's `zbase-1.0.jar`, `zcustom-1.0.jar` — these are the core ZFlow modules. The customer has these JARs but NOT the source code. They can't modify anything.
>
> If they want to add, say, a REST API that returns overdue processes — traditionally they'd call us, we'd write the code, rebuild, and send them a new WAR file. That takes days or weeks."

---

## PART 2: THE SOLUTION — ZCLAUDE (3 minutes)

### What to say:

> "Now let me show you ZClaude. It lives inside the same deployed webapp."

### What to show:

```
ls /opt/tomcat9/webapps/zflow/WEB-INF/zclaude/
```

> "This is the extension directory. It has:
>
> - `src/` — where Java source files go
> - `build.sh` — a single script that compiles, packages, and deploys
> - `CLAUDE.md` — this is the secret sauce. It's a developer guide that teaches AI how to write ZFlow code."

Show the files:
```
find /opt/tomcat9/webapps/zflow/WEB-INF/zclaude/src -name "*.java"
```

> "These are Java files that customers have added. They compile into `zclaude.jar` which sits right alongside the core JARs. When Tomcat starts, Spring automatically discovers the new controllers, and the workflow engine discovers new functions. No configuration needed."

### What to say about the build:

> "The build process is dead simple. One script does everything:"

```
cat /opt/tomcat9/webapps/zflow/WEB-INF/zclaude/build.sh
```

> "It uses `javac` to compile against the existing JARs, packages everything into `zclaude.jar`, copies it to the `lib` folder, and restarts Tomcat. 30 seconds, start to finish."

---

## PART 3: THE AI INTERFACE (5 minutes)

### What to say:

> "But here's where it gets really powerful. The customer doesn't even need to know Java. They don't need to SSH into the server. They open a browser."

### What to show:

Open **https://zora.zmdm.net/zclaude** in the browser.

> "This is ZClaude. It's a chat interface — like ChatGPT, but specifically for building ZFlow extensions.
>
> On the left, you can see the extension files that are currently deployed.
>
> At the bottom, there's a text box. The customer just types what they want."

### LIVE DEMO — Type this:

> "Let me show you. I'll ask it to show me what's deployed."

Type: **"Show me what extensions are currently deployed and what each one does"**

Wait for response.

> "See what happened? The AI called `list_files` to check the directory, then `read_file` to look at the code, and gave us a summary. Those colored badges at the bottom show every action the AI took — full transparency."

### LIVE DEMO — Build something:

> "Now let's build something. I'll describe a real requirement."

Type: **"Add a REST endpoint called /rest/zclaude/server-info that returns the server time, Java version, database type, and how many users are in the system. No authentication required."**

Wait for response. Point out each step as it happens:

> "Watch what's happening:
>
> 1. **write_file** (green badge) — it wrote the Java code
> 2. **run_build** (yellow badge) — it compiled, packaged, and restarted Tomcat
> 3. **test_endpoint** (purple badge) — it tested the new endpoint
>
> And there's the result — the endpoint is live. Let me verify."

Open in a new browser tab: **https://zora.zmdm.net/zflow/rest/zclaude/server-info**

> "There it is. Working. JSON response. We went from English description to live API in about 30 seconds."

---

## PART 4: HOW IT WORKS BEHIND THE SCENES (3 minutes)

### What to say:

> "Let me explain what just happened technically. There are three layers."

> "**Layer 1: The AI Brain.**
> When the customer types a message, it goes to our Python server which calls the Claude API — that's Anthropic's AI. But we don't just send the message. We send it with a system prompt that contains our entire ZFlow SDK documentation — the `CLAUDE.md` file. This teaches Claude how ZFlow works: what's `DataService`, what's `BaseController`, how to use `ZSQL`, how workflow functions work. So Claude can write correct ZFlow Java code."

> "**Layer 2: The Tools.**
> Claude doesn't just generate text — it can call tools. We give it 6 tools:
>
> - `list_files` — see what exists
> - `read_file` — read existing code
> - `write_file` — create or update Java files
> - `delete_file` — remove files
> - `run_build` — compile and deploy
> - `test_endpoint` — verify it works
>
> Claude decides which tools to call and in what order. It's a loop — Claude calls a tool, gets the result, decides what to do next, calls another tool, and so on until the task is complete."

> "**Layer 3: The Build System.**
> The `run_build` tool executes `build.sh` on the server. This runs `javac` to compile the Java files against all 139 JARs in ZFlow's `WEB-INF/lib/`. The compiled classes get packaged into `zclaude.jar` and copied to the lib directory. Tomcat restarts, Spring scans the `com.zesati.controllers` package, finds the new `@RestController`, and registers the endpoints. The workflow engine can find new `ExternalFunctions` via `Class.forName()`. Everything is automatic."

---

## PART 5: WHAT CAN CUSTOMERS BUILD? (2 minutes)

### What to say:

> "Customers can build three types of extensions:"

> "**1. REST APIs** — new endpoints under `/rest/zclaude/`. For dashboards, integrations, reports, mobile apps. These are Spring controllers that have full access to ZFlow's data layer."

> "**2. Workflow Functions** — custom logic that runs during workflow activities. The customer assigns the function name in the workflow configuration, and ZFlow executes it automatically. For example: 'when a purchase order exceeds $50K, send a notification to the VP.'"

> "**3. Servlet Handlers** — for more complex request processing, custom pages, or integration with external systems."

> "All of these have access to the full ZFlow API — DataService for querying data, WorkFlowService for managing workflows, ZSQL for database queries, CollabService for process management. Everything documented in CLAUDE.md."

---

## PART 6: SAFETY AND SECURITY (1 minute)

### What to say:

> "A common concern: is this safe?
>
> - **It only adds code** — it never modifies core ZFlow files. The extension JAR is separate.
> - **If something breaks** — delete the bad Java file, run build.sh again, Tomcat restarts with clean code.
> - **Path traversal protection** — the server validates all file paths stay within the extension directory.
> - **Build isolation** — if compilation fails, the old JAR stays. No damage.
> - **The AI can only call our 6 tools** — it can't run arbitrary commands. It can write files, build, and test endpoints. That's it."

---

## PART 7: DEPLOYMENT AT A CUSTOMER SITE (1 minute)

### What to say:

> "To deploy this at a customer site, we need:
>
> 1. **Copy the `zclaude/` directory** into their ZFlow's `WEB-INF/` — that's the SDK with build.sh and CLAUDE.md
> 2. **Run the Python chat server** — a single Python file, needs Flask and the Anthropic SDK
> 3. **Configure nginx** — one location block to route `/zclaude` to the chat server
> 4. **Anthropic API key** — customer gets their own key at console.anthropic.com, costs about $0.01-0.03 per message
>
> That's it. No changes to ZFlow core. No build system. No source code access."

---

## PART 8: BUSINESS VALUE (1 minute)

### What to say:

> "Let me put this in business terms:
>
> - **Before:** Customer calls us → we write code → rebuild WAR → ship → they deploy. **Days to weeks.**
> - **After:** Customer opens browser → types what they want → it's live. **Under 60 seconds.**
>
> This means:
> - Faster time-to-value for customers
> - Fewer support tickets for us
> - Customers can self-serve for customizations
> - We can charge for the extension platform as an add-on
> - Differentiator vs competitors — no one else has AI-powered extension building"

---

## CLOSING (1 minute)

### What to say:

> "To summarize — ZClaude is three things:
>
> 1. **An extension SDK** — `build.sh` + `CLAUDE.md` + directory structure that lets you add Java code to a deployed ZFlow without source access
> 2. **An AI chat interface** — customers describe what they want in English, the AI writes the code
> 3. **An automated pipeline** — compile, package, deploy, test — all in one loop, all from the browser
>
> Any questions?"

---

## BACKUP: COMMON QUESTIONS

**Q: What if the AI writes bad code?**
> "If compilation fails, build.sh stops and shows the error. The old JAR stays. Nothing breaks. The AI sees the error and can fix it in the next message."

**Q: What if the customer wants something complex?**
> "The AI can handle multi-step requests. You can say 'add a workflow function that reads purchase order items, calculates the total, and updates the process attribute.' It understands ZFlow's data model because of CLAUDE.md."

**Q: What about performance? Does the AI slow down ZFlow?**
> "No. The AI only runs during development — when someone is in the chat building an extension. Once deployed, the extension is compiled Java running at native speed inside Tomcat. No AI involved at runtime."

**Q: How much does the Claude API cost?**
> "About $0.01-0.03 per message. A $5 credit balance lasts hundreds of conversations. The customer only pays when they're building extensions, not at runtime."

**Q: Can the customer break ZFlow with a bad extension?**
> "Worst case, a bad extension throws an error on its own endpoint. It doesn't affect core ZFlow functionality. And fixing it is easy — delete the file, rebuild, done."

**Q: Does this work with any ZFlow version?**
> "Yes. It compiles against whatever JARs are in the customer's WEB-INF/lib/. It adapts to their version automatically."

---

## DEMO URLS (Keep These Open)

| Tab | URL |
|---|---|
| ZClaude Chat | https://zora.zmdm.net/zclaude |
| ZFlow Login | https://zora.zmdm.net/zflow/nui/login.jsp |
| Health Check | https://zora.zmdm.net/zflow/rest/zclaude/health |
| Terminal (SSH) | `ssh -i zflow.pem ubuntu@3.211.67.251` |

## LOGIN CREDENTIALS

| Field | Value |
|---|---|
| ZFlow Admin | admin@zflow.io |
| Password | ZFlowAdmin2026! |
