# Deployed Architecture — As-Built (for the demo)

This reflects what is actually running, not the aspirational design.

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                          SUPPLIER PORTAL  (ZFlow)                              ║
║                       https://supplychainnew.zflow.io                          ║
║                                                                                ║
║   PO Collaboration template — 14 activities:                                   ║
║   Start → PO Data Prep → Review PO by Supplier → Confirm PO                     ║
║      → Send PO JSON to Webmethods → Print Shipping Labels → Submit ASN          ║
║      → ★Send ASN to Webmethods → Notify Goods Receipt → Invoice                 ║
║      → ★Send Invoice to Webmethods → Approve Invoice → Payment Remittance → End ║
║                                                                                ║
║   ExtSystem: ZFlowAsWebMethods ──► https://training.zflow.io/training5          ║
╚══════════════════════════════════════════════════════════════════════════════╝
        │  ▲                                                │  ▲
        │  │ (1) create PO                    (2) ASN/Invoice│  │ (3) GR / Payment
        ▼  │                                            ▼    │  │
╔══════════════════════════════════════════════════════════════════════════════╗
║                    MIDDLEWARE  "WebMethods Impersonator"                        ║
║                     https://training.zflow.io/training5                         ║
║                                                                                ║
║   • /nui/middleware_juniper_po.jsp    SAP PO JSON ─► create PO on Portal        ║
║   • /nui/middleware_portal_event.jsp  Portal ASN/Invoice ─► BAPI to SAP         ║
║   • /nui/middleware_sap_event.jsp     SAP GR/Payment ─► update Portal PO        ║
║                                                                                ║
║   ExtSystems: Supplier_Portal_New ─► Portal · SAP_ERP_Mock ─► httpbin           ║
╚══════════════════════════════════════════════════════════════════════════════╝
        │  ▲
        ▼  │  (1) PO release  /  (2) inbound-delivery + invoice BAPI
╔══════════════════════════════════════════════════════════════════════════════╗
║         SAP (mock = https://training.zflow.io/training5/nui/mock_sap.jsp)       ║
║   reliable local mock; returns SAP-style ack + doc number.                      ║
║   swap SAP_ERP_Mock.BaseURL to real SAP REST/BAPI gateway for production.       ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

## Integration flows

| # | Flow | Path |
|---|---|---|
| 1 | PO release | SAP → `middleware_juniper_po.jsp` → Portal PO created |
| 2a | ASN | Portal `Send ASN to Webmethods` → `PushASNToWebMethods` → `middleware_portal_event.jsp` → SAP `BAPI_InboundDelivery` |
| 2b | Invoice | Portal `Send Invoice to Webmethods` → `PushInvoiceToWebMethods` → `middleware_portal_event.jsp` → SAP `BAPI_Invoice` |
| 3a | Goods Receipt | SAP → `middleware_sap_event.jsp` → Portal PO status updated |
| 3b | Payment | SAP → `middleware_sap_event.jsp` → Portal PO updated |

## Credentials (both instances)

`admin@zflow.io` / `zflow@12345`
