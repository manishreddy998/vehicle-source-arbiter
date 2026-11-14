-- Everything a person should look at, one row per item, with the reason. Nothing here is guessed into the record.
with items as (
    select 'generation_still_ambiguous' as issue, 'medium' as severity, b.country || ':' || b.recall_id as entity,
           b.make || ' ' || b.source_model_name || ' ' || b.model_year as subject,
           'Name fits two generations sold the same year and neither the recall text nor a linked recall says which' as reason
    from {{ ref('bridge_recall_vehicle') }} b where b.status = 'ambiguous'
    union all
    select 'link_needs_review', 'medium', l.ca_recall_id || '~' || l.us_campaign_id, l.shared_codes,
           case when l.rule = 'manufacturer_recall_code' then 'Shared code, but filed ' || l.days_apart || ' days apart and the systems differ'
                else 'Only date, vehicle and system agree, and more than one candidate fits' end
    from {{ ref('int_recall_links') }} l where l.status = 'ambiguous'
    union all
    select 'code_link_far_apart', 'low', l.ca_recall_id || '~' || l.us_campaign_id, l.shared_codes,
           'Shared manufacturer code, but filed ' || l.days_apart || ' days apart. Codes get reused'
    from {{ ref('int_recall_links') }} l where l.rule = 'manufacturer_recall_code' and l.days_apart > 60
    union all
    select 'one_code_many_campaigns', 'low', l.ca_recall_id, l.shared_codes,
           'One Canadian recall shares its code with ' || l.us_matches_for_ca || ' US campaigns'
    from {{ ref('int_recall_links') }} l where l.rule = 'manufacturer_recall_code' and l.us_matches_for_ca > 1 and l.us_campaign_id = (select min(x.us_campaign_id) from {{ ref("int_recall_links") }} x where x.ca_recall_id = l.ca_recall_id)
    union all
    select 'possible_missed_link', 'low', 'CA:' || ca.recall_id, array_to_string(ca.makes, ','),
           'No US twin found, but the same make filed a US recall within 14 days'
    from {{ ref('int_recalls') }} ca
    where ca.country = 'CA'
      and not exists (select 1 from {{ ref('int_recall_links') }} l where l.ca_recall_id = ca.recall_id)
      and exists (select 1 from {{ ref('int_recalls') }} us where us.country = 'US'
                  and len(list_intersect(us.makes, ca.makes)) > 0 and abs(us.filed_on - ca.filed_on) <= 14)
)
select md5(issue || entity) as item_id, * from items
