WITH ev0 AS (
  SELECT student_uuid, act_timestamp, act_date, FORMAT_DATE('%Y-%m', act_date) AS month,
         funnel_step, ClickID, hs_id,
         CASE WHEN channel IN ('LinkedIn','Google NB','Facebook','Google Discovery') THEN 'Paid'
              WHEN channel = 'Organic' THEN 'Non-paid' END AS grp0
  FROM `ik-marketing-data.Organic.Organic_Traffic_US_GA_Logic`
  WHERE act_date BETWEEN '2026-07-01' AND '2026-09-28'
    AND session_country = 'United States'
    AND IFNULL(business_unit,'') <> 'Internal - Non-Prod'
),
ev AS (
  SELECT e.* EXCEPT (grp0), g AS grp FROM ev0 e, UNNEST(['Overall', e.grp0]) g
),
fun AS (
  SELECT month, grp,
    COUNT(DISTINCT IF(funnel_step='s1', student_uuid, NULL)) AS s1,
    COUNT(DISTINCT IF(funnel_step='s2', student_uuid, NULL)) AS s2,
    COUNT(DISTINCT IF(funnel_step='s3', student_uuid, NULL)) AS s3,
    COUNT(DISTINCT IF(funnel_step='s4', student_uuid, NULL)) AS s4,
    COUNT(DISTINCT IF(funnel_step='s5', student_uuid, NULL)) AS s5,
    COUNT(DISTINCT IF(funnel_step='s6', student_uuid, NULL)) AS s6,
    COUNT(DISTINCT IF(funnel_step='s7', student_uuid, NULL)) AS s7_all
  FROM ev WHERE grp IS NOT NULL GROUP BY 1, 2
),
s6 AS (
  SELECT month, grp, student_uuid, MIN(act_timestamp) AS s6_ts
  FROM ev WHERE funnel_step = 's6' AND grp IS NOT NULL GROUP BY 1, 2, 3
),
u AS (
  SELECT s6.month, s6.grp, s6.student_uuid, s6.s6_ts, ANY_VALUE(e.hs_id) AS hs_id,
    LOGICAL_OR(e.ClickID = 'preferred_time_slot') AS slot,
    LOGICAL_OR(e.ClickID = 'gql_get_resume') AS resume_click,
    LOGICAL_OR(e.funnel_step = 's7') AS finish
  FROM s6 JOIN ev e ON e.student_uuid = s6.student_uuid
   AND e.act_timestamp >= s6.s6_ts AND e.month = s6.month AND e.grp = 'Overall'
  GROUP BY 1, 2, 3, 4
),
lg AS (
  SELECT DISTINCT hubspot_id, CAST(created_at AS TIMESTAMP) AS ts
  FROM `ik-marketing-data.Tech_ML_Projects.Resume Analysis - GQL data`
  WHERE lead_magnet = 'EXPERT_INSIGHTS' AND created_at >= '2026-06-30'
),
up AS (
  SELECT DISTINCT u.month, u.grp, u.student_uuid
  FROM u JOIN lg ON lg.hubspot_id = u.hs_id
   AND lg.ts BETWEEN u.s6_ts AND TIMESTAMP_ADD(u.s6_ts, INTERVAL 24 HOUR)
),
beh AS (
  SELECT month, grp, COUNT(*) AS s6_users, COUNTIF(slot) AS slot_selected,
    COUNTIF(resume_click) AS resume_clicked,
    COUNTIF(up.student_uuid IS NOT NULL) AS uploaded,
    COUNTIF(up.student_uuid IS NOT NULL AND resume_click) AS uploaded_and_clicked,
    COUNTIF(finish) AS submitted_after_s6
  FROM u LEFT JOIN up USING (month, grp, student_uuid) GROUP BY 1, 2
)
SELECT * FROM fun JOIN beh USING (month, grp) ORDER BY grp, month
