# Where the matching gets it wrong, or cannot decide

Every case below is in the public data. Each one either goes to `reports.rpt_review_queue` or is left empty on purpose.

## 1. A name that fits two generations sold the same year
Both regulators write "RAM 1500" for 2019 to 2024, when Ram sold the new 1500 and the older 1500 Classic side by side.
EPA lists them as two models. Only the recall text can tell them apart: US 21V925000 says "2021 Ram 1500 Classic", so it
attaches to the Classic only. Canadian summaries almost never name the model ("On certain vehicles..."), so a Canadian
recall inherits the answer from its linked US filing when there is one. **378** Canadian and US recall-vehicle rows are
still ambiguous and stay attached to both, marked `ambiguous`. The same applies to Silverado 1500 LD in 2019 and 2022.

## 2. Manufacturer recall codes that are series, not ids
Bentley `RE21`, and short numeric codes like `09`, appear on several campaigns. A shared code is strong evidence only
when it is specific. Tokens under 3 characters and year-like tokens are dropped, and a code that is far apart in time or
matches several US campaigns also needs the systems to agree. **47** code links are held back for review because of this.

## 3. Codes with ranges
"U49,U59-U65,U68" lists a range. The range is not expanded, so a Canadian recall filed only as "U61" will not link by
code. It may still link by vehicle, date and system.

## 4. EPA base models that are too coarse
EPA files Range Rover Sport and Range Rover Velar under the base model "Range Rover". A recall for "RANGE ROVER SPORT"
does not resolve to an EPA model and becomes its own `not_in_epa` model. Treating SPORT as a model-defining word would
break other brands (Santa Fe Sport is a model, Civic Sport is a trim), so this needs a per-make rule, not a global one.

## 5. Vehicles EPA does not rate
Heavy duty pickups (Silverado 2500 and up, Ram 2500 and up, F-250 Super Duty), cab-chassis trucks and large vans have
no EPA record. They still get a record from the recall filings, and both countries' names line up (F-250 SD and F-250
Super Duty are one truck). Drive, fuel and class stay **empty**: no source has them, so nothing is filled in.

## 6. Group names one regulator uses
Transport Canada files "SILVERADO HD" where NHTSA files "SILVERADO 2500" and "SILVERADO 3500". The name maps to both,
marked ambiguous. New group names need a row in `seeds/model_groups.csv`.

## 7. Recalls with no twin
**827** Canadian recalls have no linked US recall even though the same make filed a US recall within 14 days. Some are
Canada-only (labels, bilingual manuals, Canadian-market vehicles), some are misses the rules cannot see because the
codes differ and the vehicle or system does not line up. They are listed for review, not linked.
