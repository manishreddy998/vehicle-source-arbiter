-- How much of each source the rules could place, measured on brands EPA covers (model years 2010 and later).
with epa_makes as (select distinct make_canonical from {{ ref('int_epa_models') }} where model_year >= 2010)
select n.source, n.status, count(*) as distinct_names, sum(n.n_records) as recall_rows
from {{ ref('int_name_resolution') }} n join epa_makes using (make_canonical)
where n.model_year >= 2010
group by 1, 2
