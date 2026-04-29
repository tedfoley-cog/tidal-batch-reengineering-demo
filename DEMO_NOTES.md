# Demo Cheat Sheet — Tidal Batch Job Reengineering

## Setup (do this before joining the call)
- [ ] Open the repo in a browser tab: https://github.com/tedfoley-cog/tidal-batch-reengineering-demo
- [ ] Have a Devin session ready on this repo

## Demo Flow
1. Show the repo — point out the Tidal XML files, COBOL programs, cryptic job names (`JOB_X47B`, `PROC_LEGACY_01`), and the failure log. "This is what the ops team sees every day — a black box."
2. Prompt Devin: "Analyze all the Tidal job definitions, reverse-engineer the COBOL and JCL, trace the failure in the log, and generate an interactive dashboard documenting the full job landscape."
3. While Devin works, narrate what it's doing: parsing XML dependencies, reading COBOL business logic, identifying the broken reference to `LEGACY_CTRL_CHK`, tracing the S0C7 abend back to the skipped record in GL posting.
4. Open the generated dashboard in the browser — show the dependency graph, job documentation cards, and failure trace. "In 10 minutes, Devin mapped what would take an engineer weeks of tribal knowledge interviews."
5. Highlight the broken dependency and undocumented jobs Devin flagged — these are real risks that go unnoticed in production until something breaks.
