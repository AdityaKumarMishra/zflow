---
title: "ZFlow PO Collaboration Workbench"
subtitle: "Multi-PO portfolio across Buyer, Supplier, and Purchasing Lead — Feature Showcase"
---

**Live URL:** `https://training.zflow.io/training5/po_collab_workbench.html`

**Built on:** ZFlow training5 (middleware) + supplychainnew (Supplier Portal)

**Status:** Working, deployed, and demo-ready

---

# What we built

A **multi-PO collaboration workbench** that surfaces the entire purchase-order portfolio across three roles — **Buyer**, **Supplier**, and **Purchasing Lead** — each with a tailored view of inbox, KPIs, and operational dashboards. Inspired by the design at `zflow26.zflow.io/zflow/nui/po_workbench_mock.html`, but built against our live workflow and data model so every number, status, and PO card is real Portal data.

It complements the existing **single-PO lifecycle workbench** (5-step demo) — clicking any PO card in the portfolio deep-links into the single-PO view so the audience can drill from "portfolio" to "individual PO lifecycle" in one click.

# The three personas

The header has a role toggle in the top-right. Each role changes the inbox content, KPI tiles, visible sections, and AI Assistant prompts.

## 1. Supplier (ACME Widgets — vendor 0040018193)

> **📷 SCREENSHOT 1 — Supplier role view:** Show header with Supplier toggle active, "Needs My Attention" with 4 POs (Review PO by Supplier), Quick Stats KPIs, and a few PO cards with the "Awaiting supplier action" yellow banner.

[Paste screenshot here]

\

\

\

\

**What the supplier sees:**

- **Needs My Attention** — POs awaiting their action: *Review PO by Supplier*, *Confirm PO*, *Print Shipping Labels*, *Submit ASN*, *Submit Invoice*.
- **Portfolio** — all POs sent to this supplier, sorted with inbox items first.
- **Per-PO action banner** — yellow callout on cards needing supplier input.
- **AI Assistant prompts** — *"Which POs do I need to confirm?"*, *"Any POs awaiting my shipment?"*, *"Which invoices have I not submitted yet?"*.

## 2. Buyer (Globex Procurement — org 2380)

> **📷 SCREENSHOT 2 — Buyer role view:** Show header with Buyer toggle active, "Acting as buyer Globex Procurement (org 2380)" pill, inbox showing "Nothing in your inbox — all clear" or any approval items, and portfolio cards.

[Paste screenshot here]

\

\

\

\

**What the buyer sees:**

- **Needs My Attention** — POs awaiting their action: *Approve Invoice*, plus change-request reviews when added in a future phase.
- **Portfolio** — all POs with this buying org, including drafts and completed.
- **Per-PO action banner** — purple callout on cards needing buyer input.
- **AI Assistant prompts** — *"Any invoices waiting for my approval?"*, *"Which POs stalled > 3 days?"*, *"Show late shipments by supplier"*.

## 3. Purchasing Lead (Priya Patel — managing all suppliers and buyers)

> **📷 SCREENSHOT 3 — Purchasing Lead view:** Show header with Purchasing Lead toggle active, "Acting as Priya Patel · managing all suppliers/buyers", Team Workload section visible in left rail, and the view tabs showing "⭐ Operations Dashboard" as available.

[Paste screenshot here]

\

\

\

\

**What the lead sees:**

- **Cross-portfolio inbox** — POs in either supplier or buyer queues, surfaced as one stream.
- **Team Workload section** — per-team-member PO counts and OTIF percentages.
- **⭐ Operations Dashboard tab** appears (hidden for the other two roles) — full KPI and exception view.
- **AI Assistant prompts** — *"How is the team performing this month?"*, *"Which suppliers are below 80% OTIF?"*, *"What's our average PO cycle time?"*.

# The Operations Dashboard (Purchasing Lead only)

> **📷 SCREENSHOT 4 — Operations Dashboard:** Show the 5 KPI tiles row at top, OTIF by Supplier bar chart, PO Status Mix horizontal stacked bar, and the Top Exceptions table.

