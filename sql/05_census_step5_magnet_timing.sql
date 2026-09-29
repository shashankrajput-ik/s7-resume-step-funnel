WITH ev AS (
  SELECT student_uuid, act_timestamp, funnel_step, ClickID
  FROM `ik-marketing-data.Organic.Organic_Traffic_US_GA_Logic`
  WHERE act_date BETWEEN '2026-08-04' AND '2026-09-28'
    AND session_country = 'United States'
    AND IFNULL(business_unit,'') <> 'Internal - Non-Prod'
),
u AS (
  SELECT student_uuid, MIN(IF(funnel_step='s6', act_timestamp, NULL)) AS s6_ts,
         MIN(IF(ClickID='gql_get_resume', act_timestamp, NULL)) AS click_ts
  FROM ev GROUP BY 1 HAVING s6_ts IS NOT NULL
),
map AS (
  SELECT user_id, ARRAY_AGG(DISTINCT customer_id IGNORE NULLS) AS cids
  FROM `ik-marketing-data.Geo_Unified.master_table`
  WHERE data_source <> 'step-5-expert-insight' AND user_id IS NOT NULL GROUP BY 1
),
s5 AS (
  SELECT customer_id, lead_magnet, lead_created_time, cta_page, resume_analyser_source_check
  FROM `ik-marketing-data.Geo_Unified.master_table` WHERE data_source = 'step-5-expert-insight'
)
SELECT s5.lead_magnet, u.click_ts IS NOT NULL AS clicked_resume,
  CASE WHEN TIMESTAMP_DIFF(s5.lead_created_time, u.s6_ts, MINUTE) < 0 THEN 'a <0 (up to -60m)'
       WHEN TIMESTAMP_DIFF(s5.lead_created_time, u.s6_ts, MINUTE) <= 30 THEN 'b 0-30m'
       WHEN TIMESTAMP_DIFF(s5.lead_created_time, u.s6_ts, HOUR) <= 24 THEN 'c 30m-24h'
       ELSE 'd >24h' END AS gap,
  COUNT(DISTINCT u.student_uuid) AS users,
  ANY_VALUE(s5.cta_page) AS eg_cta_page, ANY_VALUE(s5.resume_analyser_source_check) AS eg_src
FROM u JOIN map ON map.user_id = u.student_uuid
JOIN s5 ON s5.customer_id IN UNNEST(map.cids) AND s5.lead_created_time >= TIMESTAMP_SUB(u.s6_ts, INTERVAL 1 HOUR)
GROUP BY 1, 2, 3 ORDER BY 1, 2, 3
