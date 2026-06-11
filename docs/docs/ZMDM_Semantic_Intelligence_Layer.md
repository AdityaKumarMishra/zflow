---
title: "ZMDM Semantic Intelligence Layer (§129)"
subtitle: "Graph Model Implementation — Current State & Architecture"
---

# Executive Summary

The ZMDM Semantic Intelligence Layer turns master data (suppliers, parts, plants, lanes) into a **machine-reasonable knowledge graph** that humans, LLMs, AI agents, and planning systems can all query and reason over. This document describes the current L2-α implementation of the graph model — the foundation that powers everything above it.

**Status:** L2-α (foundation) is built and ready to deploy. Tables, harvester, and browser UI are in place. Higher-level capabilities (LLM grounding, risk reasoning, MCP exposure) are deferred to later phases per the §129 spec.

---

# 1. Architecture — Three Layers

The system follows the §129 three-layer model:

| Layer | What it does | Status |
|---|---|---|
| **L1 — Master Data** | Golden records, survivorship, hierarchies across product, supplier, plant, location domains. | Already exists in ZFlow. No new work. |
| **L2 — Semantics (Knowledge Graph + Ontology)** | Typed nodes + typed directional edges with shared meaning. Projected continuously from L1. | **L2-α implemented (this document).** L2-β/γ deferred. |
| **L3 — Reasoning** | Risk detection, impact analysis, next-best-action over the graph. | Deferred. Requires L2-α + L2-β complete first. |

The key insight from §129: **don't move nodes — project edges.** L1 entities stay in their original tables. The semantic layer is purely an *edge projection* layered on top.

---

# 2. Core Design Choice — Edges as Rows in MySQL

Rather than introducing a separate graph database (Neo4j, Memgraph, Neptune) in v1, the implementation stores edges as **rows in two MySQL tables**:

- Native to ZFlow's existing ZSQL + CollabMeta infrastructure
- Lineage trivially queryable via standard SQL joins
- No new infrastructure for the customer to install
- MySQL 8 recursive CTEs cover ~95% of supply-chain traversal questions (2–4 hops)
- If 6+ hop algorithms (PageRank-style centrality, community detection) become must-haves later, the same GraphEdge table is the cleanest possible export into Neo4j as a read replica — much smaller change than rebuilding L2 from scratch.

---

# 3. The Two Tables

## Table 1 — `OntologyType` (the predicate catalog)

One row per *type* of edge. Defines what edges can exist and what they mean.

**Schema:**

| Column | Type | Purpose |
|---|---|---|
| UniqueID | varchar(128) PK | Unique identifier |
| Name | varchar(64) UNIQUE | Edge type name (e.g., `SOURCES`) |
| FromType | varchar(64) | Source entity class (e.g., `Supplier`) |
| ToType | varchar(64) | Target entity class (e.g., `PartLog`) |
| PropertySchema | TEXT (JSON) | Allowed properties on this edge type |
| Description | varchar(500) | Human-readable explanation |
| Kind | varchar(32) | Edge / Node / etc. |
| Creator, CreDate, CurDb, LastUpdate, UpdatedBy | (audit) | Standard ZFlow audit columns |

**Seeded edge types (L2-α):**

| Edge Type | From → To | Properties | Meaning |
|---|---|---|---|
| **SOURCES** | Supplier → PartLog | allocationPercentage, leadTimeInDays, costPerUOM, primary, moq, status | Supplier sources a Part |
| **CONTAINS** | PartVer → PartLog | qty, qtyUOM, sequenceNumber, usageType, inBaseline | BOM relationship |
| **MAKES** | Manufacturer → PartLog | allocationPercentage, leadTimeInDays, costPerUOM, primary, status, manuPartNo | Manufacturer produces a Part |
| **SUBSTITUTE_FOR** | PartLog → PartLog | validFrom, validTo | Approved substitute |

These four are the foundation; additional edge types (e.g., `CONSUMED_AT`, `SHIPPED_VIA`, `HAS_LINE`) can be added in L2-β simply by inserting new `OntologyType` rows — no schema changes needed.

## Table 2 — `GraphEdge` (the actual edges)

One row per edge instance. Heavily indexed for fast bidirectional traversal.

**Schema:**

| Column | Type | Purpose |
|---|---|---|
| UniqueID | varchar(128) PK | Deterministic edge identifier |
| EdgeType | varchar(64) | References `OntologyType.Name` |
| FromCls + FromID + FromDB | varchar | Source node (typed reference) |
| ToCls + ToID + ToDB | varchar | Target node (typed reference) |
| Properties | TEXT (JSON) | Edge attributes, per `PropertySchema` |
| EvidenceKind | varchar(32) | Source category (`metamodel`, `workflow`, `ai`) |
| EvidenceUID | varchar(128) | Source row UID — **full lineage back to L1** |
| Confidence | DECIMAL(5,4) | 1.0 = certain (metamodel); < 1.0 = AI-inferred |
| ValidFrom / ValidTo | datetime | Temporal validity window (bi-temporal-ready) |
| LastVerified | datetime | When the edge was last reconfirmed |
| (Audit columns) | | Standard ZFlow audit fields |

