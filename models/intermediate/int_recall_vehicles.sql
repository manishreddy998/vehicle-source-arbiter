-- Which vehicle models does each recall cover? When a name is ambiguous between two generations sold the same year
-- ("1500" vs "1500 Classic"), the recall's own text decides. If the text does not say, both stay, marked ambiguous.
with rows as (
    select 'US' as country, us_campaign_id as recall_id, 'us_nhtsa' as source, make_norm, model_raw, model_year, defect_summary as summary
    from {{ ref('stg_nhtsa__recall_rows') }}
    union all
    select 'CA', ca_recall_id, 'ca_transport', make_norm, model_raw, model_year, recall_summary from {{ ref('stg_tc__recall_rows') }}
),
cands as (
    select r.country, r.recall_id, r.model_raw, r.model_year, upper(coalesce(r.summary, '')) as text,
           n.vehicle_model_id, n.make_canonical, n.target_core, n.source_model_core, n.rule, n.confidence, n.status
    from rows r
    join {{ ref('int_name_resolution') }} n
      on n.source = r.source and n.make_norm = r.make_norm and n.model_raw = r.model_raw and n.model_year = r.model_year
),
gen as (   -- for generation-ambiguous names, what does the recall text mention?
    select c.*,
        max(case when c.rule = 'generation_ambiguous' then c.target_core end) over w as variant_core,
        max(case when c.rule <> 'generation_ambiguous' then c.target_core end) over w as base_core,
        bool_or(c.rule = 'generation_ambiguous') over w as has_generation_choice
    from cands c
    window w as (partition by c.country, c.recall_id, c.model_raw, c.model_year)
),
decided as (
    select g.*,
        has_generation_choice and contains(text, variant_core)                                   as text_names_variant,
        has_generation_choice and contains(replace(text, variant_core, ''), base_core)            as text_names_base
    from gen g
)
select
    country, recall_id, vehicle_model_id, make_canonical, target_core as model_core, model_year, model_raw as source_model_name,
    rule,
    case
        when not has_generation_choice then status
        when not text_names_variant and not text_names_base then 'ambiguous'
        else 'resolved_by_recall_text'
    end as status,
    case when has_generation_choice and (text_names_variant or text_names_base) then 0.92 else confidence end as confidence
from decided
where not has_generation_choice
   or (not text_names_variant and not text_names_base)
   or (target_core = variant_core and text_names_variant)
   or (target_core = base_core and text_names_base)
