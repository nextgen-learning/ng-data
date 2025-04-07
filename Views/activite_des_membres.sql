SELECT 
    full_name, 
    suivi, 
    DATE(timestamp_connexion) AS last_connexion,
	group_number
FROM `mindful-hull-401711.schoolmaker.members_and_events`
QUALIFY ROW_NUMBER() OVER (PARTITION BY full_name ORDER BY timestamp_connexion DESC) = 1