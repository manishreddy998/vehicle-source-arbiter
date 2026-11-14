-- One row per recall per country, with the vehicle models it names and its manufacturer recall code tokens.
with us as (
    select r.us_campaign_id as recall_id, 'US' as country, max(r.report_date) as filed_on, max(r.mfr_recall_code_raw) as mfr_code_raw,
           max(r.filer_name) as filer, max(r.components) as components_or_system, max(r.defect_summary) as summary,
           max(r.units_affected) as units_affected, list_distinct(list(n.make_canonical)) as makes,
           list_distinct(list(n.vehicle_model_id)) as vehicle_model_ids
    from {{ ref('stg_nhtsa__recall_rows') }} r
    join {{ ref('int_name_resolution') }} n on n.source = 'us_nhtsa' and n.make_norm = r.make_norm and n.model_raw = r.model_raw and n.model_year = r.model_year
    group by 1
),
ca as (
    select r.ca_recall_id, 'CA', max(r.recall_date), max(r.mfr_recall_code_raw), null, max(r.system_type), max(r.recall_summary),
           max(r.units_affected), list_distinct(list(n.make_canonical)), list_distinct(list(n.vehicle_model_id))
    from {{ ref('stg_tc__recall_rows') }} r
    join {{ ref('int_name_resolution') }} n on n.source = 'ca_transport' and n.make_norm = r.make_norm and n.model_raw = r.model_raw and n.model_year = r.model_year
    group by 1
)
select *, {{ recall_code_tokens('mfr_code_raw') }} as code_tokens from (select * from us union all select * from ca) x