**Indexes:**

- `(FromCls, FromID)` → traverse forward (e.g., "what does this Supplier source?")
- `(ToCls, ToID)` → traverse backward (e.g., "who sources this Part?")
- `(EdgeType)` → filter by relationship type
- `(EvidenceKind, EvidenceUID)` → lineage queries ("show all edges derived from this source row")

These four indexes together cover every common query pattern in 2–4 hops without table scans.

---

# 4. The Harvester (Metamodel-Implicit)

The harvester scans existing ZFlow relationship tables and *projects* each row as a `GraphEdge`. This is the core mechanism that turns master data into a graph **automatically and continuously** — no manual edge maintenance.

**Mapping (current L2-α):**

| Source Table | → Projected Edge | Properties Extracted |
|---|---|---|
| `SuppToPart` | SOURCES | AllocationPercentage, LeadTimeInDays, CostPerUOM, PrimaryMPN, MOQ, MPNStatus, MPNLifecycleStage |
| `PartToPart` | CONTAINS | Qty, QtyUOM, SequenceNumber, UsageType, InBaseline |
| `ManuToPart` | MAKES | AllocationPercentage, MPNLeadTime, MPNCostPerUOM, PrimaryMPN, MPNStatus, ManuPartNo |
| `PartToSubs` | SUBSTITUTE_FOR | SubEffectiveFrom, SubEffectiveTo |

**Key properties:**

1. **Idempotent** — Every projected edge has a deterministic UID:  
   `uid:l2:Edge:{EdgeType}:{source-row-UID}`  
   Combined with `INSERT IGNORE`, the harvester can be re-run safely at any time without creating duplicates.

2. **Lineage preserved** — Every `GraphEdge` row stores the originating L1 source row in `EvidenceUID`. When master-data stewards correct or enrich data, the harvester re-runs and the semantic layer updates automatically. There is no drift between "the data" and "the model of the data."

3. **Full property capture** — Edge `Properties` JSON captures the full business attributes from the source row (lead time, cost, allocation %, etc.) — so reasoning algorithms have everything they need without joining back to L1 tables.

---

# 5. Implementation Artifacts

The current implementation lives in these files (all JSPs, deployable to a ZFlow customer install):

| File | Size | Purpose |
|---|---|---|
| `graph_setup.jsp` | 6.7 KB | Creates `OntologyType` + `GraphEdge` tables and seeds the 4 edge types. Idempotent. |
| `graph_harvest.jsp` | 11.6 KB | Metamodel-implicit harvester. Scans the 4 relationship tables and projects all edges. |
| `graph_browser.jsp` | 57.6 KB | Interactive UI for browsing entities, traversing edges, and visualizing the graph. |
| `graph_demo.jsp` | 10.5 KB | Demo entry point with sample traversals. |
| `project_edge.jsp` | 6.4 KB | Foundation for L2-β workflow-derived edges (e.g., creating an edge from a PO Collaboration activity). |
| `seed_mdm_l0.jsp` | 28.8 KB | L1 master-data seed — bootstraps Supplier / Part / Manufacturer records for demo. |
| `add_ontology_l2b.jsp` | 2.3 KB | Extends the ontology catalog for L2-β phase. |
| `mdm_recon.jsp`, `mdm_schema_recon.jsp`, `fk_recon.jsp` | (small) | Pre-flight checks: confirms schema state before harvesting. |

**Security boundary:** All write JSPs (setup, harvest, projection) are localhost-gated. They check `request.getRemoteAddr()` and only accept requests from `127.0.0.1` / `::1`. This means they must be triggered via SSH-then-curl-localhost — they cannot be invoked from the public internet even if the URL is known.

---

# 6. What an Operator Sees

When the operator runs the harvester (`graph_harvest.jsp`), the output looks like this:

```
# L2-alpha harvest — training5
started: 2026/06/11 11:30:00

SOURCES        (SuppToPart):  +124
CONTAINS       (PartToPart):  +387
MAKES          (ManuToPart):  +89
SUBSTITUTE_FOR (PartToSubs):  +42

COMMITTED.

## Verify
  GraphEdge total: 642 rows

## Edges by type
  CONTAINS         387
  MAKES            89
  SOURCES          124
  SUBSTITUTE_FOR   42

## Sample edges (3 of each type)
--- SOURCES ---
  Supplier(uid:..acme0042) -> PartLog(uid:..mat10042)
    {"allocationPercentage":60.0,"leadTimeInDays":42,"costPerUOM":12.50,"primary":"+","moq":1000,"status":"Active"}
  ...
```

Numbers depend on actual L1 data volume; structure is the same regardless.

---

# 7. Design Decisions vs §129 Spec

The implementation aligns with the §129 spec on every key decision:

