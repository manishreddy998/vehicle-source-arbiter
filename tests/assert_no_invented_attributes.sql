-- Drive, fuel and class come only from EPA. A model EPA has no record of must leave them empty, not guess.
select vehicle_model_id from {{ ref('dim_vehicle_model') }}
where not epa_certified and (drive_types is not null or fuel_types is not null or vehicle_classes is not null)
