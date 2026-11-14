-- US recalls, light vehicles only (record type V). One row per campaign, make, model and model year.
-- The raw file repeats a row per recalled component, so components are collected into a list.
select
    campno                                                          as us_campaign_id,
    rules.norm_make(maketxt)                                        as make_norm,
    maketxt                                                         as make_raw,
    modeltxt                                                        as model_raw,
    nullif(try_cast(yeartxt as integer), 9999)                      as model_year,
    max(mfgcampno)                                                  as mfr_recall_code_raw,
    max(mfgname)                                                    as filer_name,
    max(try_strptime(rcdate, '%Y%m%d'))::date                       as report_date,
    max(try_cast(potaff as bigint))                                 as units_affected,
    string_agg(distinct compname, ' | ')                            as components,
    max(desc_defect)                                                as defect_summary,
    max(do_not_drive) = 'Yes'                                       as do_not_drive
from {{ source('raw_nhtsa', 'recalls') }}
where rcltypecd = 'V' and campno is not null and maketxt is not null and modeltxt is not null
group by 1, 2, 3, 4, 5
