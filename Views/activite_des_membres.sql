SELECT 
    full_name, 
    suivi, 
    DATE(timestamp_connexion) AS last_connexion,
	group_number
FROM `mindful-hull-401711.schoolmaker.members_and_events`
WHERE programme = 'Data Analyst Insider' and duree_action is not null and duree_action != '01:00:00' and duree_action != '00:00:00'
QUALIFY ROW_NUMBER() OVER (PARTITION BY full_name ORDER BY timestamp_connexion DESC) = 1