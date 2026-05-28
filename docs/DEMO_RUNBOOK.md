# PO Collaboration Middleware — Client Demo Runbook

**Read this top to bottom. It assumes zero prior knowledge.**
Everything below has been tested and works as of the last build.

---

## 1. The story you're telling (30-second pitch)

> "ZFlow replaces WebMethods as the integration layer between SAP and our Supplier Portal.
> When SAP releases a Purchase Order, it flows automatically into the Supplier Portal where
> the supplier confirms it, ships goods (ASN), and invoices — and every one of those events
> flows back to SAP automatically. No manual re-keying, no middleware licenses. ZFlow IS the bus."

Three systems, talking to each other automatically:

```
   SAP (ERP)  ◄──►  ZFlow Middleware (WebMethods role)  ◄──►  ZFlow Supplier Portal
   httpbin mock      training.zflow.io/training5             supplychainnew.zflow.io
```

---

## 2. Before the demo — open these 4 tabs

| Tab | URL | Login |
|---|---|---|
| **A. Supplier Portal** | https://supplychainnew.zflow.io | `admin@zflow.io` / `zflow@12345` |
| **B. Middleware** | https://training.zflow.io/training5 | `admin@zflow.io` / `zflow@12345` |
| **C. Postman** | (desktop app) | import the collection — see §3 |
| **D. SAP mock viewer** | https://httpbin.org | (no login; this just echoes calls) |

> **Tip:** Log into Tab A and Tab B *before* the client joins, so you're not typing passwords on screen.

---

## 3. Postman setup (5 minutes, once)

1. Open Postman → **Import** → select `examples/postman_collection.json` from this repo.
2. You'll get a collection **"ZFlow PO Collaboration Demo"** with 4 ready requests:
   - `1. SAP releases PO → create on Portal`
   - `2. Supplier submits ASN → SAP`
   - `3. Supplier submits Invoice → SAP`
   - `4. SAP confirms Goods Receipt → Portal`
