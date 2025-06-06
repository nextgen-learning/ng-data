WITH RECURSIVE date_search AS (
  -- Point de départ : CURRENT_DATE() - 7
  SELECT 
    7 AS days_ago,
    FORMAT_DATE('%Y-%m-%d', CURRENT_DATE() - 7) AS file_date,
    EXTRACT(DAYOFWEEK FROM CURRENT_DATE() - 7) AS day_of_week
  UNION ALL
  -- On remonte progressivement jusqu'à CURRENT_DATE() - 1, en excluant les week-ends
  SELECT 
    days_ago - 1,
    FORMAT_DATE('%Y-%m-%d', CURRENT_DATE() - (days_ago - 1)),
    EXTRACT(DAYOFWEEK FROM CURRENT_DATE() - (days_ago - 1))
  FROM date_search
  WHERE days_ago >= 1
    AND EXTRACT(DAYOFWEEK FROM CURRENT_DATE() - (days_ago - 1)) NOT IN (1, 7) -- Exclure dimanche (1) et samedi (7)
)
-- Sélectionner la dernière date valide
SELECT * 
FROM `mindful-hull-401711.schoolmaker.members_progression_data_analyst_insider_external`
WHERE _FILE_NAME LIKE CONCAT('%', (SELECT file_date FROM date_search ORDER BY days_ago DESC LIMIT 1), '.csv');
