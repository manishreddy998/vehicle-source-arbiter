-- Every distinct (source, make, model, year) name, normalized by the same SQL functions the explain tool uses.
with noise as (select list(token) as tokens from {{ ref('model_tokens') }} where role = 'noise'),
raw_names as (
    select 'us_nhtsa' as source, make_norm, model_raw, model_year, count(distinct us_campaign_id) as n_records
    from {{ ref('stg_nhtsa__recall_rows') }} group by 1, 2, 3, 4
    union all
    select 'ca_transport', make_norm, model_raw, model_year, count(distinct ca_recall_id)
    from {{ ref('stg_tc__recall_rows') }} group by 1, 2, 3, 4
),
normalized as (
    select r.*, coalesce(a.canonical_make, r.make_norm) as make_canonical,
           rules.model_core(r.model_raw, noise.tokens) as core
    from raw_names r
    cross join noise
    left join {{ ref('make_aliases') }} a on a.alias = r.make_norm
)
select
    n.source, n.make_norm, n.model_raw, n.model_year, n.n_records,
    coalesce(ma.canonical_make, n.make_canonical)                         as make_canonical,
    -- some filers repeat the make inside the model name ("RAM 1500" under make RAM)
    coalesce(ma.canonical_model,
             (select regexp_replace(n.core, pr.pattern, pr.replacement) from {{ ref('pattern_rules') }} pr
              where pr.make = n.make_canonical and regexp_matches(n.core, pr.pattern) limit 1),
             case when split_part(n.core, ' ', 1) = n.make_canonical and n.core like '% %'
                  then substr(n.core, length(n.make_canonical) + 2) else n.core end) as model_core,
    ma.reason                                                             as alias_reason
from normalized n
left join {{ ref('model_aliases') }} ma
  on ma.make = n.make_canonical and ma.model_core = n.core and n.model_year between ma.year_from and ma.year_to
