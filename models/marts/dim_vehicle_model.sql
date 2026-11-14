-- One record per make, model and model year. Every attribute names its source. Fields no source has stay empty.
with ids as (
    select distinct vehicle_model_id, make_canonical, target_core as model_core, model_year from {{ ref('int_name_resolution') }}
    union
    select md5(make_canonical || '|' || model_core || '|' || model_year), make_canonical, model_core, model_year
    from {{ ref('int_epa_models') }}
),
seen as (
    select vehicle_model_id,
           max(case when source = 'us_nhtsa' then model_raw end)     as us_name,
           max(case when source = 'ca_transport' then model_raw end) as ca_name
    from {{ ref('int_name_resolution') }} group by 1
)
select
    i.vehicle_model_id, i.make_canonical as make, i.model_core, i.model_year,
    coalesce(e.epa_display_name, s.us_name, s.ca_name, i.model_core)            as display_name,
    case when e.epa_display_name is not null then 'epa'
         when s.us_name is not null then 'us_nhtsa'
         when s.ca_name is not null then 'ca_transport' else 'derived' end         as display_name_source,
    e.model_core is not null                                                       as epa_certified,
    e.drive_types, e.fuel_types, e.vehicle_classes,                                -- EPA only. Empty when EPA has no record.
    case when e.model_core is not null then 'epa' end                              as attributes_source,
    e.epa_model_names, s.us_name, s.ca_name
from ids i
left join {{ ref('int_epa_models') }} e on e.make_canonical = i.make_canonical and e.model_core = i.model_core and e.model_year = i.model_year
left join seen s on s.vehicle_model_id = i.vehicle_model_id
