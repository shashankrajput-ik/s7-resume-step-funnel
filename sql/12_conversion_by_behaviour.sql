WITH ev AS (
  SELECT student_uuid, act_timestamp, FORMAT_DATE('%Y-%m', act_date) AS month, funnel_step, ClickID, hs_id
  FROM `ik-marketing-data.Organic.Organic_Traffic_US_GA_Logic`
  WHERE act_date BETWEEN '2026-07-01' AND '2026-09-28'
    AND session_country = 'United States'
    AND IFNULL(business_unit,'') <> 'Internal - Non-Prod'
),
usr AS (
  SELECT month, student_uuid, ANY_VALUE(hs_id) AS hs_id,
    LOGICAL_OR(funnel_step = 's3') AS s3,
    MIN(IF(funnel_step = 's6', act_timestamp, NULL)) AS s6_ts
  FROM ev GROUP BY 1, 2
),
beh AS (
  SELECT u.month, u.student_uuid,
    LOGICAL_OR(e.ClickID = 'preferred_time_slot') AS slot,
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
   AND lg.ts BETWEEN u.s6_ts AND TIMESTAMP_ADD(u.s6_ts, INTERVAL 24 HOUR)
  WHERE u.s6_ts IS NOT NULL
),
al AS (
  SELECT FORMAT_DATE('%Y-%m', Lead_Month) AS month, User_ID,
         LOGICAL_OR(sale_date IS NOT NULL) AS sale
  FROM `ik-marketing-data.Marketing_data_new_logic.Bq_data_Alumni`
  WHERE Lead_Month BETWEEN '2026-07-01' AND '2026-09-01' AND dupe_logic = 1 AND User_ID IS NOT NULL
  GROUP BY 1, 2
),
f AS (
  SELECT u.month, u.student_uuid, u.s3, u.s6_ts IS NOT NULL AS s6,
    IFNULL(b.slot, FALSE) AS slot, IFNULL(b.resume_click, FALSE) AS resume_click,
    up.student_uuid IS NOT NULL AS uploaded, IFNULL(b.finish, FALSE) AS finish, al.sale
  FROM usr u
  JOIN al ON al.User_ID = u.student_uuid AND al.month = u.month
  LEFT JOIN beh b ON b.month = u.month AND b.student_uuid = u.student_uuid
  LEFT JOIN up ON up.month = u.month AND up.student_uuid = u.student_uuid
),
seg AS (
  SELECT month, sale, s FROM f, UNNEST([
    IF(s3, '02 PII submitted (S3)', NULL),
    IF(s3 AND NOT s6, '03 PII but never reached S6', NULL),
    IF(s6, '04 Reached S6', NULL),
    IF(s6 AND slot, '05 S6 + slot selected', NULL),
    IF(s6 AND NOT slot, '06 S6 + no slot', NULL),
    IF(s6 AND resume_click, '07 S6 + resume clicked', NULL),
    IF(s6 AND NOT resume_click, '08 S6 + no resume click', NULL),
    IF(s6 AND uploaded, '09 S6 + resume uploaded', NULL),
    IF(s6 AND resume_click AND NOT uploaded, '10 S6 + clicked, not uploaded', NULL),
    IF(s6 AND NOT uploaded, '11 S6 + not uploaded', NULL),
    IF(s6 AND finish, '12 S6 + submitted (S7)', NULL),
    IF(s6 AND NOT finish, '13 S6 + not submitted', NULL),
    IF(s6 AND slot AND uploaded, '14 S6 + slot AND uploaded', NULL),
    IF(s6 AND NOT slot AND NOT resume_click, '15 S6 + no slot, no resume click', NULL)
  ]) s WHERE s IS NOT NULL
)
SELECT month, '01 ALL leads (Bq_data_Alumni, dupe_logic=1)' AS segment, COUNT(*) AS leads, COUNTIF(sale) AS sales FROM al GROUP BY 1, 2
UNION ALL
SELECT month, s, COUNT(*), COUNTIF(sale) FROM seg GROUP BY 1, 2
ORDER BY 1, 2