[Paste screenshot here]

\

\

\

\

\

A dedicated view for the lead with five real-data KPIs at the top, two charts, and a stalled-PO triage table.

**KPI tiles (computed from live Portal data):**

| Tile | What it shows |
|------|---------------|
| **Open POs** | Count of POs not yet complete (excludes DRAFT) |
| **OTIF · 30-day rolling** | % of shipped/invoiced/complete POs delivered on time and in full |
| **Avg cycle (days)** | Average days from PO creation to completion (across completed POs) |
| **Open exceptions** | POs with no workflow update in 2+ days (stalled) |
| **Late shipments** | POs past their requested delivery date but not yet shipped |

**OTIF by Supplier chart** — horizontal bar chart, one row per supplier, colored green / yellow / red by OTIF tier:

- ≥ 90% green
- 75–89% yellow
- < 75% red

**PO Status Mix bar** — single horizontal stacked bar showing the breakdown across DRAFT / OPEN / CONFIRMED / SHIPPED / INVOICED / COMPLETE, with counts in each segment and a color-coded legend.

**Top Exceptions table** — stalled and late POs, sorted by age, color-coded by severity (yellow > 3 days, red > 7 days). Clicking any row deep-links to that PO's single-PO workbench.

# AI Assistant (demo)

> **📷 SCREENSHOT 5 — AI Assistant pane:** Show the purple-tinted card at the bottom of the main pane with the three suggested prompts visible (persona-aware), the input box with placeholder "Ask about your POs…", and an example expanded answer like "You have 0 POs awaiting confirmation right now."

[Paste screenshot here]

\

\

\

\

A persona-aware assistant at the bottom of the main pane that answers questions about the portfolio. Suggested prompts change with the active role. Answers are **computed from the live portfolio data** (not canned), so the numbers update as the portfolio changes.

Examples of working questions:

- *"Which suppliers are below 80% OTIF?"* → returns the actual list
- *"How many POs are stalled?"* → live count from the data
- *"What's our average cycle time?"* → computed across completed POs
- *"Late shipments by supplier?"* → grouped breakdown

# Portfolio view

> **📷 SCREENSHOT 6 — Portfolio view:** Show 4–5 PO cards in the main pane. Highlight the per-PO progress strip (5 segments: Ordered / Confirmed / Shipped / Invoiced / Received), the stage pill (DRAFT / OPEN / CONFIRMED / SHIPPED / INVOICED / COMPLETE), buyer→supplier arrow, metadata row, and the awaiting-action callout banner on inbox items.

[Paste screenshot here]

\

\

\

\

\

Every PO renders as a card with:

- **PO number** + **stage pill** (color-coded)
- **Buyer → Supplier** flow line
- **Current workflow activity** badge (right-aligned)
- **Metadata row** — created date, IncoTerms, payment terms, requested delivery date, COLL ID
- **5-segment progress strip** — fills as the PO moves through the lifecycle
- **Action callout** — yellow (supplier needed), purple (buyer needed), or green (complete)

**Filters at top of portfolio:** All stages dropdown · All suppliers dropdown — both update the card list, KPI counts, and inbox in real time.

# Recent Activity feed

> **📷 SCREENSHOT 7 — Recent Activity tab:** Show the portfolio-wide timeline with 6–10 entries, each colored by stage with PO number, current activity, buyer/supplier line, and date.

[Paste screenshot here]

\

\

\

\

A portfolio-wide event feed showing the most-recently-updated POs across the entire portfolio. Each row is colored by PO stage and shows the current workflow activity, parties, and last update date. Click any PO number to drill into its single-PO workbench.

# Click-through to single-PO workbench

Clicking any PO card (or any inbox item, exception row, or activity entry) opens the **single-PO lifecycle workbench** in a new tab with that PO auto-loaded. The single-PO view has its own tabs — Lifecycle, Lines, Activity — and shows the full 5-step buyer/supplier/SAP integration demo.

