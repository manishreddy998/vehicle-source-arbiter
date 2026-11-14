-- A US recall and a Canadian recall from different brands can never be the same recall.
select l.link_id
from {{ ref('int_recall_links') }} l
join {{ ref('int_recalls') }} ca on ca.country = 'CA' and ca.recall_id = l.ca_recall_id
join {{ ref('int_recalls') }} us on us.country = 'US' and us.recall_id = l.us_campaign_id
where len(list_intersect(ca.makes, us.makes)) = 0
