# Data Sources Guide

## Overview

All data used in this project is publicly available from the **Centers for Medicare & Medicaid Services (CMS)** via the [CMS Provider Data Catalog](https://data.cms.gov/provider-data). No Protected Health Information (PHI) is used or stored.

---

## Dataset 1 - CMS Hospital General Information

| Field | Detail |
|---|---|
| **Name** | Hospital General Information |
| **Source** | CMS Provider Data Catalog |
| **URL** | https://data.cms.gov/provider-data/dataset/xubh-q36u |
| **Format** | CSV |
| **Frequency** | Updated quarterly |
| **Rows** | ~5,000 hospitals |
| **Target Table** | `staging.cms_hospital` → `core.dim_hospital` |

### Key Fields Used
- `Facility ID` - unique CMS provider number (maps to all other datasets)
- `Facility Name`, `City`, `State`, `ZIP Code`
- `Hospital Type` - Acute Care, Critical Access, Children's, etc.
- `Hospital Ownership` - Government, Non-profit, Proprietary
- `Hospital overall rating` - 1–5 star overall CMS rating
- Group comparison fields: `Mortality national comparison`, `Safety of care national comparison`, etc.

### Download Steps
1. Go to https://data.cms.gov/provider-data/dataset/xubh-q36u
2. Click **Export** → **CSV**
3. Save as `data/cms_hospital_general.csv`
4. Load: `\COPY staging.cms_hospital FROM 'data/cms_hospital_general.csv' CSV HEADER;`

---

## Dataset 2 — Hospital Readmissions Reduction Program (HRRP)

| Field | Detail |
|---|---|
| **Name** | Hospital Readmissions Reduction Program |
| **Source** | CMS Provider Data Catalog |
| **URL** | https://data.cms.gov/provider-data/dataset/9n3s-kdb3 |
| **Format** | CSV |
| **Frequency** | Annual (fiscal year) |
| **Rows** | ~25,000 records (6 conditions × ~4,000+ hospitals) |
| **Target Table** | `staging.readmissions` → `core.fact_readmissions` |

### Conditions Covered
- Acute Myocardial Infarction (Heart Attack)
- Heart Failure
- Pneumonia
- COPD (Chronic Obstructive Pulmonary Disease)
- Hip/Knee Arthroplasty
- CABG (Coronary Artery Bypass Graft Surgery)

### Key Fields Used
- `Number of Discharges` - denominator for readmission rate calculation
- `Number of Readmissions` - 30-day all-cause readmissions
- `Excess Readmission Ratio` - actual vs expected (> 1.0 = worse than expected)
- `Predicted Readmission Rate` - risk-adjusted predicted rate
- `Expected Readmission Rate` - national baseline for comparison

### Download Steps
1. Go to https://data.cms.gov/provider-data/dataset/9n3s-kdb3
2. Click **Export** → **CSV**
3. Save as `data/readmissions.csv`
4. Load: `\COPY staging.readmissions FROM 'data/readmissions.csv' CSV HEADER;`

---

## Dataset 3 - HCAHPS Patient Survey (Patient Satisfaction)

| Field | Detail |
|---|---|
| **Name** | HCAHPS — Hospital Consumer Assessment of Healthcare Providers and Systems |
| **Source** | CMS Provider Data Catalog |
| **URL** | https://data.cms.gov/provider-data/dataset/dgck-syfz |
| **Format** | CSV |
| **Frequency** | Annual |
| **Rows** | ~100,000+ records (multiple survey questions per hospital) |
| **Target Table** | `staging.hcahps` → `core.fact_patient_satisfaction` |

### Survey Domains Covered
- Communication with Nurses
- Communication with Doctors
- Responsiveness of Hospital Staff
- Communication about Medicines
- Cleanliness of Hospital Environment
- Quietness of Hospital Environment
- Overall Hospital Rating (0–10 scale → star rating)
- Likelihood to Recommend Hospital

### Key Fields Used
- `HCAHPS Measure ID` — standardized measure code (e.g., H-COMP-1-A-P)
- `Patient Survey Star Rating` — 1–5 stars
- `HCAHPS Answer Percent` — % of patients responding "Always" or positively
- `Number of Completed Surveys`
- `Survey Response Rate Percent`

### Download Steps
1. Go to https://data.cms.gov/provider-data/dataset/dgck-syfz
2. Click **Export** → **CSV**
3. Save as `data/hcahps.csv`
4. Load: `\COPY staging.hcahps FROM 'data/hcahps.csv' CSV HEADER;`

---

## Dataset 4 — CMS Hospital Quality Measures (Mortality, Safety, Complications)

| Field | Detail |
|---|---|
| **Name** | Complications and Deaths — Hospital |
| **Source** | CMS Provider Data Catalog |
| **URL** | https://data.cms.gov/provider-data/dataset/ynj2-r877 |
| **Format** | CSV |
| **Frequency** | Annual |
| **Rows** | ~200,000+ records |
| **Target Table** | `staging.quality_metrics` → `core.fact_quality_metrics` |

### Measure Categories
- **Mortality** - 30-day risk-standardized mortality rates (Heart Failure, Acute MI, Pneumonia, COPD, CABG, Stroke)
- **Safety / HAI** - Standardized Infection Ratios for CLABSI, CAUTI, SSI, MRSA, C. diff
- **Complications** - Serious complications, PSI-90 composite

### Key Fields Used
- `Measure ID` - standardized measure code (e.g., MORT-30-HF, HAI-1)
- `Score` - rate or ratio value
- `Lower Estimate` / `Higher Estimate` — 95% confidence interval
- `Compared to National` - "Better", "No Different", or "Worse than the National average"

### Download Steps
1. Go to https://data.cms.gov/provider-data/dataset/ynj2-r877
2. Click **Export** → **CSV**
3. Save as `data/quality_metrics.csv`
4. Load: `\COPY staging.quality_metrics FROM 'data/quality_metrics.csv' CSV HEADER;`

---

## Field Mapping Summary

| Analytics Field | Source Dataset | Source Column |
|---|---|---|
| Hospital ID | All datasets | `Facility ID` |
| Hospital Name | CMS General | `Facility Name` |
| State | All datasets | `State` |
| Hospital Type | CMS General | `Hospital Type` |
| Overall Rating | CMS General | `Hospital overall rating` |
| Readmission Rate % | HRRP | Derived: Readmissions ÷ Discharges |
| Excess Readmission Ratio | HRRP | `Excess Readmission Ratio` |
| Satisfaction Star Rating | HCAHPS | `Patient Survey Star Rating` |
| % Would Recommend | HCAHPS | `HCAHPS Answer Percent` (H-RECMND-DY) |
| Mortality Rate | Quality Measures | `Score` (MORT-30-* measures) |
| HAI SIR | Quality Measures | `Score` (HAI-1 through HAI-6) |

---

## Data Suppression Notes

CMS suppresses values when:
- Fewer than 25 cases reported (`Too Few to Report`)
- Statistical reliability is insufficient (`Not Available`)
- The hospital did not participate (`Not Applicable`)

The data cleaning script (`02_data_cleaning.sql`) converts all suppressed values to `NULL` rather than excluding the hospital record entirely, preserving hospital-level dimension data while marking metrics as unavailable.

---

## License

All CMS data is published under the **U.S. Government Open Data License** and is free for public use. See https://www.usa.gov/government-works for terms.
