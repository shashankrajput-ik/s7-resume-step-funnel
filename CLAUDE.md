# s7-resume-step-funnel

**Question:** does what a registrant does on the S7 page (the last page of the GQL webinar form: pick a
time slot, add a LinkedIn URL, upload a resume, submit) correlate with webinar attendance (WA %) and
sales conversion?

**Answer: yes, for both** (2026-09-29). The more of the S7 page a registrant completes, the more likely
they are to attend and to buy. Dose-response over 0-3 inputs: conversion 1.37% -> 4.14%, WA 41.9% ->
56.8% (trend p < 0.001 both). Every input individually goes with higher conversion AND WA. The actual
resume upload is the strongest single signal (4.00% conv, 2.0x all registrants) and beats click-only
(2.46%, p = 0.038; WA p = 0.002). Stopping after S6 attends at 32.8% vs 50.5% for those who submit.
Holds in 39/40 slice checks (Aug, Sep, paid, non-paid). **Correlation, not causation.**

Deliverable: `report/S7_Page_Behaviour_Conversion.pdf` (house style borrowed from
`page-group-funnel/build_report.py`). Tables also in `outputs/s7_funnel_behaviour_aug_sep.xlsx` and
`outputs/final_tables.md`. Read-only - nothing is written to BigQuery.

## Rebuild

```
python verify.py            # 1,093 arithmetic identities over the CSVs - must be 0 failures
python build_tables.py      # xlsx + final_tables.md
python insights_stats.py    # outputs/insights_stats.json (tests, CIs, robustness)
python build_report.py      # report/S7_Page_Behaviour_Conversion.pdf via headless Chrome
```

After re-running any SQL, re-run all four. Queries run with `bq query --use_legacy_sql=false
--format=csv < sql/NN.sql` (stdin, see the bq quirks memory). ~0.3-1 GB per query on the GA table.

## Scope and sources

| What | Source |
|---|---|
| Clickstream | `Organic.Organic_Traffic_US_GA_Logic` (user-directed; already bot-filtered; ~34x cheaper than `clickstream_master_overall_master_view`) |
| Filters | `session_country = 'United States'`, `IFNULL(business_unit,'') <> 'Internal - Non-Prod'` |
| Window | report: 2026-08-01 .. 2026-09-28 (Aug + Sep). July was explored (sql/03-13) and dropped |
| Sales / WA | `Marketing_data_new_logic.Bq_data_Alumni`, `dupe_logic = 1`, `Lead_Month` in Aug/Sep, joined `User_ID = student_uuid` |
| Resume uploaded | `Tech_ML_Projects.`Resume Analysis - GQL data``, `lead_magnet = 'EXPERT_INSIGHTS'`, `hubspot_id = hs_id`, `created_at` within 2h of ANY S6 event |

## Final definitions (sql/14 overall, sql/15 paid / non-paid)

- **Grain:** distinct `student_uuid`. Aug + Sep counts a user active in both months once.
- **Overall (base) row:** users who reached **S4** (registration) AND have a dupe_logic = 1 lead.
  13,387 of 13,546 unique S4 users (98.8%). Every "x overall" divides by this row.
- **Conversion** = users with any `sale_date IS NOT NULL` on a dupe_logic = 1 lead / users.
- **WA %** = users with `webinar_email_1 IS NOT NULL` / users (user's definition). **WA % held** also
  drops registrations whose `Event_Start_Date_Time` is in the future or < 4 days old - only Sep moves.
- **S7-page inputs:** `preferred_time_slot` (slot), `gql_linkdin_pr_link` (LinkedIn), `gql_get_resume`
  (resume CLICK - only opens the file picker). Counted after the user's first S6 in the period.
- **Submitted S7** = `funnel_step = 's7'` (`Gql-form-button_finish`) after first S6.
- **Drop-off rows** are unsequenced: e.g. "S5 -> dropped" = reached S5 and not S6 in the window.
- **Paid** = LinkedIn, Google NB, Facebook, Google Discovery; **non-paid** = Organic. ONE group per
  user for the whole window: channel of their FIRST S4, else first event. Paid 8,290 + non-paid 430 +
  other 4,667 = 13,387. Other (Email, Brand, Bing, Other...) holds most S5 -> no-S6 drop-offs.

## Read-rules (each one cost a wrong number first)

1. **The resume click is not an upload.** Only ~47% of clickers upload. Upload comes from the Resume
   Analysis table (`EXPERT_INSIGHTS`); 92% land within 30 min of S6 (sql/05). IKIQ / SALARY_INSIGHT /
   RESUME_ANALYSIS_SU rows are other tools - exclude them.
2. **Anchor the upload on ANY S6 event, not the first.** Anchoring on the first S6 missed users whose
   upload followed a later S6 and broke the month-vs-pooled identity (found by verify.py).
3. **Assign the channel group once per user for the whole window.** A per-period "first event" rule
   moved users between groups across the month and pooled views (found by verify.py).
4. **Identity routes.** step-5 `user_id` never equals `student_uuid` (0 matches). The master_table route
   (`user_id` -> `customer_id` -> step-5) agrees with the clickstream `hs_id` 100% (sql/02), and
   uploads via master_table vs the Resume Analysis table agree within 0.6% (sql/16). master_table L1
   starts at the 2026-08-04 cutover, so the Resume Analysis table (now backfilled to current) is the
   source of record.
5. **Bq_data_Alumni column traps:** its metadata lists `hubspot_id_1` but the live SQL rejects it, and
   `Hubspot_id` is ambiguous - use `User_ID` / `Leads_hubspot_id`. `dupe_logic` is a per-lead rank.
6. **Compare within a month.** September leads have had less time to close and attend, so every Sep
   rate is lower for maturity alone.
7. **July is not comparable.** The new form went live 07-16 (organic) / 07-30 (all pages); S6 barely
   exists and old-form S7 fires without S6 (July S7/S6 = 477%).
8. **The GA table reads S1 >= S0** in Jul/Aug - S1 is the top-of-funnel denominator.
9. **Two devices = two users.** 631 hubspot ids carry 2+ student_uuids. At person grain (sql/17) base
   conversion moves 0.08pt, base WA 0.4pt, segment conversion rates <= 0.1pt. Report stays at uuid grain.
10. **Recon before shipping.** RECON.md records the full reconciliation: 1,093 identities, an
    independent recompute (sql/16) exact on 14 cells, source checks, and a rerun with 0 differences.

## File map

- `sql/00-13` - exploration and earlier cuts (census, Jul-Sep monthly, 24h upload window). Superseded
  by 14/15 but kept as the trail. `00_example_student.*` is gitignored (one real user's ids).
- `sql/14`, `sql/15` - the report's two queries. `sql/16`, `sql/17` - recon.
- `outputs/*.csv` - query results; `insights_stats.json`; `final_tables.md`; the xlsx.
- `verify.py`, `build_tables.py`, `insights_stats.py`, `charts.py`, `build_report.py`.
- `report/index.html` + the PDF.

## Open

- Causation is untested - needs an A/B (e.g. stronger slot or resume prompt for half of traffic).
- The user flagged a follow-up step for the S7 cohort, not yet specified.
