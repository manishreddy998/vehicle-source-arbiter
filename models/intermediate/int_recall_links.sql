-- Which US recall is the same recall as which Canadian one?
-- Rule 1 manufacturer_recall_code: same make, a shared manufacturer recall code, filed within {{ var('link_window_days') }} days.
--        More than 14 days apart, the systems must also agree, or the link goes to review.
-- Rule 2 same_vehicles_date_system: no shared code, but the same vehicle model and year, filed within
--        {{ var('fallback_window_days') }} days, with a compatible system. Weaker, so it is only used for recalls rule 1 left unlinked.
with us as (select * from {{ ref('int_recalls') }} where country = 'US'),
ca as (select * from {{ ref('int_recalls') }} where country = 'CA'),
code_pairs as (
    select ca.recall_id as ca_recall_id, us.recall_id as us_campaign_id, 'manufacturer_recall_code' as rule, 0.97 as confidence,
           abs(ca.filed_on - us.filed_on) as days_apart,
           array_to_string(list_intersect(ca.code_tokens, us.code_tokens), ',') as shared_codes,
           exists (select 1 from {{ ref('system_component_map') }} m
                   where m.ca_system_type = ca.components_or_system and contains(us.components_or_system, m.us_component_keyword)) as systems_agree
    from ca join us
      on len(list_intersect(ca.code_tokens, us.code_tokens)) > 0
     and len(list_intersect(ca.makes, us.makes)) > 0
     and abs(ca.filed_on - us.filed_on) <= {{ var('link_window_days') }}
),
fallback_pairs as (
    select ca.recall_id, us.recall_id, 'same_vehicles_date_system', 0.80, abs(ca.filed_on - us.filed_on), null, true
    from ca join us
      on len(list_intersect(ca.vehicle_model_ids, us.vehicle_model_ids)) > 0
     and abs(ca.filed_on - us.filed_on) <= {{ var('fallback_window_days') }}
    where not exists (select 1 from code_pairs c where c.ca_recall_id = ca.recall_id)
      and exists (select 1 from {{ ref('system_component_map') }} m
                  where m.ca_system_type = ca.components_or_system and contains(us.components_or_system, m.us_component_keyword))
),
pairs as (select * from code_pairs union all select * from fallback_pairs),
ranked as (
    select *,
        count(*) over (partition by ca_recall_id)   as us_matches_for_ca,
        count(*) over (partition by us_campaign_id) as ca_matches_for_us,
        row_number() over (partition by ca_recall_id order by confidence desc, days_apart, us_campaign_id) as rank_for_ca
    from pairs
)
select
    md5(ca_recall_id || '|' || us_campaign_id) as link_id, ca_recall_id, us_campaign_id, rule, confidence, days_apart, shared_codes,
    us_matches_for_ca, ca_matches_for_us,
    systems_agree,
    case when rule = 'same_vehicles_date_system' and (us_matches_for_ca > 1 or ca_matches_for_us > 1) then 'ambiguous'
         when rule = 'same_vehicles_date_system' then 'probable'
         -- manufacturers reuse code series (Bentley RE21 was two different defects 28 days apart):
         -- a shared code more than two weeks apart also needs the systems to agree
         when days_apart > 14 and not systems_agree then 'ambiguous'
         -- one Canadian recall sharing a code with several US campaigns: the code is a series, not an id. Systems must agree.
         when us_matches_for_ca > 1 and not systems_agree then 'ambiguous'
         else 'confirmed' end as status
from ranked
-- the fallback rule keeps only its single best candidate per Canadian recall
where rule = 'manufacturer_recall_code' or rank_for_ca = 1
