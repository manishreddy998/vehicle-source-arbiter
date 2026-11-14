-- The record per vehicle model and year: what it is (with the source of each field) and what has happened to it.
with b as (select * from {{ ref('bridge_recall_vehicle') }}),
counts as (
    select vehicle_model_id,
        count(distinct case when country = 'US' then recall_id end)                       as us_recalls,
        count(distinct case when country = 'CA' then recall_id end)                       as ca_recalls,
        count(distinct case when status in ('ambiguous') then country || recall_id end)   as recalls_possibly_applying
    from b group by 1
),
linked as (
    select b.vehicle_model_id, count(distinct l.ca_recall_id) as ca_recalls_linked_to_us
    from b join {{ ref('int_recall_links') }} l on b.country = 'CA' and l.ca_recall_id = b.recall_id and l.status <> 'ambiguous'
    group by 1
)
select d.*, coalesce(c.us_recalls, 0) as us_recalls, coalesce(c.ca_recalls, 0) as ca_recalls,
       coalesce(l.ca_recalls_linked_to_us, 0) as ca_recalls_linked_to_us,
       coalesce(c.ca_recalls, 0) - coalesce(l.ca_recalls_linked_to_us, 0) as ca_only_recalls,
       coalesce(c.recalls_possibly_applying, 0) as recalls_possibly_applying
from {{ ref('dim_vehicle_model') }} d
left join counts c using (vehicle_model_id)
left join linked l using (vehicle_model_id)
