-- Real cases from the public data, checked by hand. Each row returned is a case the rules now get wrong.
with checks as (
    -- US recall 21V925000 says "2021 Ram 1500 Classic": it must not attach to the new-generation 2021 Ram 1500
    select '21V925000 covers 2021 Ram 1500 Classic only' as case_name,
           (select list_sort(list(model_core)) from {{ ref('bridge_recall_vehicle') }}
            where country = 'US' and recall_id = '21V925000' and make = 'RAM' and model_year = 2021 and model_core like '1500%')
           = ['1500 CLASSIC'] as ok
    union all
    -- same Cummins fuel pump recall in both countries, manufacturer code Z46, filed the same day
    select 'CA 2022303 is US 22V406000', exists (select 1 from {{ ref('fct_recall_link') }}
           where ca_recall_id = '2022303' and us_campaign_id = '22V406000' and status = 'confirmed')
    union all
    -- Bentley reuses the RE21 code series: the Canadian seat recall 2021445 is NOT the US stability-control recall 21V647000
    select 'Bentley RE21 series is not an id', not exists (select 1 from {{ ref('fct_recall_link') }}
           where ca_recall_id = '2021445' and us_campaign_id = '21V647000' and status = 'confirmed')
    union all
    -- US says "SILVERADO 1500", EPA says "Silverado"
    select 'US Silverado 1500 is EPA Silverado', exists (select 1 from {{ ref('int_name_resolution') }}
           where source = 'us_nhtsa' and model_raw = 'SILVERADO 1500' and model_year = 2020 and target_core = 'SILVERADO')
    union all
    -- Canada files Silverado HD; the US files 2500 and 3500
    select 'CA Silverado HD covers 2500 and 3500', (select count(distinct target_core) from {{ ref('int_name_resolution') }}
           where source = 'ca_transport' and model_raw = 'SILVERADO HD' and model_year = 2020) = 2
    union all
    -- F-250 SD (US) and F-250 SUPER DUTY (Canada) are one truck
    select 'F-250 SD = F-250 Super Duty', (select count(distinct vehicle_model_id) from {{ ref('int_name_resolution') }}
           where make_canonical = 'FORD' and model_year = 2020 and model_raw in ('F-250 SD', 'F-250 SUPER DUTY')) = 1
    union all
    -- US files Mercedes-Benz by engine variant (GLC 300), EPA by class (GLC-Class)
    select 'GLC 300 is GLC-Class', exists (select 1 from {{ ref('int_name_resolution') }}
           where source = 'us_nhtsa' and make_canonical = 'MERCEDES BENZ' and model_raw = 'GLC 300' and model_year = 2020 and target_core = 'GLCCLASS')
)
select case_name from checks where not coalesce(ok, false)
