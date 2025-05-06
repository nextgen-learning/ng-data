WITH donnees as (
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
  where 
    -- On ne veut que les actions de consultation des leçons du programe Data Analyst Insider de semaine ou moins
    action like 'Consultation de la leçon%'
    and programme = 'Data Analyst Insider'
    and cast(timestamp_connexion as date) > current_date - 7
    -- FILTRE : action de plus de 1m30
    and duree_action > time(00,01,30)
    -- FILTRE : Action différente de 1h (temps avant déconnexion)
    -- and duree_action != time(01,00,00)
    -- DEBUG : Filtre sur une personne
    -- and full_name like '%Abdel%' 
),
-- On découpe le ord avec le num de la section et le num de la lesson pour pouvoir faire un tri sur les 2 int et non en float 
donnees_with_section_and_lesson_number as (
    select 
      *,
      cast(split(cast(ord as STRING), '.')[0] as INT64) as section_number,
      cast(split(cast(ord as STRING), '.')[1] as INT64) as lesson_number
    from donnees
),
-- On ajoute un rang pour toutes les lignes par personnes, le premier rang correspond à la leçon max qu'ils ont consulté ect.
donnees_with_ranking as (
    select 
    -- On reprend les colonnes de base mais on supprime section_number et lesson_number qui ne sont la que pour le tri
      full_name,
      date,
      programme,
      lesson,
      duree_action,
      timestamp_connexion,
      group_number,
      ord,
      ROW_NUMBER() OVER (PARTITION BY full_name ORDER BY section_number DESC, lesson_number DESC) AS rang
    from donnees_with_section_and_lesson_number
),
-- Ici on ne garde que la dernière leçon qui n'est pas trop éloigné de la précédente
last_lesson as (
    -- On parcourt les rangs jusqu’à trouver deux ord consécutifs avec écart <= 1
    select 
      *
    from donnees_with_ranking o
    -- Premier filtre pour n'avoir que les lignes qui se suivent (par le rang : défini par l'ord) avec une différence d'ord de inférieur ou égale à 1
    where exists (
        select 1
        from donnees_with_ranking o2
        -- Pour une même personne
        where o2.full_name = o.full_name
          -- Pour le rang suivant
          and o2.rang = o.rang + 1
          -- Qui a un écart de 1 ou moins dans les lecon
          and o.ord - o2.ord <= 1
    )
    -- Dans les lignes séléctionnées via le premier filtre (c'est pour ça qu'on reproduit le même filtre après le FROM)
    -- On ne veut que le rang minimal (le premier), on utilise donc MIN(rang) parmi les même données que précédemment
    and o.rang = (
        select min(rang)
        from donnees_with_ranking o3
        where o3.full_name = o.full_name
          and exists (
              select 1
              from donnees_with_ranking o4
              where o4.full_name = o3.full_name
                and o4.rang = o3.rang + 1
                and o3.ord - o4.ord <= 1
          )
    )
)
select 
  full_name,
  date,
  last_lesson.programme,
  plan_programme_data_analyst_insider.section,
  last_lesson.lesson,
  group_number,
FROM last_lesson
left join mindful-hull-401711.schoolmaker.plan_programme_data_analyst_insider plan_programme_data_analyst_insider
  on lower(trim(last_lesson.lesson)) = lower(trim(plan_programme_data_analyst_insider.lesson))
