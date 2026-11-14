"""Land the three public sources exactly as published (all text), and record where each file came from.

Sources (download with scripts/download.sh):
  NHTSA recalls      data/raw/nhtsa/FLAT_RCL_POST_2010.txt   tab-delimited, no header, 29 fields (see RCL.txt)
  Transport Canada   data/raw/tc/vrdb_full_monthly.csv       Vehicle Recalls Database, CSV with header
  EPA fuel economy   data/raw/epa/vehicles.csv               one row per model variant per year

Every load writes raw_meta.source_files: file, sha256, bytes, rows, loaded_at. A value in this warehouse can always
be traced back to the exact file it came from.
"""
import hashlib, os, sys
from datetime import datetime, timezone
import duckdb

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RAW = os.path.join(ROOT, "data", "raw")
con = duckdb.connect(os.environ.get("DUCKDB_PATH", os.path.join(ROOT, "warehouse.duckdb")))
now = datetime.now(timezone.utc).isoformat()

NHTSA_FIELDS = ["record_id", "campno", "maketxt", "modeltxt", "yeartxt", "mfgcampno", "compname", "mfgname", "bgman",
                "endman", "rcltypecd", "potaff", "odate", "influenced_by", "mfgtxt", "rcdate", "datea", "rpno", "fmvss",
                "desc_defect", "consequence_defect", "corrective_action", "notes", "rcl_cmpt_id", "mfr_comp_name",
                "mfr_comp_desc", "mfr_comp_ptno", "do_not_drive", "park_outside"]
SOURCES = [
    ("raw_nhtsa", "recalls", "nhtsa/FLAT_RCL_POST_2010.txt",
     "read_csv(?, delim='\t', header=false, all_varchar=true, quote='', escape='', null_padding=true, "
     f"names={NHTSA_FIELDS!r})"),
    ("raw_tc", "recalls", "tc/vrdb_full_monthly.csv", "read_csv(?, header=true, all_varchar=true)"),
    ("raw_epa", "vehicles", "epa/vehicles.csv", "read_csv(?, header=true, all_varchar=true)"),
]


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


con.execute("create schema if not exists raw_meta")
con.execute("create table if not exists raw_meta.source_files (schema_name varchar, table_name varchar, file varchar, "
            "sha256 varchar, bytes bigint, row_count bigint, loaded_at varchar)")
for schema, table, rel, reader in SOURCES:
    path = os.path.join(RAW, rel)
    if not os.path.exists(path):
        sys.exit(f"missing {path}: run scripts/download.sh first")
    con.execute(f"create schema if not exists {schema}")
    con.execute(f"create or replace table {schema}.{table} as select *, ? as _source_file, ? as _loaded_at from {reader}",
                [rel, now, path])
    n = con.execute(f"select count(*) from {schema}.{table}").fetchall()[0][0]
    con.execute("delete from raw_meta.source_files where schema_name = ? and table_name = ?", [schema, table])
    con.execute("insert into raw_meta.source_files values (?, ?, ?, ?, ?, ?, ?)",
                [schema, table, rel, sha256(path), os.path.getsize(path), n, now])
    print(f"{schema}.{table:10s} {n:>9,} rows  <- {rel}")
