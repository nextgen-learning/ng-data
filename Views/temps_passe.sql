WITH all_users AS (
  SELECT 
    email,
    full_name,
    numero_groupe
  FROM mindful-hull-401711.schoolmaker.repartition_eleves_groupe
),

historic AS (
  SELECT 
    email,
    CAST(REGEXP_EXTRACT(time_spent, r'\d+\.\d+?') AS FLOAT64) AS time_spent_last_week
  FROM mindful-hull-401711.schoolmaker.members_progression_data_analyst_insider_external_7days
),

actual AS (
  SELECT
    email,
    DATE(current_date) as date_day, -- ajout de la date du jour
    CAST(REGEXP_EXTRACT(time_spent, r'\d+\.\d+?') AS FLOAT64) AS time_spent_today
  FROM mindful-hull-401711.schoolmaker.members_progression_data_analyst_insider
),

data_combined AS (
  SELECT 
    all_users.email,
    all_users.full_name,
    all_users.numero_groupe,
    COALESCE(actual.time_spent_today, 0) AS time_spent_today,
    COALESCE(historic.time_spent_last_week, 0) AS time_spent_last_week
  FROM all_users
  LEFT JOIN actual ON all_users.email = actual.email
  LEFT JOIN historic ON all_users.email = historic.email
)

SELECT 
  full_name,
  numero_groupe AS group_number,
  ROUND(SUM(time_spent_today - time_spent_last_week), 1) AS time_spent_7days
FROM data_combined
GROUP BY full_name, numero_groupe
ORDER BY group_number, full_name