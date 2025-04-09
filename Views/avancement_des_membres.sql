WITH last_lesson_extract AS (
  SELECT
    full_name,
    DATE(timestamp_connexion) AS date,
    programme,
    CASE 
      WHEN action LIKE 'Consultation de la leçon%' THEN REGEXP_EXTRACT(action, r'\d.*') 
      END
    AS lesson,
    duree_action,
    timestamp_connexion,
    group_number
  FROM mindful-hull-401711.schoolmaker.members_and_events      
)

SELECT
  full_name,
  date,
  section,
  last_lesson_extract.lesson,
  group_number
FROM last_lesson_extract
LEFT JOIN mindful-hull-401711.schoolmaker.plan_programme_data_analyst_insider
  ON LOWER(TRIM(last_lesson_extract.lesson))=LOWER(TRIM(plan_programme_data_analyst_insider.lesson))
WHERE last_lesson_extract.lesson IS NOT NULL
  AND last_lesson_extract.programme = 'Data Analyst Insider'
  AND duree_action > TIME(00,01,30) 
  AND duree_action != TIME(01,00,00)
  AND CAST(timestamp_connexion AS DATE) > CURRENT_DATE - 7
QUALIFY ROW_NUMBER () OVER (PARTITION BY full_name ORDER BY timestamp_connexion DESC) = 1
