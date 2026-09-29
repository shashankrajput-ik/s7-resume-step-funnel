-- Independent recompute of the Aug+Sep overall cells + source recon. Different shape from sql/14:
-- no period UNNEST, no segment UNNEST, EXISTS-based upload and lead tests.
DECLARE t0 TIMESTAMP DEFAULT TIMESTAMP '2026-08-01';
CREATE TEMP TABLE e AS
SELECT student_uuid, act_timestamp, funnel_step, ClickID, hs_id
FROM `ik-marketing-data.Organic.Organic_Traffic_US_GA_Logic`
WHERE act_date BETWEEN '2026-08-01' AND '2026-09-28' AND session_country = 'United States'
  AND IFNULL(business_unit,'') <> 'Internal - Non-Prod';
CREATE TEMP TABLE u AS
SELECT student_uuid, MAX(hs_id) AS hs_id,
  COUNTIF(funnel_step='s4') > 0 AS s4, COUNTIF(funnel_step='s5') > 0 AS s5,
  MIN(IF(funnel_step='s6', act_timestamp, NULL)) AS s6_first
FROM e GROUP BY 1;
CREATE TEMP TABLE a AS
SELECT User_ID, MAX(IF(sale_date IS NOT NULL, 1, 0)) AS sale, MAX(IF(webinar_email_1 IS NOT NULL, 1, 0)) AS att,
  MIN(sale_date) AS first_sale, MIN(DATE(Lead_Created_Time)) AS first_lead
FROM `ik-marketing-data.Marketing_data_new_logic.Bq_data_Alumni`
WHERE Lead_Month IN ('2026-08-01','2026-09-01') AND dupe_logic = 1 AND User_ID IS NOT NULL GROUP BY 1;
CREATE TEMP TABLE x AS
SELECT u.*, a.sale, a.att, a.first_sale, a.first_lead,
  (SELECT COUNT(DISTINCT ClickID) FROM e WHERE e.student_uuid = u.student_uuid AND e.act_timestamp >= u.s6_first
     AND ClickID IN ('preferred_time_slot','gql_linkdin_pr_link','gql_get_resume')) AS n_in,
  EXISTS(SELECT 1 FROM e WHERE e.student_uuid = u.student_uuid AND e.act_timestamp >= u.s6_first AND e.funnel_step='s7') AS sub,
  EXISTS(SELECT 1 FROM e JOIN `ik-marketing-data.Tech_ML_Projects.Resume Analysis - GQL data` r
           ON r.hubspot_id = u.hs_id AND r.lead_magnet='EXPERT_INSIGHTS'
          AND CAST(r.created_at AS TIMESTAMP) BETWEEN e.act_timestamp AND TIMESTAMP_ADD(e.act_timestamp, INTERVAL 2 HOUR)
         WHERE e.student_uuid = u.student_uuid AND e.funnel_step='s6') AS upl
