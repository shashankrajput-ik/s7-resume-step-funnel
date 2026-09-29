WITH ev0 AS (
  SELECT student_uuid, act_timestamp, FORMAT_DATE('%Y-%m', act_date) AS month, funnel_step, ClickID, hs_id, channel
  FROM `ik-marketing-data.Organic.Organic_Traffic_US_GA_Logic`
  WHERE act_date BETWEEN '2026-08-01' AND '2026-09-28'
    AND session_country = 'United States'
    AND IFNULL(business_unit,'') <> 'Internal - Non-Prod'
),
ev AS (SELECT e.*, p FROM ev0 e, UNNEST([e.month, 'Aug+Sep']) p),
-- ONE group per user for the whole Aug-Sep window, used in every view so month and pooled agree:
-- channel of the user's FIRST REGISTRATION (S4); first event only if they never reached S4.
gu AS (
  SELECT student_uuid,
    COALESCE(ARRAY_AGG(IF(funnel_step = 's4', channel, NULL) IGNORE NULLS ORDER BY act_timestamp LIMIT 1)[SAFE_OFFSET(0)],
             ARRAY_AGG(channel ORDER BY act_timestamp LIMIT 1)[OFFSET(0)]) AS first_channel
  FROM ev0 GROUP BY 1
),
usr AS (
  SELECT p, student_uuid, ANY_VALUE(hs_id) AS hs_id,
    ANY_VALUE(gu.first_channel) AS first_channel,
    LOGICAL_OR(funnel_step = 's4') AS s4, LOGICAL_OR(funnel_step = 's5') AS s5,
    MIN(IF(funnel_step = 's6', act_timestamp, NULL)) AS s6_ts
  FROM ev JOIN gu USING (student_uuid) GROUP BY 1, 2
),
beh AS (
  SELECT u.p, u.student_uuid,
    LOGICAL_OR(e.ClickID = 'preferred_time_slot') AS slot,
    LOGICAL_OR(e.ClickID = 'gql_linkdin_pr_link') AS linkedin,
    LOGICAL_OR(e.ClickID = 'gql_get_resume') AS rc,
    LOGICAL_OR(e.funnel_step = 's7') AS finish
  FROM usr u JOIN ev e ON e.student_uuid = u.student_uuid AND e.p = u.p AND e.act_timestamp >= u.s6_ts
  WHERE u.s6_ts IS NOT NULL GROUP BY 1, 2
),
lg AS (
  SELECT DISTINCT hubspot_id, CAST(created_at AS TIMESTAMP) AS ts
  FROM `ik-marketing-data.Tech_ML_Projects.Resume Analysis - GQL data`
  WHERE lead_magnet = 'EXPERT_INSIGHTS' AND created_at >= '2026-07-31'
),
s6ev AS (
  SELECT DISTINCT p, student_uuid, act_timestamp AS ts FROM ev WHERE funnel_step = 's6'
),
up AS (  -- an upload within 2h of ANY S6 event in the period, not only the first
  SELECT DISTINCT u.p, u.student_uuid FROM usr u
  JOIN s6ev ON s6ev.p = u.p AND s6ev.student_uuid = u.student_uuid
  JOIN lg ON lg.hubspot_id = u.hs_id AND lg.ts BETWEEN s6ev.ts AND TIMESTAMP_ADD(s6ev.ts, INTERVAL 2 HOUR)
),
al0 AS (
  SELECT FORMAT_DATE('%Y-%m', Lead_Month) AS month, User_ID, sale_date, webinar_email_1,
    IFNULL(Event_Start_Date_Time, TIMESTAMP '2000-01-01') <= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 4 DAY) AS held
  FROM `ik-marketing-data.Marketing_data_new_logic.Bq_data_Alumni`
  WHERE Lead_Month IN ('2026-08-01', '2026-09-01') AND dupe_logic = 1 AND User_ID IS NOT NULL
),
al AS (
  SELECT p, User_ID,
    LOGICAL_OR(sale_date IS NOT NULL) AS sale,
    LOGICAL_OR(webinar_email_1 IS NOT NULL) AS att,
    LOGICAL_OR(held) AS reg_held,
    LOGICAL_OR(held AND webinar_email_1 IS NOT NULL) AS att_held
  FROM al0, UNNEST([month, 'Aug+Sep']) p GROUP BY 1, 2
),
f AS (
  SELECT u.p, u.student_uuid,
    CASE WHEN u.first_channel IN ('LinkedIn','Google NB','Facebook','Google Discovery') THEN 'Paid'
         WHEN u.first_channel = 'Organic' THEN 'Non-paid' ELSE 'Other' END AS grp, u.s4, u.s5, u.s6_ts IS NOT NULL AS s6,
    IFNULL(b.slot, FALSE) AS slot, IFNULL(b.linkedin, FALSE) AS linkedin, IFNULL(b.rc, FALSE) AS rc,
    up.student_uuid IS NOT NULL AS uploaded, IFNULL(b.finish, FALSE) AS finish,
    CAST(IFNULL(b.slot, FALSE) AS INT64) + CAST(IFNULL(b.linkedin, FALSE) AS INT64) + CAST(IFNULL(b.rc, FALSE) AS INT64) AS n_inputs,
    al.sale, al.att, al.reg_held, al.att_held
  FROM usr u
  JOIN al ON al.User_ID = u.student_uuid AND al.p = u.p
  LEFT JOIN beh b ON b.p = u.p AND b.student_uuid = u.student_uuid
  LEFT JOIN up ON up.p = u.p AND up.student_uuid = u.student_uuid
),
seg AS (
  SELECT f.*, s FROM f, UNNEST([
    IF(s4, 'A00 All registrations (reached S4) = overall', NULL),
    IF(s6, 'A01 Reached S6', NULL),
    IF(s6 AND n_inputs = 0, 'B01 S6 + touched no input', NULL),
    IF(s6 AND n_inputs = 1, 'B02 S6 + exactly one input', NULL),
    IF(s6 AND n_inputs = 1 AND slot, 'B03 one input = slot only', NULL),
    IF(s6 AND n_inputs = 1 AND linkedin, 'B04 one input = LinkedIn only', NULL),
    IF(s6 AND n_inputs = 1 AND rc, 'B05 one input = resume click only', NULL),
    IF(s6 AND n_inputs = 2, 'B06 S6 + exactly two inputs', NULL),
    IF(s6 AND n_inputs = 3, 'B07 S6 + all three inputs', NULL),
    IF(s6 AND slot, 'C01 S6 + slot selected', NULL),
    IF(s6 AND NOT slot, 'C02 S6 + no slot', NULL),
    IF(s6 AND linkedin, 'C03 S6 + LinkedIn added', NULL),
    IF(s6 AND NOT linkedin, 'C04 S6 + no LinkedIn', NULL),
    IF(s6 AND rc, 'C05 S6 + resume clicked', NULL),
    IF(s6 AND NOT rc, 'C06 S6 + no resume click', NULL),
    IF(s6 AND uploaded, 'C07 S6 + resume uploaded (<=2h)', NULL),
    IF(s6 AND rc AND NOT uploaded, 'C08 S6 + clicked, not uploaded', NULL),
    IF(s6 AND NOT uploaded, 'C09 S6 + not uploaded', NULL),
    IF(s6 AND finish, 'D01 Completed S6 -> submitted S7', NULL),
    IF(s6 AND NOT finish, 'D02 Completed S6 -> dropped (no S7)', NULL),
    IF(s5 AND s6, 'D03 Completed S5 -> reached S6', NULL),
    IF(s5 AND NOT s6, 'D04 Completed S5 -> dropped (no S6)', NULL),
    IF(s4 AND s5, 'D05 Completed S4 -> reached S5', NULL),
    IF(s4 AND NOT s5, 'D06 Completed S4 -> dropped (no S5)', NULL)
  ]) s WHERE s IS NOT NULL
)
SELECT p AS period, grp, s AS segment, COUNT(DISTINCT student_uuid) AS users,
  COUNT(DISTINCT IF(sale, student_uuid, NULL)) AS sales,
  COUNT(DISTINCT IF(att, student_uuid, NULL)) AS attended,
  COUNT(DISTINCT IF(reg_held, student_uuid, NULL)) AS reg_held,
  COUNT(DISTINCT IF(att_held, student_uuid, NULL)) AS att_held
FROM seg GROUP BY 1, 2, 3
UNION ALL
SELECT u.p, CASE WHEN u.first_channel IN ('LinkedIn','Google NB','Facebook','Google Discovery') THEN 'Paid'
         WHEN u.first_channel = 'Organic' THEN 'Non-paid' ELSE 'Other' END,
  'Z01 Reached S4, before lead match', COUNT(*), NULL, NULL, NULL, NULL
FROM usr u WHERE u.s4 GROUP BY 1, 2, 3
ORDER BY 1, 2, 3
