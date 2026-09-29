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
SELECT 'uuid_grain' AS grain, COUNTIF(s4) AS base, COUNTIF(s4 AND sale=1) AS sales, COUNTIF(s4 AND att=1) AS att,
  COUNTIF(s6_first IS NOT NULL) AS s6, COUNTIF(s6_first IS NOT NULL AND sale=1) AS s6_sales,
  COUNTIF(upl) AS upl, COUNTIF(upl AND sale=1) AS upl_sales, COUNTIF(n_in=3) AS all3, COUNTIF(n_in=3 AND sale=1) AS all3_sales,
  COUNTIF(s6_first IS NOT NULL AND n_in=0) AS none, COUNTIF(s6_first IS NOT NULL AND n_in=0 AND sale=1) AS none_sales
FROM x
UNION ALL
SELECT 'person_grain', COUNT(DISTINCT IF(s4, k, NULL)), COUNT(DISTINCT IF(s4 AND sale=1, k, NULL)), COUNT(DISTINCT IF(s4 AND att=1, k, NULL)),
  COUNT(DISTINCT IF(s6_first IS NOT NULL, k, NULL)), COUNT(DISTINCT IF(s6_first IS NOT NULL AND sale=1, k, NULL)),
  COUNT(DISTINCT IF(upl, k, NULL)), COUNT(DISTINCT IF(upl AND sale=1, k, NULL)), COUNT(DISTINCT IF(n_in=3, k, NULL)), COUNT(DISTINCT IF(n_in=3 AND sale=1, k, NULL)),
  COUNT(DISTINCT IF(s6_first IS NOT NULL AND n_in=0, k, NULL)), COUNT(DISTINCT IF(s6_first IS NOT NULL AND n_in=0 AND sale=1, k, NULL))
FROM (SELECT x.*, IFNULL(hs_id, student_uuid) AS k FROM x);