| §129 Decision Point | Implementation Choice | Rationale |
|---|---|---|
| Graph storage | MySQL rows (no Neo4j v1) | Native to ZFlow, no new infra |
| Node movement | None — L1 untouched | Avoids drift, preserves source-of-truth |
| Lineage tracking | Every edge → source row | Compliance + automatic refresh on L1 changes |
| Idempotency | Deterministic UID + INSERT IGNORE | Safe to re-run anytime |
| Confidence model | Default 1.0 for metamodel | Future AI-extracted edges will use < 1.0 |
| Bi-temporal columns | Present but unused in v1 | §129 explicitly says LastVerified is enough for v1 |
| Property schema | Free-form JSON | §129 open question — defaulted per spec recommendation |
| Multi-tenancy | Global (matches L1) | §129 open question — defaulted per spec recommendation |
| Security | Localhost-gated writes | Standard pattern for admin-only operations |

---

# 8. What's Built vs What's Deferred

## Built (L2-α — foundation)

- ✅ `OntologyType` and `GraphEdge` tables with all required columns and indexes
- ✅ Ontology catalog seeded with 4 core edge types
- ✅ Metamodel-implicit harvester — projects 4 relationship tables as edges
- ✅ Idempotent re-projection (safe to re-run)
- ✅ Full lineage back to L1 source rows
- ✅ Browser UI for graph exploration and traversal
- ✅ Pre-flight reconnaissance JSPs (schema/data checks)
- ✅ L1 seed data for end-to-end demo

## Deferred to Later Phases

| Phase | Capability | Why deferred |
|---|---|---|
| **L2-β** | `ProjectEdge` SpecialFunction wired into workflows (e.g., PO Confirmation creates a SUPPLIED_BY edge automatically) | Needs L2-α tables in place + workflow design decisions |
| **L2-γ** | LLM-based EdgeExtractor (reads contracts/PDFs, proposes edges with confidence < 1.0); NodeEmbedding for similarity matching ("find substitutes") | Needs AgentRuntime + DocumentEmbeddingService integration |
| **L3** | Concentration risk algorithm; lane fragility; impact analysis via recursive CTEs; MDMReasonerAgent | Needs L2-α + L2-β edges populated |
| **MCP / API surface** | `/rest/system/graph` Spring controller with `@AgentTool` annotations for LLM tool-calling | Needs Java service layer (not JSP) |
| **Kafka event stream** | Edge change events on `zmdm.graph.events` topic | Needs Kafka producer code (Kafka jar is present) |

These phases build on top of L2-α — no rework, just additions.

---

# 9. How a Consuming System Uses the Graph

Once L2-α is deployed and the harvester has projected edges, any consuming system can answer questions like:

- *"What suppliers source Part MAT-10042?"* → query `GraphEdge WHERE EdgeType='SOURCES' AND ToCls='PartLog' AND ToID='MAT-10042'`
- *"What is the BOM for SKU-88210?"* → recursive CTE walking `CONTAINS` edges
- *"What's at risk if Supplier ACME is disrupted?"* → forward traversal from `Supplier(ACME)` through `SOURCES` → `CONTAINS` → `CONSUMED_AT` → `PRODUCES` → `SHIPPED_VIA`
- *"Show all single-source dependencies"* → aggregate by `(ToCls, ToID)` HAVING COUNT(DISTINCT FromID) < 2 on `SOURCES` edges
- *"Who manufactures Part X and what are alternates?"* → query `MAKES` edges + `SUBSTITUTE_FOR` edges from the same target

The same graph powers humans (browser UI), planning systems (REST API), LLM assistants (MCP tools), and event-driven workflows (Kafka).

---

# 10. Path to Customer Deployment

A customer installation of the semantic layer requires:

1. **Deploy the JSP files** to the customer's ZFlow webapp (in a persistent folder so they survive system updates).
2. **Run `graph_setup.jsp` once** (localhost) — creates tables and seeds ontology. Idempotent.
3. **Run `graph_harvest.jsp` once** (localhost) — populates initial edges from existing L1 master data.
4. **Schedule the harvester** to re-run on a chosen cadence (e.g., nightly) or wire it to L1 change events for near-real-time refresh.
5. **Optionally deploy `graph_browser.jsp`** to give business users a visual graph explorer.

Total customer-side install time: under 30 minutes for the foundation. Subsequent phases (LLM grounding, risk algorithms, MCP API) layer on top without disturbing what's already there.

---

# 11. Summary

The semantic intelligence layer's foundation is built and matches the §129 specification. The two-table, edge-as-row design gives a customer the full value of a knowledge graph (typed relationships, queryable lineage, automatic refresh) without the operational burden of a separate graph database. Every higher-level capability — LLM grounding, risk reasoning, MCP tool exposure, Kafka events — can be added on top without rework.

The customer gets a real, queryable knowledge graph from their existing governed master data on day one, with a clear roadmap for incremental intelligence as later phases ship.
