---
title: "Finding: 53 W3C cases crash xpact.exe with contract violations (45 scored as pass)"
labels: group:C-correctness, D2-guided, P0, type:finding
milestone: Week 2 - Baseline
---
## Steps to reproduce
1. Run `scripts\run_xmlconf_conformance.ps1` (all assertions on, workbench `xpact.exe`).
2. Search the results for `system execution failed`, or read `exception_trace.log` in the repository root.

## Expected
Every case ends in ACCEPT or a parse error (REJECT). A malformed input must never break a parser contract.

## Actual
On 2026-10-14, 53 of 2,168 cases crashed with an Eiffel contract violation at 8 distinct sites, mostly in DTD declaration loops (`parse_attlist_declaration`, `parse_content_particle`, `parse_attlist_default_value`) and in `normalized_input`. The runner counts a crash as REJECT, so **45 crashing not-wf cases are reported as passing**. 8 crashing cases are valid documents.

## Logs
`student/results/xmlconf-crashes-2026-10-14/`: `README.md` (table of crash sites), `crashes.tsv` (every case) and `exception_trace.log`.

## Update 2026-10-21

Not rechecked yet, and blocked: with the Python runner and an assertions-on
build (#29), 1,357 of 1,727 cases crash first in `XP_PARSER.normalized_input`
on any CR byte (#28), which hides the crash sites above. One of them still
shows: `rmt-e3e-12` (no CR) fails the loop invariant `index_in_bounds` in
`parse_attlist_default_value`. The assertions-off build reports 0 crashes,
but it has no contracts compiled in. Recheck this finding after #28 is fixed.

## Proposed next step
1. Reproduce and minimize one case per crash site (student work: fixtures and reproductions).
2. Report crashes separately in the runner (B04).
3. Discuss the parser repairs with the developers; this links to A05 (contract failures must not continue as success) and C01/C09.
