"""Explain what the record says about a vehicle, and why.

    python scripts/explain.py "2019 Ram 1500"
    python scripts/explain.py "2019 Dodge Ram"
    python scripts/explain.py "2020 Chevrolet Silverado HD"

The name rules are the same SQL functions and rule tables the dbt models use (rules.* in the warehouse), so this tool
cannot drift from the pipeline. When the name does not settle which model it is, every candidate is shown and nothing
is picked for you.
"""
import os, re, sys
import duckdb

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
con = duckdb.connect(os.environ.get("DUCKDB_PATH", os.path.join(ROOT, "warehouse.duckdb")), read_only=True)
q = lambda sql, *p: con.execute(sql, list(p)).fetchall()

text = " ".join(sys.argv[1:]).strip()
m = re.match(r"^\s*((?:19|20)\d\d)\s+(.+)$", text)
if not m:
    sys.exit('usage: explain.py "<year> <make> <model>", e.g. "2019 Ram 1500"')
year, rest = int(m.group(1)), m.group(2)

# make: the longest leading run of words that is a known make or alias
makes = {r[0] for r in q("select distinct make from marts.dim_vehicle_model")}
aliases = dict(q("select alias, canonical_make from rules.make_aliases"))
words = rest.split()
make, model_text = None, ""
for i in range(len(words), 0, -1):
    cand = q("select rules.norm_make(?)", " ".join(words[:i]))[0][0]
    cand = aliases.get(cand, cand)
    if cand in makes:
        make, model_text = cand, " ".join(words[i:])
        break
if not make:
    sys.exit(f"unknown make in {rest!r}")

core = q("""with n as (select list(token) as noise from rules.model_tokens where role = 'noise')
             select rules.model_core(?, n.noise) from n""", model_text)[0][0] or ""
steps = [f"normalized model name: {model_text!r} -> {core!r}"]
pat = q("select regexp_replace(?, pattern, replacement), reason from rules.pattern_rules where make = ? and regexp_matches(?, pattern)",
        core, make, core)
if pat:
    core = pat[0][0]; steps.append(f"pattern rule: {pat[0][1]} -> {core!r}")
ali = q("select canonical_make, canonical_model, reason from rules.model_aliases where make = ? and model_core = ? and ? between year_from and year_to",
        make, core, year)
if ali:
    make, core = ali[0][0], ali[0][1]; steps.append(f"alias: {ali[0][2]} -> {make} {core!r}")
if make == "DODGE" and core.startswith("RAM") and year >= 2011:
    make, core = "RAM", core[3:].strip(); steps.append("alias: Ram became its own brand from model year 2011 -> RAM " + repr(core))

def models(where, *p):
    return q(f"select vehicle_model_id, model_core from marts.dim_vehicle_model where make = ? and model_year = ? and {where}", make, year, *p)

cands, rule = [], None
if core:
    cands, rule = models("model_core = ?", core), "exact_name"
    if not cands:
        for s in [r[0] for r in q("select suffix from rules.light_duty_suffixes")]:
            if core.endswith(" " + s):
                cands, rule = models("model_core = ?", core[: -len(s) - 1]), "light_duty_series_dropped"
    if not cands:
        cands, rule = models("model_core in (select member from rules.model_groups where make = ? and group_name = ?)", make, core), "regulator_group_name"
    if cands:
        gen = models("model_core in (select ? || ' ' || token from rules.model_tokens where token in ('CLASSIC', 'LD'))", cands[0][1])
        if gen:
            cands, rule = cands + gen, "generation_ambiguous"
if not cands:   # the name is incomplete ("Dodge Ram"): show every model it could be, pick none
    cands, rule = models("(? = '' or model_core = ? or model_core like ? || ' %')", core, core, core), "partial_name"

print(f'\n"{text}"')
for s in steps:
    print(f"  {s}")
if not cands:
    print(f"  no {year} {make} model matches. Nothing is guessed.")
    sys.exit(0)
status = "resolved" if len(cands) == 1 else f"AMBIGUOUS: {len(cands)} models fit, none is picked"
print(f"  rule: {rule}  ->  {status}\n")

if len(cands) > 3:   # too many to detail: list them and ask for a fuller name
    for vid, _ in cands:
        d = q("select display_name, display_name_source, us_recalls, ca_recalls from marts.vehicle_record where vehicle_model_id = ?", vid)[0]
        print(f"  {make.title()} {d[0]:28} name from {d[1]:13} recalls US {d[2]:>3}  Canada {d[3]:>3}")
    print("\n  The name does not say which model. Add the model (e.g. 1500, 2500) to see its record.\n")
    sys.exit(0)

for vid, _ in cands:
    d = q("""select display_name, display_name_source, model_year, epa_certified, drive_types, fuel_types, vehicle_classes,
                    us_name, ca_name, us_recalls, ca_recalls, ca_recalls_linked_to_us, ca_only_recalls, recalls_possibly_applying
             from marts.vehicle_record where vehicle_model_id = ?""", vid)[0]
    print(f"  {make.title()} {d[0]} ({d[2]})")
    print(f"    name            {d[0]!r:28} source: {d[1]}")
    print(f"    names seen      US: {d[7] or '-'}   Canada: {d[8] or '-'}")
    for label, val in (("drive", d[4]), ("fuel", d[5]), ("class", d[6])):
        print(f"    {label:15} {(val or 'empty (no source has it)')[:60]:60} {'source: epa' if val else ''}")
    print(f"    recalls         US {d[9]}  Canada {d[10]} ({d[11]} with a US twin, {d[12]} Canada-only)"
          + (f", {d[13]} may apply (the source name fits more than one model)" if d[13] else ""))
    rows = q("""select distinct b.country, b.recall_id, r.filed_on, b.status, coalesce(left(r.components_or_system, 38), ''),
                       (select string_agg(case when b.country = 'CA' then l.us_campaign_id else l.ca_recall_id end || ' (' || l.rule || ')', ', ')
                        from marts.fct_recall_link l
                        where (b.country = 'CA' and l.ca_recall_id = b.recall_id) or (b.country = 'US' and l.us_campaign_id = b.recall_id))
                from marts.bridge_recall_vehicle b join marts.fct_recall r on r.country = b.country and r.recall_id = b.recall_id
                where b.vehicle_model_id = ? order by r.filed_on desc limit 6""", vid)
    for c, rid, filed, st, comp, link in rows:
        print(f"      {c} {rid:10} {filed}  {comp:38}  {('twin: ' + link) if link else 'no twin'}" + (f"  [{st}]" if st not in ('resolved',) else ""))
    print()
