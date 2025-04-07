with calendar_60_day as (
  select
    date
  from unnest(
    generate_date_array(current_date() - 60, current_date(), interval 1 day)
  ) as date
),

number_of_connexions as (
  select 
    date(timestamp_connexion) as date,
    full_name,
    group_number,
    -- Compter une connexion uniquement si 'action' contient le mot 'Connexion'
    case 
      when trim(action) like 'Connexion' then 1 
      else 0 
    end as is_connexion
  from 
    `mindful-hull-401711.schoolmaker.members_and_events` 
),

users as (
  select distinct full_name, group_number
  from `mindful-hull-401711.schoolmaker.members_and_events`
),

number_of_connexion_per_user as (
  select 
    calendar_60_day.date as date,
    users.full_name as full_name,
    users.group_number as group_number,
    coalesce(sum(number_of_connexions.is_connexion), 0) as total_connexions
  from 
    calendar_60_day
  cross join
    users
  left join
    number_of_connexions 
  on
    calendar_60_day.date = number_of_connexions.date 
    and users.full_name = number_of_connexions.full_name
  group by
    calendar_60_day.date, users.full_name, users.group_number
  order by 
    calendar_60_day.date, users.full_name
)

select
  format_date('S-%V', date) AS week,
  full_name,
  group_number,
  round((sum(if (total_connexions != 0, 1,0))/7), 2) as connexion_per_week
from number_of_connexion_per_user
group by 
  week,
  full_name,
  group_number
order by 
  group_number, week, full_name