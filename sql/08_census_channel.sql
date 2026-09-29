SELECT channel, COUNT(DISTINCT student_uuid) AS users, COUNT(DISTINCT IF(funnel_step='s6', student_uuid, NULL)) AS s6_users
FROM `ik-marketing-data.Organic.Organic_Traffic_US_GA_Logic`
WHERE act_date BETWEEN '2026-07-01' AND '2026-09-28' AND session_country = 'United States'
  AND IFNULL(business_unit,'') <> 'Internal - Non-Prod'
GROUP BY 1 ORDER BY 2 DESC
