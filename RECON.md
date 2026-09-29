# Reconciliation - 2026-09-29 (run before the PDF)

1. **Arithmetic identities** - `python verify.py`: 1,093 checks, 0 failures. Parts sum to wholes
   (0/1/2/3 inputs = S6; slot/no slot; uploaded/not; submitted/dropped; S4->S5 + dropped = base),
   Paid + Non-paid + Other = overall on every segment and metric, max(month) <= Aug+Sep <= Aug + Sep,
   pre-match S4 == funnel S4 per month (7,541 / 6,211).
2. **Two bugs found and fixed by (1):**
   - Upload was anchored on the FIRST S6 in the period, so a user whose upload followed a later S6 was
     missed in the pooled view (pooled 'clicked, not uploaded' 1,192 > 628 + 563). Now: EXPERT_INSIGHTS
     within 2h of ANY S6 event. Aug+Sep uploaders 1,035 -> 1,049, sales 40 -> 42.
   - Paid/non-paid was the first event's channel per period, so a user could change group between the
     month and pooled views. Now ONE group per user for the whole window: channel of the first S4,
     first event if no S4.
3. **Independent recompute** - `sql/16` (temp tables, EXISTS, no UNNEST): all 14 key cells equal the
   report exactly (base 13,387 / 264 / 6,104; S6 10,232 / 235; all-3 1,330 / 55; none 3,646;
   uploaded 1,049 / 42 / 591; S6 dropped 1,777 / 582; S5 dropped 2,290).
4. **Sources** - upload legacy vs master_table route (from 2026-08-04 11:00): 1,001 vs 1,007 (0.6%).
   Counted sale dates 2026-08-03..2026-09-28; 1 user has a sale before the lead. Base holds 264 of the
   353 Bq_data_Alumni (dupe_logic=1, Aug-Sep) sale-users = 74.8%; the rest never registered through a
   US-session clickstream path.
5. **Person grain** - 631 hubspot ids carry 2+ student_uuids (multi-device). Person-grain (`sql/17`):
   base 12,654 (-5.5%), conv 2.05% vs 1.97%, WA 45.2% vs 45.6%; segment CONVERSION rates move <= 0.1pt (segment WA not re-derived at person grain)
   (S6 2.34 vs 2.30, all-3 4.12 vs 4.14, uploaded 3.96 vs 4.00, none 1.37 vs 1.37). Report stays at
   student_uuid grain (user's instruction); conclusions unchanged.
6. **Stability** - sql/14 rerun: 75 rows, 0 differences.
