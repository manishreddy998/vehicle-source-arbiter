#!/usr/bin/env bash
# Download the three public sources. About 220 MB in total.
set -euo pipefail
cd "$(dirname "$0")/../data/raw"
mkdir -p nhtsa tc epa
curl -fsSL -o nhtsa/FLAT_RCL_POST_2010.zip https://static.nhtsa.gov/odi/ffdd/rcl/FLAT_RCL_POST_2010.zip
curl -fsSL -o nhtsa/RCL.txt https://static.nhtsa.gov/odi/ffdd/rcl/RCL.txt
curl -fsSL -o tc/vrdb_full_monthly.csv https://opendatatc.tc.canada.ca/vrdb_full_monthly.csv
curl -fsSL -o epa/vehicles.csv.zip https://www.fueleconomy.gov/feg/epadata/vehicles.csv.zip
unzip -o -q nhtsa/FLAT_RCL_POST_2010.zip -d nhtsa
unzip -o -q epa/vehicles.csv.zip -d epa
echo "downloaded: $(du -sh . | cut -f1)"
