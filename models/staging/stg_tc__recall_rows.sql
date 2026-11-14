-- Canadian recalls since 2010, light vehicles only. One row per recall, make, model and model year.
select
    RECALL_NUMBER_NUM                                               as ca_recall_id,
    rules.norm_make(MAKE_NAME_NM)                                   as make_norm,
    MAKE_NAME_NM                                                    as make_raw,
    MODEL_NAME_NM                                                   as model_raw,
    nullif(try_cast(try_cast(YEAR as double) as integer), 9999)     as model_year,
    max(MANUFACTURER_RECALL_NO_TXT)                                 as mfr_recall_code_raw,
    max(CATEGORY_ETXT)                                              as category,
    max(cast(RECALL_DATE_DTE as date))                              as recall_date,
    max(try_cast(try_cast(UNIT_AFFECTED_NBR as double) as bigint))  as units_affected,
    max(SYSTEM_TYPE_ETXT)                                           as system_type,
    max(NOTIFICATION_TYPE_ETXT)                                     as notification_type,
    max(COMMENT_ETXT)                                               as recall_summary
from {{ source('raw_tc', 'recalls') }}
where CATEGORY_ETXT in ('Car', 'SUV', 'Light Truck & Van', 'Minivan')
  and cast(RECALL_DATE_DTE as date) >= date '2010-01-01'
  and MAKE_NAME_NM is not null and MODEL_NAME_NM is not null
group by 1, 2, 3, 4, 5
