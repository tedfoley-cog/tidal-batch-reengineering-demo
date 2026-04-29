# Implementation Plan — Tidal Batch Job Reengineering Demo

## 1. What the Demo Proves

An enterprise's Tidal Workload Automation server is a black box of interconnected batch jobs spanning COBOL programs, JCL scripts, shell scripts, and stored procedures. Nobody fully understands the dependency chains, failure modes, or business purpose of each job. Devin can reverse-engineer the entire job landscape from raw Tidal export files, trace failure root causes, generate comprehensive documentation, and produce an interactive dependency dashboard — all end-to-end in a single live session.

## 2. What Devin Does Live

Devin analyzes the Tidal job definitions, reverse-engineers the COBOL/JCL, maps the full dependency graph, identifies failure root causes, tags each job with metadata, and generates an interactive HTML dashboard with dependency visualization and documentation cards.

## 3. Stack and Rationale

| Component | Technology | Source / Citation |
|---|---|---|
| Job definition format | Tidal/TES XML with `tes:` namespace | [Cisco TES 6.2 REST API Reference Guide — Job chapter](https://www.cisco.com/c/en/us/td/docs/net_mgmt/datacenter_mgmt/Tidal_Enterprise_Scheduler/6-2/rest_api_reference/guide/Cisco_TES_6-2_REST_API_Reference_Guide/Job.html) |
| XML namespace | `http://www.tidalsoftware.com/client/teservlet` | Same as above — all API examples use this namespace |
| Job types | `OSJob`, `JobGroup`, `FTPJob`, `ServiceJob` | TES 6.2 REST API — Job Type section |
| COBOL programs | COBOL-85, column-based (cols 7-72) | Prior demo: `tedfoley-cog/cobol-ims-demo` |
| JCL scripts | MVS JCL with DD statements | Prior demo: `tedfoley-cog/cobol-ims-demo/jcl/CANRUN.jcl` |
| Dashboard output | Static HTML + Mermaid.js for dependency graph | Prior demo: `tedfoley-cog/ecu-bms-controller/docs/flowchart.html` |
| Flowchart | Mermaid via CDN, standalone HTML | Template from `ecu-bms-controller` |

## 4. Repo Layout

```
tidal-batch-reengineering-demo/
├── README.md
├── DEMO_NOTES.md
├── docs/
│   ├── IMPLEMENTATION_PLAN.md          # This file
│   ├── flowchart.html                  # Demo flow — standalone HTML + Mermaid
│   └── flowchart.png                   # Rasterized version
├── tidal_jobs/
│   ├── finance_daily_batch.xml         # 7 finance/accounting jobs
│   ├── payroll_processing.xml          # 4 payroll jobs
│   ├── eod_operations.xml              # 5 end-of-day jobs
│   ├── legacy_misc.xml                 # 4 legacy/cryptic jobs
│   ├── groups/
│   │   └── job_groups.xml              # Job group hierarchy definitions
│   └── schedules/
│       └── daily_calendar.xml          # Calendar/schedule definitions
├── cobol_programs/
│   ├── ACCTEXTRACT.cbl                 # Account daily extract
│   ├── GLPOSTING.cbl                   # General ledger posting
│   └── PAYROLLCALC.cbl                 # Payroll calculation
├── jcl_scripts/
│   ├── ACCTEXTR.jcl                    # JCL for account extract
│   ├── GLPOST.jcl                      # JCL for GL posting
│   └── EODRECON.jcl                    # JCL for EOD reconciliation
├── shell_scripts/
│   ├── file_transfer.sh                # FTP/SFTP file transfer
│   ├── archive_logs.sh                 # Log archival
│   └── notify_ops.sh                   # Ops notification
├── sql_procedures/
│   ├── sp_gl_validation.sql            # GL validation stored procedure
│   └── sp_payroll_summary.sql          # Payroll summary stored procedure
├── logs/
│   └── failure_log_20260415.log        # Sample failure log with non-obvious root cause
├── dashboard/
│   └── index.html                      # Scaffold for generated dashboard (Devin fills this live)
└── .github/workflows/
    └── ci.yml                          # Simple CI: XML lint + structure validation
```

## 5. Flowchart Outline

**Nodes:**
1. Presenter opens repo → shows Tidal XML files (black box)
2. Devin session starts → reads all job definitions
3. Devin parses dependency chains → maps job graph
4. Devin traces failure log → identifies root cause
5. Devin reverse-engineers COBOL/JCL → documents business logic
6. Devin tags each job → purpose, owner, schedule, data sources
7. Devin generates interactive dashboard → dependency graph + job cards
8. Presenter opens dashboard in browser → audience sees full landscape

**Edges:** Linear flow with a parallel branch for COBOL analysis and failure tracing.

## 6. Runtime Plan

**"Appears runnable" via Devin-generated dashboard.** Since we cannot connect to a real Tidal server, the repo contains exported Tidal XML job definitions (using authentic TES XML format) that Devin parses directly. Devin generates a `dashboard/index.html` with:
- Interactive Mermaid dependency graph
- Job documentation cards (purpose, owner, dependencies, data sources, schedule)
- Failure trace visualization

The presenter opens the generated dashboard in the browser tab within the Devin session.

## 7. CI Plan

`.github/workflows/ci.yml` — under 30 lines:
- Checkout
- Validate XML well-formedness (`xmllint` or Python `xml.etree`)
- Verify expected file structure

## 8. Risks and Unknowns

- **Tidal XML export format**: The official Tidal Workload Automation Transporter exports in a proprietary XML format. Cisco docs are partially offline (PDF links return 404). The REST API XML schema from the TES 6.2 guide is the best public reference available. The demo uses this schema for job definitions, which is realistic for API-extracted definitions. If a customer's actual Tidal export uses a different schema (e.g. Transporter flat file), the XML structure may need adjustment.
- **Job count**: 20 jobs across 4 XML files, organized by business domain. This is realistic for a subset of a real Tidal server (which might have thousands).
