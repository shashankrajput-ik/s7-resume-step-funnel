SELECT FORMAT_DATE('%Y-%m', act_date) AS month,
  COUNT(DISTINCT IF(funnel_step='s0', student_uuid, NULL)) AS s0,
  COUNT(DISTINCT IF(funnel_step='s1', student_uuid, NULL)) AS s1,
  COUNT(DISTINCT IF(funnel_step='s2', student_uuid, NULL)) AS s2,
  COUNT(DISTINCT IF(funnel_step='s3', student_uuid, NULL)) AS s3,
  COUNT(DISTINCT IF(funnel_step='s4', student_uuid, NULL)) AS s4,
  COUNT(DISTINCT IF(funnel_step='s5', student_uuid, NULL)) AS s5,
  COUNT(DISTINCT IF(funnel_step='s6', student_uuid, NULL)) AS s6,
  COUNT(DISTINCT IF(funnel_step='s7', student_uuid, NULL)) AS s7,
  MAX(act_date) AS last_date
FROM `ik-marketing-data.Organic.Organic_Traffic_US_GA_Logic`
WHERE act_date BETWEEN '2026-07-01' AND '2026-09-28'
  AND session_country = 'United States'
  AND IFNULL(business_unit,'') <> 'Internal - Non-Prod'
GROUP BY 1 ORDER BY 1
