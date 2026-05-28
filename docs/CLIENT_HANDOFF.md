# ZFlow PO Collaboration Middleware — Solution Overview & Demo Guide

**Status: Working end-to-end (proof of concept). Ready to demo.**

This document is for everyone — a business summary up top, the architecture and how it
works in the middle, and a hands-on testing section at the end for the technical team.

---

## Executive Summary

We have stood up a working proof of concept in which **ZFlow replaces WebMethods** as the
integration layer between **SAP** and the **Supplier Portal**. A purchase order now flows
automatically from SAP into the Supplier Portal, the supplier confirms and fulfils it, and
every downstream event (shipping notice, invoice, goods receipt, payment) is exchanged with
SAP automatically — with no manual re-keying and no separate middleware product to license.

**What this proves:**
- ZFlow can act as the integration bus ("WebMethods role") using its own REST capabilities.
- The full purchase-order collaboration lifecycle runs on the Supplier Portal.
- Both directions work: SAP → Portal (PO release, goods receipt) and Portal → SAP (ASN, invoice).

**Business value:**
- One less platform to license and maintain (no external WebMethods).
- Real-time, automated supplier collaboration on top of SAP.
- An AI-native platform (ZFlow) carrying the integration, with room to add intelligent automation.

---

## Architecture

Three systems. SAP and the Portal talk to each other automatically through the ZFlow
integration layer in the middle.

```
┌───────────────────────────────────────────────────────────────────────────┐
│  SUPPLIER PORTAL  (ZFlow)                  supplychainnew.zflow.io           │
│  • PO Collaboration workflow — full supplier + buyer lifecycle (14 steps)   │
│  • Where suppliers log in to confirm POs, ship (ASN), and invoice           │
└───────────────────────────────────────────────────────────────────────────┘
            │  ▲                                          │  ▲
            │  │  create PO                  ASN / Invoice│  │  Goods Receipt / Payment
            ▼  │                                      ▼   │  │
┌───────────────────────────────────────────────────────────────────────────┐
│  ZFLOW INTEGRATION LAYER  (WebMethods replacement)                          │
│  training.zflow.io/training5                                                │
│  • Receives PO releases from SAP and creates the collaboration on the Portal│
│  • Translates supplier ASN/invoice events into SAP messages                 │
│  • Relays SAP goods-receipt / payment events back to the Portal             │
└───────────────────────────────────────────────────────────────────────────┘
            │  ▲
            ▼  │  PO release  /  inbound-delivery + invoice
┌───────────────────────────────────────────────────────────────────────────┐
│  SAP (ERP)                                                                  │
│  • Mocked for the POC; switches to the real SAP gateway with one setting    │
└───────────────────────────────────────────────────────────────────────────┘
```

---

## How it works — the purchase-order lifecycle

### The workflow on the Supplier Portal (14 steps)
```
Start → PO Data Preparation → Review PO by Supplier → Confirm PO → (notify SAP)
  → Print Shipping Labels → Submit ASN → (notify SAP) → Notify Goods Receipt
  → Invoice → (notify SAP) → Approve Invoice → Payment Remittance Advice → End
```

### The five integration points

| # | Event | Direction | What happens |
|---|-------|-----------|--------------|
| 1 | **PO released** | SAP → Portal | SAP sends the PO; the integration layer creates a PO Collaboration on the Portal, visible to the supplier. |
| 2 | **ASN submitted** | Portal → SAP | Supplier submits the Advance Shipping Notice; the integration layer sends an inbound-delivery message to SAP. |
| 3 | **Invoice submitted** | Portal → SAP | Supplier invoices; the integration layer sends a vendor invoice to SAP accounts-payable. |
| 4 | **Goods receipt** | SAP → Portal | SAP records goods received; the integration layer updates the supplier's PO status on the Portal. |
| 5 | **Payment** | SAP → Portal | SAP confirms payment; the integration layer updates the PO on the Portal. |

### Key principle
- **SAP and the Portal never talk directly** — every exchange goes through the ZFlow
  integration layer, which translates the formats both ways.
- **The only person in the loop is the supplier**, working in their browser. SAP-side
  events and the supplier's submissions trigger the cross-system messages automatically.

---

## What's proven (verified end-to-end)

| Step | Result |
|------|--------|
| SAP releases PO → created on Portal | ✅ PO appears with the full 14-step workflow |
| Supplier submits ASN → sent to SAP | ✅ SAP acknowledges with a document number |
| Supplier submits invoice → sent to SAP | ✅ SAP acknowledges with a document number |
| SAP confirms goods receipt → Portal updated | ✅ PO status updated on the Portal |

---

## How to test / demo it

There are three ways to run the demo, from easiest to most realistic.

### Option A — Live Demo Console (easiest, browser only, no tools)

Open **https://training.zflow.io/training5/demo.html**

Click **↻ New PO #**, then the four buttons in order. Each shows the live response with a
SUCCESS / ERROR badge:

1. **SAP: Release PO** → a new PO is created on the Portal (returns a PO ID)
2. **Supplier: Submit ASN** → sent to SAP (returns a SAP document number)
3. **Supplier: Submit Invoice** → sent to SAP (returns a SAP document number)
4. **SAP: Confirm Goods Receipt** → the PO is updated on the Portal

> Tip: use a fresh PO number for each full run (the ↻ button does this). Reusing a number
> returns a "duplicate" message — that's expected, not an error in the system.

### Option B — Postman (for the technical team)

Import `examples/postman_collection.json`, set the `poNumber` variable to a fresh value,
and run the requests in order. Same expected results as Option A.

### Option C — Browser, fully UI-driven (most realistic)

1. Trigger a PO release (Demo Console button 1).
2. Log in to the Supplier Portal and open the PO → the workflow graph shows all 14 steps.
3. Work the PO as a supplier would (Review → Confirm → Print Labels → Submit ASN). When the
   workflow reaches the "send to SAP" step, it calls SAP automatically — no manual action.
4. (Optional) For a live view of SAP receiving the messages, we can point the SAP mock at a
   visual dashboard so the audience sees each message arrive in real time.

### After a run — verify on the Portal
Supplier Portal → Process Templates → **PO Collaboration** → **Processes** tab → open your
PO to see the workflow and status.

---

## Planned enhancements (next phase)

The POC covers the straight-through "happy path." The following are designed and ready to
add in a coordinated next step with the ZFlow team:

- **Confirm vs. Change PO** branching (supplier proposes changes; buyer approves or rejects)
- **Buyer approval loop** for proposed changes
- **Quality / non-conformance** sub-process on goods receipt
- **Real SAP connection** — the SAP side is currently mocked; connecting the live SAP
  REST/BAPI gateway is a configuration change, with no workflow rebuild required.

---

## Access & support

- **Supplier Portal:** https://supplychainnew.zflow.io
- **Integration layer:** https://training.zflow.io/training5
- **Demo console:** https://training.zflow.io/training5/demo.html
- **Login:** admin credentials (shared separately / your existing ZFlow admin login)

For a guided walkthrough or to connect the live SAP gateway, contact the implementation team.
