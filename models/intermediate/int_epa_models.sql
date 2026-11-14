-- What EPA says exists: one row per make, model and year. A model is the EPA base model plus any variant token
-- that marks a different model (Hybrid, Classic, LD ...). Trims, drive types and engines are attributes, not models.
with noise as (select list(token) as tokens from {{ ref('model_tokens') }} where role = 'noise'),
variants as (select list(token) as tokens from {{ ref('model_tokens') }} where role = 'variant'),
v as (
    select e.*, coalesce(a.canonical_make, e.make_norm) as make_canonical,
           rules.model_core(e.base_model_raw, noise.tokens) as base_core,
           list_filter(rules.model_tokens(e.model_raw), lambda t: list_contains(variants.tokens, t)) as variant_tokens
    from {{ ref('stg_epa__vehicles') }} e
    cross join noise cross join variants
    left join {{ ref('make_aliases') }} a on a.alias = e.make_norm
)
select
    make_canonical, model_year,
    trim(base_core || ' ' || array_to_string(list_distinct(list_filter(variant_tokens, lambda t: not contains(base_core, t))), ' ')) as model_core,
    -- display name as the manufacturer certified it: the shortest EPA spelling of this model
    min_by(trim(base_model_raw || case when len(variant_tokens) > 0 and not contains(upper(base_model_raw), variant_tokens[1])
                                       then ' ' || {{ initcap_first("variant_tokens") }} else '' end), length(model_raw)) as epa_display_name,
    string_agg(distinct drive, ', ' order by drive)              as drive_types,
    string_agg(distinct fuel_type, ', ' order by fuel_type)      as fuel_types,
    string_agg(distinct vehicle_class, ', ' order by vehicle_class) as vehicle_classes,
    count(*)                                                     as epa_variants,
    string_agg(distinct model_raw, ' ; ' order by model_raw)     as epa_model_names
from v
where base_core is not null
group by 1, 2, 3
