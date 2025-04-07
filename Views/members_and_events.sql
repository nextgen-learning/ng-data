with requete_1 as (
  select 
    members_export.first_name,
    members_export.last_name,
    concat(members_export.first_name,' ', members_export.last_name) as full_name,
    email_du_membre,
    action,
    programme,
    espace,
    Dur__e_de_l_action as duree_action,
    PARSE_TIMESTAMP(
    '%A %d %B %Y %Hh%M',
    LOWER(
      REGEXP_REPLACE(
        REGEXP_REPLACE(
          fait_le,
          r'janvier|février|mars|avril|mai|juin|juillet|août|septembre|octobre|novembre|décembre',
          CASE
            WHEN REGEXP_CONTAINS(fait_le, r'janvier') THEN 'January'
            WHEN REGEXP_CONTAINS(fait_le, r'février') THEN 'February'
            WHEN REGEXP_CONTAINS(fait_le, r'mars') THEN 'March'
            WHEN REGEXP_CONTAINS(fait_le, r'avril') THEN 'April'
            WHEN REGEXP_CONTAINS(fait_le, r'mai') THEN 'May'
            WHEN REGEXP_CONTAINS(fait_le, r'juin') THEN 'June'
            WHEN REGEXP_CONTAINS(fait_le, r'juillet') THEN 'July'
            WHEN REGEXP_CONTAINS(fait_le, r'août') THEN 'August'
            WHEN REGEXP_CONTAINS(fait_le, r'septembre') THEN 'September'
            WHEN REGEXP_CONTAINS(fait_le, r'octobre') THEN 'October'
            WHEN REGEXP_CONTAINS(fait_le, r'novembre') THEN 'November'
            WHEN REGEXP_CONTAINS(fait_le, r'décembre') THEN 'December'
          END
        ),
          r'lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche',
          CASE
            WHEN REGEXP_CONTAINS(fait_le, r'lundi') THEN 'Monday'
            WHEN REGEXP_CONTAINS(fait_le, r'mardi') THEN 'Tuesday'
            WHEN REGEXP_CONTAINS(fait_le, r'mercredi') THEN 'Wednesday'
            WHEN REGEXP_CONTAINS(fait_le, r'jeudi') THEN 'Thursday'
            WHEN REGEXP_CONTAINS(fait_le, r'vendredi') THEN 'Friday'
            WHEN REGEXP_CONTAINS(fait_le, r'samedi') THEN 'Saturday'
            WHEN REGEXP_CONTAINS(fait_le, r'dimanche') THEN 'Sunday'
          END
        )
      ) 
  ) AS timestamp_connexion,
    numero_groupe as group_number,
    members_progression_rate/100 as members_progression_rate,
    members_progression_rate || ' %' as members_progression_percent,
    time_spent 
  FROM mindful-hull-401711.schoolmaker.members_events_export members_events_export
  left join mindful-hull-401711.schoolmaker.members_export members_export
  on members_events_export.email_du_membre = members_export.email
  left join mindful-hull-401711.schoolmaker.repartition_eleves_groupe repartition_eleves_groupe
  on members_events_export.email_du_membre = repartition_eleves_groupe.email
  left join mindful-hull-401711.schoolmaker.members_progression_data_analyst_insider members_progression_data_analyst_insider
  on members_events_export.email_du_membre = members_progression_data_analyst_insider.email
)

select 
  *,
  if(timestamp_diff(cast(current_date as date), cast(timestamp_connexion as date), day) <= 4, 'actif', 'à relancer') as suivi,
  cast(regexp_extract(time_spent, r'^\d+') as decimal) time_spent_int,
  date(timestamp_connexion) as last_connexion
from requete_1