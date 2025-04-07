with calendar_60_day as (
  select
    date
  from unnest(
    generate_date_array(current_date() - 31, current_date() -1, interval 1 day)
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
    calendar_60_day.date desc, users.full_name
)

select
  users.full_name,
  users.group_number,
  number_of_connexion_per_user.date,
  coalesce(number_of_connexion_per_user.total_connexions, 0) as total_connexions,
  if (coalesce(number_of_connexion_per_user.total_connexions, 0) != 0, 1, 0) as binary_connexion
from users
cross join calendar_60_day
left join number_of_connexion_per_user
on users.full_name = number_of_connexion_per_user.full_name
and users.group_number = number_of_connexion_per_user.group_number
and calendar_60_day.date = number_of_connexion_per_user.date
order by date desc, full_name