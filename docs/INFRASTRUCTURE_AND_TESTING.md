# ZFlow PO Collaboration Middleware — Infrastructure, Working & Testing

Complete reference for the as-built POC. Covers (1) the infrastructure, (2) how it
works end to end, and (3) how to test it. Nothing here is aspirational — it's all deployed.

---

## 1. Infrastructure

Three logical systems, two real ZFlow instances + one mock SAP.

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║  SUPPLIER PORTAL  (ZFlow)                https://supplychainnew.zflow.io         ║
║  host 100.24.119.62 · Tomcat /opt/tomcat · webapp ROOT · DB "zflow"             ║
║  - PO Collaboration template: 14 activities (full lifecycle)                    ║
║  - Data classes: POCollab(+POLine), ASNCollab, InvoiceCollab, POChangeCollab    ║
║  - ExtSystem  ZFlowAsWebMethods ──► https://training.zflow.io/training5          ║
║  - RestApiFns SendPoJsonToZFlow, PushASNToWebMethods, PushInvoiceToWebMethods    ║
╚═══════════════════════════════════════════════════════════════════════════════╝
        │  ▲                                              │  ▲
        │  │ create PO                       ASN/Invoice  │  │ Goods Receipt / Payment
        ▼  │                                          ▼   │  │
╔═══════════════════════════════════════════════════════════════════════════════╗
║  MIDDLEWARE  "WebMethods Impersonator"    https://training.zflow.io/training5    ║
║  host 54.209.68.159 · Tomcat /usr/share/tomcat9 · webapp training5 · DB training5║
║  Integration endpoints (JSP):                                                   ║
║   • /nui/middleware_juniper_po.jsp     SAP PO JSON ─► create PO on Portal        ║
║   • /nui/middleware_portal_event.jsp   Portal ASN/Invoice ─► BAPI to SAP         ║
║   • /nui/middleware_sap_event.jsp      SAP GR/Payment ─► update Portal PO        ║
║  Demo console (browser):  /demo.html                                            ║
║  ExtSystems  Supplier_Portal_New ─► Portal · SAP_ERP_Mock ─► local SAP mock      ║
║  RestApiFns  PushPOToPortal, AdvancePortalActivity, BAPI_InboundDelivery,        ║
║              BAPI_Invoice                                                        ║
╚═══════════════════════════════════════════════════════════════════════════════╝
        │  ▲
        ▼  │  PO release / inbound-delivery + invoice BAPI
╔═══════════════════════════════════════════════════════════════════════════════╗
║  SAP (mock for POC)   https://training.zflow.io/training5/nui/mock_sap.jsp       ║
║  Reliable local mock — returns a SAP-style ACCEPTED ack + fake doc number.       ║
║  Swap SAP_ERP_Mock.BaseURL to the real SAP REST/BAPI gateway for production.     ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

**Access (both ZFlow instances):** `admin@zflow.io` / `zflow@12345`

---

## 2. How it works (end to end)

### The PO Collaboration template on the Portal (14 activities)
```
Start → PO Data Preparation → Review PO by Supplier → Confirm PO
  → Send PO JSON to Webmethods → Print Shipping Labels → Submit ASN
  → Send ASN to Webmethods → Notify Goods Receipt → Invoice
  → Send Invoice to Webmethods → Approve Invoice → Payment Remittance Advice → End
```

### The 5 integration flows

| # | Flow | Trigger | Path | What the middleware does |
|---|------|---------|------|--------------------------|
| 1 | **PO release** | SAP releases a PO | SAP → `middleware_juniper_po.jsp` → Portal | Transforms SAP's nested PO JSON, calls Portal `/rest/process/create/PO Collaboration` |
| 2a | **ASN** | Supplier submits ASN (Portal activity auto-fires) | Portal `Send ASN to Webmethods` → `PushASNToWebMethods` → `middleware_portal_event.jsp` → SAP | Maps to `BAPI_InboundDelivery`, POSTs to SAP |
| 2b | **Invoice** | Supplier submits invoice (auto-fires) | Portal `Send Invoice to Webmethods` → `PushInvoiceToWebMethods` → `middleware_portal_event.jsp` → SAP | Maps to `BAPI_Invoice`, POSTs to SAP |
| 3a | **Goods Receipt** | SAP confirms receipt | SAP → `middleware_sap_event.jsp` → Portal | Finds the PO on the Portal by PONumber, posts status update |
| 3b | **Payment** | SAP confirms payment | SAP → `middleware_sap_event.jsp` → Portal | Updates PO (POStatus=PAID, FinalResult=Completed) |

