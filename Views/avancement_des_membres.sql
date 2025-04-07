with last_lesson_extract as(
  select
    full_name,
    date(timestamp_connexion) as date,
    programme,
    case
      when action like 'Consultation de la leçon%' then regexp_extract(action, r'\d.*') 
    end as lesson,
    duree_action,
    timestamp_connexion,
    group_number,
    cast(regexp_extract(action, r'\d+\.\d+') as float64) as ord
  from mindful-hull-401711.schoolmaker.members_and_events
  where duree_action > time(00,01,30) and cast(timestamp_connexion as date) > current_date - 7
  qualify
    row_number() over(partition by full_name order by ord desc) = 1
)

select 
  full_name,
  date,
  last_lesson_extract.programme,
  plan_programme_data_analyst_insider.section,
  last_lesson_extract.lesson,
  group_number,
from 
  last_lesson_extract
left join
  mindful-hull-401711.schoolmaker.plan_programme_data_analyst_insider plan_programme_data_analyst_insider
on
lower(trim(last_lesson_extract.lesson))=lower(trim(plan_programme_data_analyst_insider.lesson))
where 
  last_lesson_extract.lesson is not null
and
  last_lesson_extract.programme = 'Data Analyst Insider'