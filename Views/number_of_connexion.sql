select 
    count(*) as number_of_connexion,
    date_trunc(timestamp_connexion, day) as day,
    full_name,
    max(group_number) as group_number
  from 
    `mindful-hull-401711.schoolmaker.members_and_events` 
  where trim(action) like "Connexion"
  group by 
    day, full_name
  order by
    day