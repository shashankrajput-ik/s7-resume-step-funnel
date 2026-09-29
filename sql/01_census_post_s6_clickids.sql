WITH ev AS (
  SELECT student_uuid, act_timestamp, month, funnel_step, ClickID
  FROM `ik-marketing-data.Marketing_data_new_logic.clickstream_master_overall_master_view`
  WHERE act_date BETWEEN '2026-07-01' AND '2026-09-28'
    AND session_country = 'United States'
    AND IFNULL(business_unit,'') <> 'Internal - Non-Prod'
),
s6 AS (
  SELECT student_uuid, MIN(act_timestamp) AS s6_ts FROM ev WHERE funnel_step = 's6' GROUP BY 1
)
SELECT FORMAT_DATE('%Y-%m', DATE(s6.s6_ts)) AS s6_month, ev.funnel_step, ev.ClickID,
       COUNT(DISTINCT ev.student_uuid) AS users, COUNT(*) AS events
FROM ev JOIN s6 USING (student_uuid)
WHERE ev.act_timestamp >= s6.s6_ts
GROUP BY 1,2,3
HAVING users >= 5
ORDER BY 1, users DESC
