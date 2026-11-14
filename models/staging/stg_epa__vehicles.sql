-- EPA certified vehicle variants. The EPA list is the best public record of which models exist in a given year,
-- but it does not cover everything: heavy duty pickups (2500 and up) are exempt from fuel economy labels.
select
    id                                       as epa_vehicle_id,
    cast(year as integer)                    as model_year,
    rules.norm_make(make)                    as make_norm,
    make                                     as make_raw,
    model                                    as model_raw,
    baseModel                                as base_model_raw,
    drive, fuelType1 as fuel_type, VClass as vehicle_class, trany as transmission,
    try_cast(cylinders as integer)           as cylinders,
    try_cast(displ as double)                as displacement_l,
    nullif(atvType, '')                      as alt_fuel_type
from {{ source('raw_epa', 'vehicles') }}