FROM u JOIN a ON a.User_ID = u.student_uuid;
SELECT 'base_S4_users' AS k, COUNTIF(s4) AS v FROM x
UNION ALL SELECT 'base_sales', COUNTIF(s4 AND sale=1) FROM x
UNION ALL SELECT 'base_attended', COUNTIF(s4 AND att=1) FROM x
UNION ALL SELECT 'S6_users', COUNTIF(s6_first IS NOT NULL) FROM x
UNION ALL SELECT 'S6_sales', COUNTIF(s6_first IS NOT NULL AND sale=1) FROM x
UNION ALL SELECT 'S6_all3_users', COUNTIF(s6_first IS NOT NULL AND n_in=3) FROM x
UNION ALL SELECT 'S6_all3_sales', COUNTIF(s6_first IS NOT NULL AND n_in=3 AND sale=1) FROM x
UNION ALL SELECT 'S6_none_users', COUNTIF(s6_first IS NOT NULL AND n_in=0) FROM x
UNION ALL SELECT 'S6_uploaded_users', COUNTIF(s6_first IS NOT NULL AND upl) FROM x
UNION ALL SELECT 'S6_uploaded_sales', COUNTIF(s6_first IS NOT NULL AND upl AND sale=1) FROM x
UNION ALL SELECT 'S6_uploaded_att', COUNTIF(s6_first IS NOT NULL AND upl AND att=1) FROM x
UNION ALL SELECT 'S6_dropped_users', COUNTIF(s6_first IS NOT NULL AND NOT sub) FROM x
UNION ALL SELECT 'S6_dropped_att', COUNTIF(s6_first IS NOT NULL AND NOT sub AND att=1) FROM x
UNION ALL SELECT 'S5_dropped_users', COUNTIF(s5 AND s6_first IS NULL) FROM x
-- source recon
UNION ALL SELECT 'SRC_alumni_users_dl1', COUNT(*) FROM a
UNION ALL SELECT 'SRC_alumni_sale_users', COUNTIF(sale=1) FROM a
UNION ALL SELECT 'SRC_alumni_att_users', COUNTIF(att=1) FROM a
UNION ALL SELECT 'SRC_base_share_of_alumni_sales_pct_x100', CAST(10000 * (SELECT COUNTIF(s4 AND sale=1) FROM x) / COUNTIF(sale=1) AS INT64) FROM a
UNION ALL SELECT 'CHK_sale_before_lead_users', COUNTIF(s4 AND sale=1 AND first_sale < first_lead) FROM x
UNION ALL SELECT 'CHK_min_sale_date_yyyymmdd', CAST(FORMAT_DATE('%Y%m%d', MIN(first_sale)) AS INT64) FROM x WHERE s4 AND sale=1
UNION ALL SELECT 'CHK_max_sale_date_yyyymmdd', CAST(FORMAT_DATE('%Y%m%d', MAX(first_sale)) AS INT64) FROM x WHERE s4 AND sale=1
UNION ALL SELECT 'CHK_hsid_with_2plus_uuids_in_base', COUNT(*) FROM (SELECT hs_id FROM x WHERE s4 AND hs_id IS NOT NULL GROUP BY 1 HAVING COUNT(*) > 1)
UNION ALL SELECT 'CHK_base_users_null_hsid', COUNTIF(s4 AND hs_id IS NULL) FROM x
UNION ALL SELECT 'CHK_alumni_userid_multi_hubspot', COUNT(*) FROM (
  SELECT User_ID FROM `ik-marketing-data.Marketing_data_new_logic.Bq_data_Alumni`
  WHERE Lead_Month IN ('2026-08-01','2026-09-01') AND dupe_logic = 1 AND User_ID IS NOT NULL
  GROUP BY 1 HAVING COUNT(DISTINCT Leads_hubspot_id) > 1)
-- upload source cross-check: master_table route (user_id -> customer_id -> step-5 EXPERT_INSIGHTS), same 2h any-S6 rule
UNION ALL SELECT 'XCHK_uploaded_via_master_table', COUNT(DISTINCT u.student_uuid) FROM u
  JOIN e ON e.student_uuid = u.student_uuid AND e.funnel_step = 's6'
  JOIN (SELECT user_id, customer_id FROM `ik-marketing-data.Geo_Unified.master_table` WHERE data_source <> 'step-5-expert-insight' AND customer_id IS NOT NULL GROUP BY 1, 2) m ON m.user_id = u.student_uuid
  JOIN `ik-marketing-data.Geo_Unified.master_table` s5 ON s5.data_source = 'step-5-expert-insight' AND s5.lead_magnet = 'EXPERT_INSIGHTS'
   AND s5.customer_id = m.customer_id AND s5.lead_created_time BETWEEN e.act_timestamp AND TIMESTAMP_ADD(e.act_timestamp, INTERVAL 2 HOUR)
  WHERE e.act_timestamp >= TIMESTAMP '2026-08-04 11:00:00'
UNION ALL SELECT 'XCHK_uploaded_via_legacy_same_window', COUNT(DISTINCT u.student_uuid) FROM u
  JOIN e ON e.student_uuid = u.student_uuid AND e.funnel_step = 's6'
  JOIN `ik-marketing-data.Tech_ML_Projects.Resume Analysis - GQL data` r ON r.hubspot_id = u.hs_id AND r.lead_magnet = 'EXPERT_INSIGHTS'
   AND CAST(r.created_at AS TIMESTAMP) BETWEEN e.act_timestamp AND TIMESTAMP_ADD(e.act_timestamp, INTERVAL 2 HOUR)
  WHERE e.act_timestamp >= TIMESTAMP '2026-08-04 11:00:00';
