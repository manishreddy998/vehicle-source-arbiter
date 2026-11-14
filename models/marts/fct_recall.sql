-- One row per recall per country. A US campaign and its Canadian twin are two rows, joined by fct_recall_link.
select
    r.country, r.recall_id, r.filed_on, r.mfr_code_raw as manufacturer_recall_code, r.filer,
    r.components_or_system, r.units_affected, r.summary, array_to_string(r.makes, ', ') as makes,
    case r.country
        when 'US' then (select count(*) from {{ ref('int_recall_links') }} l where l.us_campaign_id = r.recall_id and l.status <> 'ambiguous')
        else (select count(*) from {{ ref('int_recall_links') }} l where l.ca_recall_id = r.recall_id and l.status <> 'ambiguous')
    end as n_links
from {{ ref('int_recalls') }} r
