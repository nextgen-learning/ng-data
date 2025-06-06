select 
  round(avg(members_progression_rate)/100,2) as avg_progression_rate,
  round(avg(cast(regexp_extract(time_spent, r'^\d+') as decimal)),2) as avg_time_spent,
  numero_groupe
from 
  mindful-hull-401711.schoolmaker.members_progression_data_analyst_insider
join
  mindful-hull-401711.schoolmaker.repartition_eleves_groupe
on
  members_progression_data_analyst_insider.email = repartition_eleves_groupe.email
group by
  numero_groupe