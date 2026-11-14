-- The same recall in both countries, with the rule that linked them and how far apart the filings were.
select l.*, ca.filed_on as ca_filed_on, us.filed_on as us_filed_on, ca.units_affected as ca_units, us.units_affected as us_units
from {{ ref('int_recall_links') }} l
join {{ ref('int_recalls') }} ca on ca.country = 'CA' and ca.recall_id = l.ca_recall_id
join {{ ref('int_recalls') }} us on us.country = 'US' and us.recall_id = l.us_campaign_id
