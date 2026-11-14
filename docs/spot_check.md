# Hand check of recall links

A fixed random sample (ordered by a hash of the link id) of 15 links per rule, read side by side: the Transport Canada
summary against the NHTSA summary. Checked Nov 14, 2026.

| Rule | Sampled | Same recall | Wrong | Unsure |
|---|---:|---:|---:|---:|
| manufacturer_recall_code | 15 | 14 | 1 | 0 |
| same_vehicles_date_system | 15 | 14 | 0 | 1 |

**The wrong one:** Canadian recall 2021445 (front seats keep moving and can trap a rear passenger's legs) was linked to
US 21V647000 (stability control software) because both carry Bentley code `RE21`. Bentley codes are a series: `RE21`
is a prefix shared by several 2021 campaigns. Fix, now in the rules: a shared code more than 14 days apart, or a code
that matches more than one US campaign, also needs the Canadian system type and the US component to agree. Otherwise
the link goes to the review queue. A test (`assert_golden_cases`) keeps it fixed.

**The unsure one:** Canadian 2017642 (door lock, CMVSS 206) and US 17V816000 (Mercedes-Benz GLE/GLS, 2017). The US
summary in the file is cut before the defect, so the pair is likely but not proven from the text alone.

Code links checked: GM brake vacuum pump (N202300860), Audi A6 airbag inflator (69U1), Lincoln MKZ daytime running
lights (15C02), Jaguar F-TYPE occupant classification (H208), Subaru Outback occupant detection (WRA24), Jeep Liberty
wiper motor (K24), Nissan Frontier/Titan parking pawl (R22A1), Ford Transit brake pushrod (26C07), Bentley Bentayga
load label (RE2609), Audi Q6 e-tron camera (90XM), Lincoln Nautilus lane centering (19S02), GM rear axle shafts
(N212351030), Ram 1500 coolant bypass valve (N25), Porsche owner's manual child seat (AKC0).

Fallback links checked: Lexus 5.0L fuel pump cover, BMW X3 spoiler, BMW X5 rear door locks, Genesis fuel pipe nuts,
Hyundai Venue seat belt pretensioners, Tesla Model X steering bolts, Mercedes-Benz G-Class steering coupling, Kia EV9
remote parking, Nissan Z bumper fasteners, Mercedes-Benz Metris driveshaft, Acura RDX/CR-V Hybrid driveshaft, Hyundai
Azera ABS module, Nissan Sentra battery terminal, Nissan Juke fuel pressure sensor.