### Key principles
- **SAP ↔ Middleware hops are automatic** — SAP fires JSON on PO release / goods receipt; the middleware transforms and forwards.
- **The only human is the supplier** clicking in the Portal UI. Even their ASN/Invoice submissions trigger SAP calls automatically (the "Send to Webmethods" workflow activities).
- **ZFlow IS the bus** — no external WebMethods. The middleware instance plays the WebMethods role entirely with ZFlow's own REST + ExtSystem/RestApiFunction capabilities.

---

## 3. How to test

### Option A — Demo Console (easiest, no tools, all browser)

Open: **https://training.zflow.io/training5/demo.html**

Click ↻ New PO #, then the 4 buttons in order:
1. **SAP: Release PO** → expect SUCCESS + a `CollID` (e.g. POCOLL000xx)
2. **Supplier: Submit ASN** → expect SUCCESS + `"bapi":"BAPI_InboundDelivery"`
3. **Supplier: Submit Invoice** → expect SUCCESS + `"bapi":"BAPI_Invoice"`
4. **SAP: Confirm Goods Receipt** → expect SUCCESS + `resolvedProcessUID` populated

Each button shows the live response with a SUCCESS/ERROR badge.

### Option B — Postman (for technical audiences)

Import `examples/postman_collection.json`. Set the `poNumber` collection variable to a
fresh value, then run requests 1→5 in order. Same expected results as above.

### Option C — Browser, fully UI-driven (most "real")

1. **Trigger PO release:** use the Demo Console button 1 (or have SAP/Postman send it).
2. **Log into the Portal** (https://supplychainnew.zflow.io) → Process Templates →
   PO Collaboration → Processes → open your PO → **Graph View** shows the 14-step workflow.
3. **Drive the workflow:** open the current activity, complete it (Review → Confirm →
   Print Labels → Submit ASN). When the workflow reaches "Send ASN to Webmethods", it
   automatically calls the middleware → SAP — no manual step.
4. **Watch SAP receive it** (optional live view): see "Live SAP view" below.

### Live SAP view (optional, for a projector "wow")

By default SAP is mocked at a reliable local endpoint (`/nui/mock_sap.jsp` on the middleware),
which returns a SAP-style `ACCEPTED` ack + a fake SAP document number — visible in the Demo
Console response. For a live external dashboard view instead:
1. Open https://webhook.site → copy "Your unique URL"
2. Update `SAP_ERP_Mock.BaseURL` on the middleware to that URL
3. Keep a browser tab on webhook.site — ASN/Invoice messages appear there in real time.

### Verifying on the Portal after a run
- https://supplychainnew.zflow.io → Process Templates → PO Collaboration → **Processes** tab
- Your PO appears (named by PO number). Open it to see the workflow graph + status.

### Reset / clean run
Just use a fresh PO number for each full run (the Demo Console's ↻ button does this).
SAP enforces a unique PO number, so reusing one returns a "Duplicate entry" error.

---

## 4. What's deferred (not yet built)

Needs a small, coordinated metadata addition on the Portal's POCollab class:
- Confirm vs **Change PO** branching
- Buyer **Approve/Reject** loop-back
- **Quality** non-conformance sub-process

These were intentionally left out of the POC because they require adding fields
(`POAction`, `ChangeDecision`, quality fields) to the Portal's live metadata, which
should be coordinated with the ZFlow/client team to avoid conflicting with their work.

---

## 5. File index (this repo)

| File | Purpose |
|------|---------|
| `docs/INFRASTRUCTURE_AND_TESTING.md` | This document |
| `docs/DEMO_RUNBOOK.md` | Step-by-step demo script |
| `docs/ARCHITECTURE_DEPLOYED.md` | As-built architecture diagram |
| `examples/postman_collection.json` | Importable Postman demo collection |
| `scripts/demo_console.html` | Source of the browser demo console (deployed at training5/demo.html) |
| `scripts/middleware_juniper_po.jsp` | Middleware: SAP PO → Portal |
| `scripts/middleware_portal_event.jsp` | Middleware: Portal ASN/Invoice → SAP |
| `scripts/middleware_sap_event.jsp` | Middleware: SAP GR/Payment → Portal |
| `scripts/supplychainnew_baseline.txt` | Pre-change object baseline on the Portal |
