-- Which vehicle model does each source name refer to? Ranked, written-down rules. A name can resolve to:
--   resolved     one model, by a named rule
--   ambiguous    more than one model is possible (e.g. "1500" in a year when both 1500 and 1500 Classic were sold)
--   not_in_epa   no EPA model (heavy duty pickups are not EPA rated), so the name becomes its own model, flagged
with names as (select * from {{ ref('int_names') }} where model_core is not null and model_year is not null),
epa as (select * from {{ ref('int_epa_models') }}),
generation_variants as (select token from {{ ref('model_tokens') }} where token in ('CLASSIC', 'LD')),
exact as (
    select n.*, e.model_core as target_core, 'exact_name' as rule, 0.98 as confidence
    from names n join epa e on e.make_canonical = n.make_canonical and e.model_year = n.model_year and e.model_core = n.model_core
),
series as (   -- "SILVERADO 1500" -> EPA "SILVERADO"
    select n.*, e.model_core, 'light_duty_series_dropped', 0.90
    from names n
    join {{ ref('light_duty_suffixes') }} s on n.model_core like '% ' || s.suffix
    join epa e on e.make_canonical = n.make_canonical and e.model_year = n.model_year
              and e.model_core = trim(left(n.model_core, length(n.model_core) - length(s.suffix)))
    where not exists (select 1 from exact x where x.source = n.source and x.make_norm = n.make_norm
                      and x.model_raw = n.model_raw and x.model_year = n.model_year)
),
generation as (   -- the plain name also fits a same-year generation variant: "1500" vs "1500 CLASSIC"
    select x.source, x.make_norm, x.model_raw, x.model_year, x.n_records, x.make_canonical, x.model_core, x.alias_reason,
           e.model_core, 'generation_ambiguous', 0.50
    from (select * from exact union all select * from series) x
    join epa e on e.make_canonical = x.make_canonical and e.model_year = x.model_year
    join generation_variants g on e.model_core = x.target_core || ' ' || g.token
),
grouped as (   -- "SILVERADO HD" -> 2500 and 3500
    select n.*, g.member, 'regulator_group_name', 0.85
    from names n join {{ ref('model_groups') }} g on g.make = n.make_canonical and g.group_name = n.model_core
),
matched as (select * from exact union all select * from series union all select * from generation union all select * from grouped),
unmatched as (
    select n.*, n.model_core, 'not_in_epa', 0.70
    from names n
    where not exists (select 1 from matched m where m.source = n.source and m.make_norm = n.make_norm
                      and m.model_raw = n.model_raw and m.model_year = n.model_year)
),
all_candidates as (select * from matched union all select * from unmatched)
select
    md5(c.make_canonical || '|' || c.target_core || '|' || c.model_year)  as vehicle_model_id,
    c.source, c.make_norm, c.model_raw, c.model_year, c.n_records, c.make_canonical, c.model_core as source_model_core,
    c.target_core, c.rule, c.confidence, c.alias_reason,
    case when count(*) over (partition by c.source, c.make_norm, c.model_raw, c.model_year) > 1 then 'ambiguous'
         when c.rule = 'not_in_epa' then 'not_in_epa'
         else 'resolved' end                                             as status,
    count(*) over (partition by c.source, c.make_norm, c.model_raw, c.model_year) as n_candidates
from all_candidates c
