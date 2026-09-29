SELECT lead_magnet, FORMAT_TIMESTAMP('%Y-%m', CAST(created_at AS TIMESTAMP)) AS m, COUNT(*) AS n, COUNT(DISTINCT hubspot_id) AS ids, MAX(CAST(created_at AS TIMESTAMP)) AS max_ts
FROM `ik-marketing-data.Tech_ML_Projects.Resume Analysis - GQL data`
WHERE CAST(created_at AS TIMESTAMP) >= '2026-06-01'
GROUP BY 1,2 ORDER BY 2,1
