with calendar_60_day as (
  select
    date
  from unnest(
    generate_date_array(current_date() - 60, current_date() -1, interval 1 day)
  ) as date
),

number_of_connexions as (
  select 
    date(timestamp_connexion) as date,
    full_name,
    group_number,
    programme,
    case 
      when trim(action) like 'Connexion' then 1 
      else 0 
    end as is_connexion,
    lag (programme) over (partition by full_name order by timestamp_connexion) as preceding_row_programme,
    lag (duree_action) over (partition by full_name order by timestamp_connexion) as preceding_row_duree_action
  from 
    `mindful-hull-401711.schoolmaker.members_and_events`
  order by 
    date desc, full_name
),

number_of_connexions_dai as (
  select 
    * 
  from 
    number_of_connexions 
  where 
    is_connexion = 1 
  and 
    preceding_row_programme = 'Data Analyst Insider'
  and 
    preceding_row_duree_action != '00:01:30'
  and
    preceding_row_duree_action is not null
),

users as (
  select 
    distinct full_name, group_number
  from 
    `mindful-hull-401711.schoolmaker.members_and_events`
),

number_of_connexion_per_user as (
  select 
    format_date('S-%V', number_of_connexions_dai.date) AS week,
    calendar_60_day.date,
    users.group_number,
    users.full_name,
    coalesce(sum(number_of_connexions_dai.is_connexion), 0) as total_connexions
  from 
    calendar_60_day
  cross join
    users
  left join
    number_of_connexions_dai 
  on
    calendar_60_day.date = number_of_connexions_dai.date 
  and 
    users.full_name = number_of_connexions_dai.full_name
  group by
    calendar_60_day.date, number_of_connexions_dai.date, users.full_name, users.group_number
  order by 
    calendar_60_day.date desc, users.full_name
),

if_connexion as (
  select
    *,
    if (total_connexions != 0, 1, 0) as binary_connexion
  from number_of_connexion_per_user
)

select
  format_date('S-%V', if_connexion.date) AS week,
  if_connexion.date,
  users.full_name,
  users.group_number /*modif ici*/,
  round((if (total_connexions != 0, 1,0)/7), 2) as connexion_per_week,
  if (coalesce(if_connexion.total_connexions, 0) != 0, 1, 0) as binary_connexion,
  (binary_connexion)/31 as percent
from 
  users
cross join 
  calendar_60_day
left join 
  if_connexion
on 
  users.full_name = if_connexion.full_name
and 
  users.group_number = if_connexion.group_number
and 
  calendar_60_day.date = if_connexion.date
order by 
  full_name, date desc