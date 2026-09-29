WITH ev AS (
  SELECT student_uuid, act_timestamp, funnel_step, ClickID, hs_id
  FROM `ik-marketing-data.Marketing_data_new_logic.clickstream_master_overall_master_view`
  WHERE act_date BETWEEN '2026-07-01' AND '2026-09-28'
    AND session_country = 'United States'
    AND IFNULL(business_unit,'') <> 'Internal - Non-Prod'
),
u AS (
  SELECT student_uuid,
         MIN(IF(funnel_step='s6', act_timestamp, NULL)) AS s6_ts,
         LOGICAL_OR(ClickID='gql_get_resume') AS clicked_resume,
         LOGICAL_OR(funnel_step='s7') AS s7,
         ANY_VALUE(hs_id) AS hs_id
  FROM ev GROUP BY 1 HAVING s6_ts IS NOT NULL
),
map AS (
  SELECT user_id, ARRAY_AGG(DISTINCT customer_id IGNORE NULLS) AS cids
  FROM `ik-marketing-data.Geo_Unified.master_table`
  WHERE data_source <> 'step-5-expert-insight' AND user_id IS NOT NULL
  GROUP BY 1
),
s5 AS (
  SELECT customer_id, user_id, lead_magnet, lead_created_time, ingested_at
  FROM `ik-marketing-data.Geo_Unified.master_table`
  WHERE data_source = 'step-5-expert-insight'
),
j AS (
  SELECT u.*, map.cids, ARRAY_LENGTH(map.cids) AS n_cid, map.cids[SAFE_OFFSET(0)] AS cid
  FROM u LEFT JOIN map ON map.user_id = u.student_uuid
)
SELECT
  COUNT(*) AS s6_users,
  COUNTIF(hs_id IS NOT NULL) AS has_hs_id,
  COUNTIF(n_cid >= 1) AS mapped_in_master,
  COUNTIF(n_cid > 1) AS multi_cid,
  COUNTIF(n_cid >= 1 AND hs_id IS NOT NULL AND hs_id IN UNNEST(cids)) AS hs_id_agrees,
  COUNTIF(n_cid >= 1 AND hs_id IS NOT NULL AND hs_id NOT IN UNNEST(cids)) AS hs_id_disagrees,
  COUNTIF(clicked_resume) AS clicked_resume,
  COUNTIF(EXISTS(SELECT 1 FROM s5 WHERE s5.customer_id IN UNNEST(j.cids))) AS s5_any_via_master,
  COUNTIF(EXISTS(SELECT 1 FROM s5 WHERE s5.customer_id = j.hs_id)) AS s5_any_via_hs_id,
  COUNTIF(EXISTS(SELECT 1 FROM s5 WHERE s5.user_id = j.student_uuid)) AS s5_via_user_id_direct,
  COUNTIF(EXISTS(SELECT 1 FROM s5 WHERE s5.customer_id IN UNNEST(j.cids) AND s5.lead_created_time >= TIMESTAMP_SUB(j.s6_ts, INTERVAL 1 HOUR))) AS s5_after_s6_via_master,
  COUNTIF(clicked_resume AND EXISTS(SELECT 1 FROM s5 WHERE s5.customer_id IN UNNEST(j.cids) AND s5.lead_created_time >= TIMESTAMP_SUB(j.s6_ts, INTERVAL 1 HOUR))) AS clicked_and_s5_after,
  COUNTIF(NOT clicked_resume AND EXISTS(SELECT 1 FROM s5 WHERE s5.customer_id IN UNNEST(j.cids) AND s5.lead_created_time >= TIMESTAMP_SUB(j.s6_ts, INTERVAL 1 HOUR))) AS notclicked_but_s5_after
FROM j
