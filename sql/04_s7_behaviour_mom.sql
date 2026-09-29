WITH ev AS (
  SELECT student_uuid, act_timestamp, act_date, funnel_step, ClickID
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
  SELECT s6.month, s6.student_uuid, s6.s6_ts,
    LOGICAL_OR(e.ClickID = 'preferred_time_slot')      AS slot,
    LOGICAL_OR(e.ClickID = 'gql_linkdin_pr_link')      AS linkedin,
    LOGICAL_OR(e.ClickID = 'gql_get_resume')           AS resume_click,
    LOGICAL_OR(e.funnel_step = 's7')                   AS finish,
    LOGICAL_OR(e.ClickID = 'Icon_material-close')      AS closed,
    LOGICAL_OR(e.ClickID = 'webinar-modal_button_go-back') AS went_back
  FROM s6 JOIN ev e ON e.student_uuid = s6.student_uuid
   AND e.act_timestamp >= s6.s6_ts AND FORMAT_DATE('%Y-%m', e.act_date) = s6.month
  GROUP BY 1, 2, 3
),
map AS (
  SELECT user_id, ARRAY_AGG(DISTINCT customer_id IGNORE NULLS) AS cids
  FROM `ik-marketing-data.Geo_Unified.master_table`
  WHERE data_source <> 'step-5-expert-insight' AND user_id IS NOT NULL
  GROUP BY 1
),
s5 AS (
  SELECT customer_id, lead_magnet, lead_created_time
  FROM `ik-marketing-data.Geo_Unified.master_table`
  WHERE data_source = 'step-5-expert-insight' AND lead_magnet = 'EXPERT_INSIGHTS'
),
up AS (
  SELECT u.month, u.student_uuid,
    ARRAY_AGG(DISTINCT s5.lead_magnet IGNORE NULLS) AS lms
  FROM u JOIN map ON map.user_id = u.student_uuid
  JOIN s5 ON s5.customer_id IN UNNEST(map.cids)
   AND s5.lead_created_time BETWEEN u.s6_ts AND TIMESTAMP_ADD(u.s6_ts, INTERVAL 24 HOUR)
  GROUP BY 1, 2
),
f AS (
  SELECT u.*, map.cids IS NOT NULL AS mapped, up.student_uuid IS NOT NULL AS uploaded, up.lms
  FROM u LEFT JOIN map ON map.user_id = u.student_uuid
  LEFT JOIN up USING (month, student_uuid)
)
SELECT month,
  COUNT(*) AS s6_users,
  COUNTIF(s6_ts >= TIMESTAMP '2026-08-04 11:00:00') AS s6_upload_measurable,
  COUNTIF(resume_click AND s6_ts >= TIMESTAMP '2026-08-04 11:00:00') AS resume_clicked_measurable,
  COUNTIF(slot) AS slot_selected,
  COUNTIF(linkedin) AS linkedin_added,
  COUNTIF(resume_click) AS resume_clicked,
  COUNTIF(uploaded) AS resume_uploaded,
  COUNTIF(uploaded AND resume_click) AS uploaded_and_clicked,
  COUNTIF(finish) AS finish,
  COUNTIF(finish AND NOT slot AND NOT linkedin AND NOT resume_click) AS finish_no_s7_action,
  COUNTIF(NOT finish) AS no_finish,
  COUNTIF(NOT finish AND closed) AS no_finish_closed,
  COUNTIF(NOT finish AND NOT slot AND NOT linkedin AND NOT resume_click) AS no_finish_no_action,
  COUNTIF(went_back) AS went_back,
  COUNTIF(mapped) AS mapped_to_customer_id,
  COUNTIF(uploaded AND finish) AS uploaded_and_finish
FROM f GROUP BY 1 ORDER BY 1
