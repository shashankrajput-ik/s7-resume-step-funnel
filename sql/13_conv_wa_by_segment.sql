WITH ev AS (
  SELECT student_uuid, act_timestamp, FORMAT_DATE('%Y-%m', act_date) AS month, funnel_step, ClickID, hs_id
  FROM `ik-marketing-data.Organic.Organic_Traffic_US_GA_Logic`
  WHERE act_date BETWEEN '2026-07-01' AND '2026-09-28'
    AND session_country = 'United States'
    AND IFNULL(business_unit,'') <> 'Internal - Non-Prod'
),
usr AS (
  SELECT month, student_uuid, ANY_VALUE(hs_id) AS hs_id,
    LOGICAL_OR(funnel_step = 's3') AS s3, LOGICAL_OR(funnel_step = 's4') AS s4,
    LOGICAL_OR(funnel_step = 's5') AS s5, LOGICAL_OR(funnel_step = 's7') AS s7,
    MIN(IF(funnel_step = 's6', act_timestamp, NULL)) AS s6_ts
  FROM ev GROUP BY 1, 2
),
beh AS (
  SELECT u.month, u.student_uuid,
    LOGICAL_OR(e.ClickID = 'preferred_time_slot') AS slot,
    LOGICAL_OR(e.ClickID = 'gql_linkdin_pr_link') AS linkedin,
    LOGICAL_OR(e.ClickID = 'gql_get_resume') AS resume_click,
    LOGICAL_OR(e.funnel_step = 's7') AS finish
  FROM usr u JOIN ev e ON e.student_uuid = u.student_uuid AND e.month = u.month AND e.act_timestamp >= u.s6_ts
  WHERE u.s6_ts IS NOT NULL GROUP BY 1, 2
),
lg AS (
  SELECT DISTINCT hubspot_id, CAST(created_at AS TIMESTAMP) AS ts
  FROM `ik-marketing-data.Tech_ML_Projects.Resume Analysis - GQL data`
  WHERE lead_magnet = 'EXPERT_INSIGHTS' AND created_at >= '2026-06-30'
),
up AS (
  SELECT DISTINCT u.month, u.student_uuid FROM usr u JOIN lg ON lg.hubspot_id = u.hs_id
   AND lg.ts BETWEEN u.s6_ts AND TIMESTAMP_ADD(u.s6_ts, INTERVAL 2 HOUR)
  WHERE u.s6_ts IS NOT NULL
),
al AS (
  SELECT FORMAT_DATE('%Y-%m', Lead_Month) AS month, User_ID,
    LOGICAL_OR(sale_date IS NOT NULL) AS sale,
    LOGICAL_OR(webinar_email_1 IS NOT NULL) AS att,
    LOGICAL_OR(IFNULL(Event_Start_Date_Time, TIMESTAMP '2000-01-01') <= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 4 DAY)) AS reg_held,
    LOGICAL_OR(webinar_email_1 IS NOT NULL AND IFNULL(Event_Start_Date_Time, TIMESTAMP '2000-01-01') <= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 4 DAY)) AS att_held
  FROM `ik-marketing-data.Marketing_data_new_logic.Bq_data_Alumni`
  WHERE Lead_Month BETWEEN '2026-07-01' AND '2026-09-01' AND dupe_logic = 1 AND User_ID IS NOT NULL
  GROUP BY 1, 2
),
f AS (
  SELECT u.month, u.s3, u.s4, u.s5, u.s6_ts IS NOT NULL AS s6, u.s7,
    IFNULL(b.slot, FALSE) AS slot, IFNULL(b.linkedin, FALSE) AS linkedin, IFNULL(b.resume_click, FALSE) AS rc,
    up.student_uuid IS NOT NULL AS uploaded, IFNULL(b.finish, FALSE) AS finish,
    CAST(IFNULL(b.slot, FALSE) AS INT64) + CAST(IFNULL(b.linkedin, FALSE) AS INT64) + CAST(IFNULL(b.resume_click, FALSE) AS INT64) AS n_inputs,
    al.sale, al.att, al.reg_held, al.att_held
  FROM usr u
  JOIN al ON al.User_ID = u.student_uuid AND al.month = u.month
  LEFT JOIN beh b ON b.month = u.month AND b.student_uuid = u.student_uuid
  LEFT JOIN up ON up.month = u.month AND up.student_uuid = u.student_uuid
),
seg AS (
  SELECT f.*, s FROM f, UNNEST([
    IF(s6, 'A01 Reached S6', NULL),
    IF(s6 AND n_inputs = 0, 'B01 S6 + touched no input', NULL),
    IF(s6 AND n_inputs = 1, 'B02 S6 + exactly one input', NULL),
    IF(s6 AND n_inputs = 1 AND slot, 'B03   one input = slot only', NULL),
    IF(s6 AND n_inputs = 1 AND linkedin, 'B04   one input = LinkedIn only', NULL),
    IF(s6 AND n_inputs = 1 AND rc, 'B05   one input = resume click only', NULL),
    IF(s6 AND n_inputs = 2, 'B06 S6 + exactly two inputs', NULL),
    IF(s6 AND n_inputs = 3, 'B07 S6 + all three inputs', NULL),
    IF(s6 AND slot, 'C01 S6 + slot selected', NULL),
    IF(s6 AND NOT slot, 'C02 S6 + no slot', NULL),
    IF(s6 AND linkedin, 'C03 S6 + LinkedIn added', NULL),
    IF(s6 AND NOT linkedin, 'C04 S6 + no LinkedIn', NULL),
    IF(s6 AND rc, 'C05 S6 + resume clicked', NULL),
    IF(s6 AND NOT rc, 'C06 S6 + no resume click', NULL),
    IF(s6 AND uploaded, 'C07 S6 + resume uploaded', NULL),
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
SELECT month, 'A00 ALL leads (overall)' AS segment, COUNT(*) AS leads, COUNTIF(sale) AS sales, COUNTIF(att) AS att, COUNTIF(reg_held) AS reg_held, COUNTIF(att_held) AS att_held FROM al GROUP BY 1, 2
UNION ALL
SELECT month, s, COUNT(*), COUNTIF(sale), COUNTIF(att), COUNTIF(reg_held), COUNTIF(att_held) FROM seg GROUP BY 1, 2
ORDER BY 1, 2
