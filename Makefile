PY := .venv/bin/python -I
DBT := DBT_PROFILES_DIR=. .venv/bin/dbt
.PHONY: all setup download load build explain clean
all: load build                                   ## needs data/raw (make download)
setup:
	python3 -m venv .venv && .venv/bin/pip install -q -r requirements.txt
download:
	./scripts/download.sh
load:
	$(PY) scripts/load.py
build:
	$(DBT) seed -q && $(DBT) build
explain:
	$(PY) scripts/explain.py "2019 Ram 1500"
clean:
	rm -rf target logs warehouse.duckdb*