3. Each request already has the URL, headers, and body filled in.
4. **Before each run, change the PO number** in the body (there's a `{{poNumber}}` variable — set it once in the collection variables to something fresh like `PO-DEMO-001`, `PO-DEMO-002`...).

---

## 4. The demo — step by step

### Opening (show the architecture)
Show the diagram in `docs/ARCHITECTURE_DEPLOYED.md` (or the one in this runbook §1). Say:
> "Left is SAP. Middle is ZFlow acting as WebMethods — the integration bus. Right is the
> ZFlow Supplier Portal the suppliers log into. Watch a PO travel the whole loop."

---

### STEP 1 — SAP releases a PO (inbound)

**Do:** In Postman, run request **`1. SAP releases PO → create on Portal`**.
(Set the body's `purchaseOrderNumber` to something fresh, e.g. `PO-DEMO-101`.)

**Say:**
> "This is exactly the JSON SAP/Juniper sends — the real nested purchaseOrder format with header,
> line items and schedules. It hits our middleware, which creates a PO Collaboration in the Portal."

**Show:** The Postman response — point out:
- `"upstreamStatus": 200`
- `CollID` like `POCOLL000xx`
- `PONumber` matches what you sent

**Then switch to Tab A (Portal):** Administration → Process Templates → **PO Collaboration** → **Processes** tab. Your new PO appears. Open it → **Graph View** to show the **14-step workflow**:
> "The supplier now sees this PO with the full lifecycle — confirm, ship, invoice, get paid."

---

### STEP 2 — Supplier confirms & ships (ASN goes to SAP)

**Option A (visual, in the Portal UI):** In Tab A, open the PO, advance the activities
(PO Data Prep → Review → Confirm PO → Print Shipping Labels → Submit ASN). When it reaches
**"Send ASN to Webmethods"**, the middleware automatically pushes the ASN to SAP.

**Option B (scripted, guaranteed):** In Postman run **`2. Supplier submits ASN → SAP`**
(same PO number). This simulates the supplier's ASN action.

**Say:**
> "When the supplier submits the Advance Shipping Notice, ZFlow translates it and pushes an
> inbound-delivery message to SAP — automatically."

**Show:** The Postman response — point out `"bapi": "BAPI_InboundDelivery"` and the
`upstreamBody` echoing the exact payload SAP received (poNumber, asnNumber, supplierID, shipDate).

---

### STEP 3 — Supplier invoices (invoice goes to SAP)

**Do:** In Postman run **`3. Supplier submits Invoice → SAP`** (same PO number).

**Say:**
> "Same pattern for the invoice — supplier submits it on the Portal, ZFlow pushes it to SAP's
> accounts-payable as a vendor invoice. No manual entry."

**Show:** Response shows `"bapi": "BAPI_Invoice"` and the invoice payload SAP received.

---

### STEP 4 — SAP confirms Goods Receipt (inbound back to Portal)

**Do:** In Postman run **`4. SAP confirms Goods Receipt → Portal`** (same PO number).

**Say:**
> "And it works both ways. When SAP records goods received, ZFlow updates the supplier's PO
> on the Portal so the supplier sees real-time status — without anyone logging into SAP."

**Show:** Response shows `"resolvedProcessUID"` (the middleware found the right PO on the Portal)
and `"upstreamStatus": 200`. Switch to Tab A, refresh the PO — the status/comments reflect the receipt.

---

### Closing

> "That's the full purchase-order lifecycle — SAP to supplier and back — running through ZFlow
> as the integration bus. Every hop you saw was automatic JSON-over-REST. Replacing WebMethods
> with ZFlow means one less platform to license and maintain, and AI-native orchestration on top."

---

## 5. What success looks like (so you know it's working)

| Step | Expected |
|---|---|
| 1 | Postman 200 + `CollID` returned; PO visible in Portal Processes tab with 14-step graph |
| 2 | Postman 200 + `"bapi":"BAPI_InboundDelivery"` + echoed ASN payload |
| 3 | Postman 200 + `"bapi":"BAPI_Invoice"` + echoed invoice payload |
| 4 | Postman 200 + `"resolvedProcessUID"` populated + `"upstreamStatus":200` |

---

## 6. If something goes wrong (live troubleshooting)

| Symptom | Fix |
|---|---|
| Step 1 returns `Duplicate entry` | You reused a PO number. Change `purchaseOrderNumber` to a new value and re-run. |
| Step 4 returns `no_matching_pocoll` | The PONumber in step 4 doesn't match one you created in step 1. Use the same number. |
| Any request times out | Re-run it once; the cloud instances occasionally cold-start. |
| Portal page won't load | Refresh; if still failing, the Tomcat may be reloading — wait 30s. |
| You need a clean slate | Just use a brand-new PO number for the whole run. |

---

## 7. Reference — what's deployed (for technical questions)

**Middleware (training.zflow.io/training5):** 3 endpoints
- `/nui/middleware_juniper_po.jsp` — SAP PO → create on Portal
- `/nui/middleware_portal_event.jsp` — Portal ASN/Invoice → SAP
- `/nui/middleware_sap_event.jsp` — SAP GR/Payment → Portal
- ExtSystems: `Supplier_Portal_New`, `SAP_ERP_Mock` · RestApiFns: PushPOToPortal, BAPI_InboundDelivery, BAPI_Invoice, AdvancePortalActivity

**Portal (supplychainnew.zflow.io):** PO Collaboration template, 14 activities
- ExtSystem `ZFlowAsWebMethods` → training5 · RestApiFns: SendPoJsonToZFlow, PushASNToWebMethods, PushInvoiceToWebMethods

**SAP:** mocked locally at `https://training.zflow.io/training5/nui/mock_sap.jsp` (reliable; returns SAP-style ack + doc number). Swap `SAP_ERP_Mock.BaseURL` to real SAP for production.

**Not yet built (mention only if asked):** Confirm/Change branching, Quality non-conformance
sub-process — deferred pending a small metadata addition on the Portal, to be coordinated with the ZFlow team.
