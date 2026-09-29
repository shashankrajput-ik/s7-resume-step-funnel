# S7 page behaviour vs webinar attendance and sales

Does what a registrant does on the last page of the GQL webinar form (S7: time slot, LinkedIn URL,
resume upload, submit) correlate with webinar attendance and sales conversion? **Yes, for both.**
US traffic, 1 Aug - 28 Sep 2026.

- Report: [`report/S7_Page_Behaviour_Conversion.pdf`](report/S7_Page_Behaviour_Conversion.pdf)
- Tables: `outputs/s7_funnel_behaviour_aug_sep.xlsx`, `outputs/final_tables.md`
- Reconciliation: [`RECON.md`](RECON.md)
- Definitions, read-rules and file map: [`CLAUDE.md`](CLAUDE.md)

Rebuild: `python verify.py && python build_tables.py && python insights_stats.py && python build_report.py`

All queries are read-only against BigQuery project `ik-marketing-data`.