> **📷 SCREENSHOT 8 — Single-PO workbench (linked from a portfolio click):** Show the lifecycle steps with status badges, the polished summary card at top (status pill, progress strip, action banner), and the Lines tab showing real POLine data with ABC123 partNumber, OrderedQty/SupplierQty deltas, UnitPrice/SupplierPrice negotiation indicators.

[Paste screenshot here]

\

\

\

\

\

# What's real vs. what's simulated

We were explicit about not faking data anywhere we could avoid it. Here's the split:

**Real, live from Portal:**

- Stage, current workflow activity, role inbox bucketing
- Per-PO metadata: PONumber, Supplier, BuyerOrg, IncoTerms, payment terms, requested/supplier delivery dates, created/updated timestamps, COLL ID
- Per-line data via POLine: PartNumber, OrderedQty, SupplierQty, UnitPrice, SupplierPrice, UOM (visible on click-through)
- WebMethodsPayload (the canonical PO JSON the workflow constructs) — surfaced in the single-PO Step 2 SEND panel
- All KPI tile counts and percentages (Open POs, OTIF, Cycle, Exceptions, Late)
- OTIF by Supplier chart
- PO Status Mix
- Top Exceptions table (stalled and late POs, sorted by age)
- Activity feed (recent updates across the portfolio)
- AI Assistant answers (computed from real data)

**Simulated, for narrative clarity:**

- Persona display names (ACME Widgets, Globex Procurement, Priya Patel)
- Team Workload split across three names (Sarah / Marcus / Priya)
- Per-team-member OTIF percentages

**Deliberately skipped (and why):**

- Change Request workflow — requires the Portal `POChangeCollab` template, which Kris's team would need to build first
- Live LLM AI Assistant — computed-answer version honestly demonstrates the UX without an API key or budget conversation
- Supplier scorecards — no historical performance data to compute them from

# Performance characteristics

The portfolio JSP joins POCollab and Collaboration data from the Portal — two REST calls. We optimized so the demo is snappy:

- **Parallel Portal fetches** — POCollab and Collaboration run concurrently in two threads (was sequential)
- **60-second server-side cache** — repeated visits within a minute return instantly
- **30-second browser cache** — `Cache-Control: private, max-age=30` makes auto-refresh invisible within that window
- **12-second read timeout** — fails fast if the Portal hangs, instead of waiting 30s

Typical page load: **1–3 seconds on first visit**, **near-instant for the next minute**.

# Live URLs

**Multi-PO Collaboration Workbench:**
`https://training.zflow.io/training5/po_collab_workbench.html`

**Single-PO Lifecycle Workbench (deep-linkable):**
`https://training.zflow.io/training5/po_workbench.html?po=PO-DEMO-88198`

**Portfolio JSON API:**
`https://training.zflow.io/training5/nui/middleware_portfolio.jsp`

**Supplier Portal (back-end source of truth):**
`https://supplychainnew.zflow.io`

# Demo flow (suggested)

1. **Open the multi-PO workbench** — defaults to Supplier role with 4 POs in the inbox awaiting "Review PO by Supplier".
2. **Toggle through the three roles** in the top-right header to show each persona's view.
3. **Switch to Purchasing Lead** — the Operations Dashboard tab appears; click it to show KPIs, OTIF chart, and the exceptions table.
4. **Open the AI Assistant** at the bottom — click a suggested prompt or type a free-text question. Real data answer comes back.
5. **Click any PO card** — opens the single-PO lifecycle workbench in a new tab. Walk through the 5-step Buyer → Supplier → SAP integration demo.
6. **Toggle back to the multi-PO tab** to close the loop on the portfolio-level view.

---

*Built on ZFlow training5 + supplychainnew · live, no mock data in the dashboard · 29 POs across 3 suppliers (0040018193, TTM, WUS) and 1 buyer org (2380) at time of authoring.*
