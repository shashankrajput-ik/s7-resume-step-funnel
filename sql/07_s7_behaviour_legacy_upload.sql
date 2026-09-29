WITH ev AS (
  SELECT student_uuid, act_timestamp, act_date, funnel_step, ClickID, hs_id
  FROM `ik-marketing-data.Organic.Organic_Traffic_US_GA_Logic`
  WHERE act_date BETWEEN '2026-07-01' AND '2026-09-28'
    AND session_country = 'United States'
    AND IFNULL(business_unit,'') <> 'Internal - Non-Prod'
),
s6 AS (
  SELECT FORMAT_DATE('%Y-%m', act_date) AS month, student_uuid, MIN(act_timestamp) AS s6_ts
  FROM ev WHERE funnel_step = 's6' GROUP BY 1, 2
),
u AS (
  SELECT s6.month, s6.student_uuid, s6.s6_ts, ANY_VALUE(e.hs_id) AS hs_id,
    LOGICAL_OR(e.ClickID = 'gql_get_resume') AS resume_click,
    LOGICAL_OR(e.funnel_step = 's7') AS finish
  FROM s6 JOIN ev e ON e.student_uuid = s6.student_uuid
   AND e.act_timestamp >= s6.s6_ts AND FORMAT_DATE('%Y-%m', e.act_date) = s6.month
  GROUP BY 1, 2, 3
),
lg AS (
  SELECT DISTINCT hubspot_id, CAST(created_at AS TIMESTAMP) AS ts
  FROM `ik-marketing-data.Tech_ML_Projects.Resume Analysis - GQL data`
  WHERE lead_magnet = 'EXPERT_INSIGHTS' AND created_at >= '2026-06-30'
),
up AS (
  SELECT DISTINCT u.month, u.student_uuid
  FROM u JOIN lg ON lg.hubspot_id = u.hs_id
   AND lg.ts BETWEEN u.s6_ts AND TIMESTAMP_ADD(u.s6_ts, INTERVAL 24 HOUR)
)
SELECT month, COUNT(*) AS s6_users, COUNTIF(hs_id IS NOT NULL) AS has_hs_id,
  COUNTIF(resume_click) AS resume_clicked,
  COUNTIF(up.student_uuid IS NOT NULL) AS uploaded,
  COUNTIF(up.student_uuid IS NOT NULL AND resume_click) AS uploaded_and_clicked,
  COUNTIF(up.student_uuid IS NOT NULL AND NOT resume_click) AS uploaded_no_click,
  COUNTIF(up.student_uuid IS NOT NULL AND finish) AS uploaded_and_finish
FROM u LEFT JOIN up USING (month, student_uuid)
GROUP BY 1 ORDER BY 1
