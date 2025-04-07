with calendar_60_day as (
  select
    date
  from unnest(
    generate_date_array(current_date() - 31, current_date(), interval 1 day)
  ) as date
),

number_of_connexions as (
  select 
    date(timestamp_connexion) as date,
    full_name,
    group_number,
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
    calendar_60_day.date,
    users.group_number,
    users.full_name,
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
),

if_connexion as (
  select
    *,
    if (total_connexions != 0, 1, 0) as binary_connexion
  from number_of_connexion_per_user
),

final_result as (
  select 
    full_name,
    group_number,
    (sum(binary_connexion)/31) as percent
  from if_connexion
  group by full_name, group_number
)

-- Jointure avec users pour s'assurer que tout le monde est inclus
select 
  distinct users.full_name,
  users.group_number,
  coalesce(final_result.percent, 0) as percent
from users
left join final_result
on users.full_name = final_result.full_name
where users.group_number is not null
order by percent