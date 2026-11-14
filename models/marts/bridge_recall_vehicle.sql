-- Which vehicle models each recall covers, and how that was decided.
-- A Canadian recall that is ambiguous between two generations inherits the answer from its linked US recall when
-- the US text named the generation: the manufacturer's US filing wins because it is the one that says it.
with rv as (select * from {{ ref('int_recall_vehicles') }}),
us_decided as (
    select l.ca_recall_id, v.make_canonical, v.model_year, v.model_core
    from {{ ref('int_recall_links') }} l
    join rv v on v.country = 'US' and v.recall_id = l.us_campaign_id and v.status = 'resolved_by_recall_text'
    where l.status = 'confirmed'
),
ca_ambiguous_with_answer as (
    select distinct v.recall_id, v.make_canonical, v.model_year
    from rv v join us_decided d on d.ca_recall_id = v.recall_id and d.make_canonical = v.make_canonical and d.model_year = v.model_year
    where v.country = 'CA' and v.status = 'ambiguous'
)
select v.country, v.recall_id, v.vehicle_model_id, v.make_canonical as make, v.model_core, v.model_year, v.source_model_name, v.rule,
    case when a.recall_id is not null then 'resolved_via_linked_us_recall' else v.status end as status,
    case when a.recall_id is not null then 0.90 else v.confidence end as confidence
from rv v
left join ca_ambiguous_with_answer a on a.recall_id = v.recall_id and a.make_canonical = v.make_canonical and a.model_year = v.model_year
-- drop the generation the linked US filing ruled out
where a.recall_id is null
   or exists (select 1 from us_decided d where d.ca_recall_id = v.recall_id and d.make_canonical = v.make_canonical
              and d.model_year = v.model_year and d.model_core = v.model_core)
