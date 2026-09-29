WITH s6 AS (
  SELECT DISTINCT FORMAT_DATE('%Y-%m', act_date) AS month, student_uuid, hs_id
  FROM `ik-marketing-data.Organic.Organic_Traffic_US_GA_Logic`
  WHERE act_date BETWEEN '2026-07-01' AND '2026-09-28' AND session_country = 'United States'
    AND IFNULL(business_unit,'') <> 'Internal - Non-Prod' AND funnel_step = 's6'
),
a AS (
  SELECT FORMAT_DATE('%Y-%m', Lead_Month) AS month, dupe_logic, User_ID, Leads_hubspot_id, sale_date
  FROM `ik-marketing-data.Marketing_data_new_logic.Bq_data_Alumni`
  WHERE Lead_Month BETWEEN '2026-07-01' AND '2026-09-01'
)
SELECT 'dist_dl1' AS k, month, 'rows|sales|ids|null_ids' AS v, COUNT(*) AS n, COUNTIF(sale_date IS NOT NULL) AS sales, COUNT(DISTINCT Leads_hubspot_id) AS ids FROM a WHERE dupe_logic=1 GROUP BY 1,2,3
UNION ALL
SELECT 'match_hs_same_month_dl1', s6.month, '', COUNT(DISTINCT s6.student_uuid), NULL, NULL FROM s6 JOIN a ON a.Leads_hubspot_id = s6.hs_id AND a.month = s6.month AND a.dupe_logic = 1 GROUP BY 1,2,3
UNION ALL
SELECT 'match_hs_any_month_any', s6.month, '', COUNT(DISTINCT s6.student_uuid), NULL, NULL FROM s6 JOIN a ON a.Leads_hubspot_id = s6.hs_id GROUP BY 1,2,3
UNION ALL
SELECT 'match_userid_same_month_dl1', s6.month, '', COUNT(DISTINCT s6.student_uuid), NULL, NULL FROM s6 JOIN a ON a.User_ID = s6.student_uuid AND a.month = s6.month AND a.dupe_logic = 1 GROUP BY 1,2,3
UNION ALL
SELECT 's6_users', month, '', COUNT(DISTINCT student_uuid), NULL, NULL FROM s6 GROUP BY 1,2,3
ORDER BY 1,2,3
