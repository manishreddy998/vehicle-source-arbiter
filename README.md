# vehicle-source-arbiter

[![build](https://github.com/manishreddy998/vehicle-source-arbiter/actions/workflows/build.yml/badge.svg)](https://github.com/manishreddy998/vehicle-source-arbiter/actions/workflows/build.yml)

**One record per vehicle, built from three public sources that disagree, with every value naming its source and every decision written down.**

US NHTSA recalls, Transport Canada recalls and EPA's vehicle list describe the same vehicles in different words. This project lands all three as published, decides which vehicle each name means, links each Canadian recall to its US twin, and keeps a review queue for what the rules cannot settle. Where no source has a value, the field stays empty.

```bash
make setup && make download && make all     # ~220 MB of public data, then 12 tests
.venv/bin/python -I scripts/explain.py "2019 Ram 1500"
```

## The problem, from the real files

| | US (NHTSA) | Canada (Transport Canada) | EPA |
|---|---|---|---|
| 2019 Ram pickup | `RAM 1500` | `RAM 1500` | `1500` **and** `1500 Classic`, two different generations |
| 2020 Silverado | `SILVERADO 1500` | `SILVERADO` | `Silverado` |
| 2020 heavy duty Silverado | `SILVERADO 2500`, `SILVERADO 3500` | `SILVERADO HD` | not rated by EPA |
| 2020 Ford F-250 | `F-250 SD` | `F-250 SUPER DUTY` | not rated by EPA |
| 2021 Mercedes-Benz GLC | `GLC 300`, `AMG GLC43` | `GLC-CLASS` | `GLC-Class` |
| Same Cummins fuel pump recall | 22V406000, code `Z46`, Jun 9 2022 | 2022303, code `Z46`, Jun 9 2022 | |

Both regulators write "RAM 1500" for model years when Ram sold two different trucks under that name. Only the recall's own text says which one: US recall 21V925000 reads *"2021 Ram 1500 Classic"*, so it attaches to the Classic and not the new 1500.

## What it decides, and how

**Which vehicle a name means** (`int_name_resolution`). Ranked rules, each with a name and a confidence:

| Rule | Example | Confidence |
|---|---|---:|
| `exact_name` after normalization | `CR-V AWD` = `CRV` | 0.98 |
| `light_duty_series_dropped` | `SILVERADO 1500` = EPA `Silverado` | 0.90 |
| `regulator_group_name` | Canada `SILVERADO HD` = 2500 + 3500 | 0.85, ambiguous |
| `generation_ambiguous` | `1500` in 2019 to 2024 = 1500 or 1500 Classic | 0.50 until text decides |
| `not_in_epa` | `SILVERADO 2500` gets its own record, attributes empty | 0.70 |

Normalization is a handful of SQL functions created in the warehouse (`macros/name_functions.sql`): hyphens inside names are dropped (F-150 = F150), and noise words (drive, cab, body, engine) are removed using `seeds/model_tokens.csv`, where every token has a reason. Renames that depend on the year or the make live in seeds too: Dodge Ram became Ram in model year 2011, and US filings name Mercedes-Benz engine variants (C 300) where Canada and EPA name the class (C-Class).

**Which source wins** for each field of the record (`dim_vehicle_model`):

| Field | Order | Why |
|---|---|---|
| Name | EPA, then the US filing, then Transport Canada | EPA's list is the manufacturer-certified spelling (`1500 Classic`). Both recall files drop "Classic". |
| Drive, fuel, vehicle class | EPA only | Recall files don't carry them. If EPA has no record, the field stays **empty**. |
| Which recalls apply | each country's own filing, then the recall text, then the linked recall in the other country | A Canadian summary rarely names the model, so a confirmed US twin that does name it decides for both. |

**Which US recall is the Canadian one** (`int_recall_links`):

1. `manufacturer_recall_code`: same brand, a shared manufacturer recall code, filed within 120 days. Codes are tokenized ("Y55 & Y63", "SRC XC8/XC9", "12 89 25RC"). Short and year-like tokens are dropped. If the filings are more than 14 days apart, or the code matches several US campaigns, the systems must also agree, or the link goes to review.
2. `same_vehicles_date_system`: no shared code, but the same vehicle model and year, filed within 21 days, with a compatible system (`seeds/system_component_map.csv`). One best candidate only. Several candidates means review.

## Results on the current files

- **446,171** raw rows: 248,196 NHTSA, 147,328 Transport Canada, 50,647 EPA. Every load records each file's SHA-256, size and row count in `raw_meta.source_files`.
- **48,812** vehicle-model-year records, 12,725 of them EPA certified.
- **3,388 of 4,624** Canadian light-vehicle recalls since 2010 (73%) are linked to a US twin: 2,407 by manufacturer code, 1,001 by vehicle, date and system. 195 more links are held for review instead of guessed.
- On brands EPA covers, **61%** of US and **71%** of Canadian recall rows resolve to an EPA model. Most of the rest are vehicles EPA does not rate (heavy duty pickups, cab-chassis, large vans). They still get records, just without EPA attributes.
- **Hand check:** a random sample of 30 links read side by side: 28 the same recall, 1 likely, 1 wrong. The wrong one (a Bentley code series) led to the stricter code rule above. See [docs/spot_check.md](docs/spot_check.md).
- **12 tests pass**, one of which holds 7 real cases checked by hand (`tests/assert_golden_cases.sql`): the Ram 1500 Classic recall, the Z46 twins, Silverado 1500 vs Silverado, Silverado HD, F-250 SD vs Super Duty, GLC 300 vs GLC-Class, and the Bentley series that must *not* link. A link can never join two different brands, and no EPA attribute can appear on a vehicle EPA has no record of.

## Where it fails

[docs/where_matching_fails.md](docs/where_matching_fails.md) lists the cases the rules get wrong or cannot decide, with real examples: generations sold side by side, code series, code ranges, EPA base models that are too coarse (Range Rover Sport), group names, and 827 Canadian recalls with no twin found. Each one lands in `reports.rpt_review_queue` with a reason.

## Explain a record

```
$ python scripts/explain.py "2019 Ram 1500"
  rule: generation_ambiguous  ->  AMBIGUOUS: 2 models fit, none is picked

  Ram 1500 (2019)
    name            '1500'                       source: epa
    names seen      US: 1500   Canada: 1500
    drive           4-Wheel Drive, Rear-Wheel Drive          source: epa
    recalls         US 27  Canada 19 (17 with a US twin, 2 Canada-only), 2 may apply
      CA 2026371    2026-07-30  Seats And Restraints   twin: 26V495000 (manufacturer_recall_code)  [resolved_via_linked_us_recall]
      US 26V495000  2026-07-30  SEAT BELTS:REAR/OTHER  twin: 2026371 (manufacturer_recall_code)    [resolved_by_recall_text]
  Ram 1500 Classic (2019)
    ...
```

`"2019 Dodge Ram"` lists all eight 2019 Ram models it could be and picks none. `"2020 Chevrolet Silverado HD"` shows the 2500 and the 3500.

## Layout

```
scripts/download.sh, load.py   fetch and land the three files as published, with SHA-256 and row counts
macros/name_functions.sql      the name rules, created as SQL functions used by dbt and by explain.py
seeds/                         every rule table: noise tokens, make aliases, year-bounded renames, group names, system map
models/staging/                one row per recall x make x model x year, per source
models/intermediate/           names, EPA models, name resolution, recalls, cross-border links, recall-vehicle decisions
models/marts/                  dim_vehicle_model, vehicle_record, fct_recall, fct_recall_link, bridge_recall_vehicle
models/reports/                rpt_review_queue, rpt_coverage
tests/                         real golden cases, no cross-brand links, no invented attributes
```

Built with SQL on DuckDB (dbt). The rule tables and the logic carry over to Postgres. The list functions used for code tokens would become arrays and `unnest` there.

---

Built by Manish Reddy, Data/AI Engineer in Toronto. [LinkedIn](https://www.linkedin.com/in/manish-re-50c02a719k/) · [GitHub](https://github.com/manishreddy998)
