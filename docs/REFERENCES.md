# Key references

All 82 sources the app uses are in `db/ZapWise_DB.xlsx` (Sources sheet) and in the app's Learn tab.
These are the ones behind the model. Publisher PDFs are not included in this package for copyright
reasons; download them through the DOI links (a school or public library can help with paywalled ones).

| ID | Reference | Used for |
|---|---|---|
| S01 | Simoneau C. (ed.) et al. (2010). Applicability of generally recognised diffusion models for the estimation of specific migration. JRC59476, EUR 24514 EN. | Piringer upper-bound diffusion coefficient, Crank solution |
| S78 | Huang L., Fantke P., Ernstoff A., Jolliet O. (2017). A quantitative property-property relationship for the internal diffusion coefficients of organic compounds in solid materials. Indoor Air 27(6):1128-1140. https://doi.org/10.1111/ina.12395 | Realistic diffusion coefficient (Eq. 5, Table 2) |
| S76 | Huang L., Jolliet O. (2019). A combined QPPR for estimating packaging-food and solid material-water partition coefficients of organic compounds. Sci Total Environ 658:493-500. https://doi.org/10.1016/j.scitotenv.2018.12.062 | Partition coefficient regression and its 1,881-row dataset (`ml/data/kpf/`) |
| S77 | Ernstoff A.S., Fantke P., Huang L., Jolliet O. (2017). High-throughput migration modelling for estimating exposure to chemicals in food packaging in screening and prioritization tools. Food Chem Toxicol 109(1):428-438. https://doi.org/10.1016/j.fct.2017.09.024 | Why K = 1 is not a universal worst case; EtOH-eq as the food proxy |
| S79 | Vaferi B. et al. (2025). Sci Rep 15, supplementary Table S1. https://doi.org/10.1038/s41598-025-92459-x | Same databank with gradient boosting predictions (comparison only) |
| S02 | Haldimann M. et al. (2013). Exposure to antimony from PET trays used in ready-to-eat meals. Food Addit Contam A 30(3):587-598. https://doi.org/10.1080/19440049.2012.751631 | Antimony diffusion in CPET (Arrhenius fit), validation V1-V3 |
| S05 | Moreira M.A. et al. (2014). Analysis of phthalate migration to food simulants in plastic containers during microwave operations. IJERPH 11(1):507-526. https://doi.org/10.3390/ijerph110100507 | Validation V4 |
| S07 | EFSA CEP Panel (2019). Update of the risk assessment of DBP, BBP, DEHP, DINP and DIDP for use in food contact materials. EFSA Journal 17(12):5838. | Phthalate group TDI 50 µg/kg bw/day |
| S08 | Commission Regulation (EU) 2023/1442 (group restriction 36). | DEHP-equivalent factors, 20 % allocation behind the bands |
| S81 | Commission Regulation (EU) No 10/2011, Annex III and V. | Food simulants used to anchor food EtOH-eq |
| S82 | BfR (2019). Do not use "bamboo ware" tableware for hot drinks and meals. Press release, 25 Nov 2019. https://www.bfr.bund.de/en/press-release/do-not-use-bamboo-ware-tableware-for-hot-drinks-and-meals/ | Melamine and bamboo-fibre dishes marked as not for microwave heating (added after the store photos) |

The supplementary files used to build the partition dataset are in `ml/data/kpf/` (CSV tables from the
Huang and Jolliet 2019 supplement and Table S1 of Vaferi et al. 2025, with attribution). Cite the papers
when you use them.
