# Demo Cheat Sheet — Tidal Batch Job Reengineering

## Setup (do this before joining the call)
- [ ] Open the repo in a browser tab: https://github.com/tedfoley-cog/tidal-batch-reengineering-demo
- [ ] Confirm the 3 connected repos exist: [acme-gl-ledger](https://github.com/tedfoley-cog/acme-gl-ledger), [acme-payroll-engine](https://github.com/tedfoley-cog/acme-payroll-engine), [acme-data-warehouse](https://github.com/tedfoley-cog/acme-data-warehouse)
- [ ] Have a Devin session ready on this repo

## Demo Flow
1. Show the repo — point out the Tidal XML files, COBOL programs, cryptic job names (`JOB_X47B`, `PROC_LEGACY_01`), and the failure log. "This is what the ops team sees every day — a black box. And it gets worse: these jobs interact with 3 separate application codebases that live in different repos."
2. Show the 3 connected repos briefly — GL ledger (DB2 schemas, stored procs), payroll engine (COBOL copybooks, tax tables), data warehouse (ETL pipelines, SOX compliance). "Nobody has a complete picture of how data flows across all of these."
3. Prompt Devin: "Analyze all the Tidal job definitions, discover which external repos they reference, clone those repos, trace the full data flow across all systems, and generate an interactive dashboard documenting the complete cross-repo job landscape."
4. While Devin works, narrate: it's parsing XML dependencies, discovering cross-repo references in the job comments, cloning the GL ledger and payroll repos, matching COBOL copybooks to program COPY statements, tracing DB2 table lineage from extract → validation → posting → warehouse → regulatory feed, and identifying the broken reference to `LEGACY_CTRL_CHK`.
5. Open the generated dashboard — show the cross-repo dependency graph, data flow diagram, job documentation cards, and failure trace. "In 10 minutes, Devin mapped what would take an engineer weeks of tribal knowledge interviews across 4 repos."
