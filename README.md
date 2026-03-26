## [Live Dashboard Demo](https://omoshow10.github.io/Healthcare-Performance-Analytics-Dashboard/)

# 🏥 Healthcare Performance Analytics Dashboard

![SQL](https://img.shields.io/badge/SQL-PostgreSQL-blue?logo=postgresql)
![Excel](https://img.shields.io/badge/Excel-Data%20Model-green?logo=microsoft-excel)
![PowerBI](https://img.shields.io/badge/Power%20BI-Dashboard-yellow?logo=powerbi)
![Status](https://img.shields.io/badge/Status-Active-brightgreen)

## 📋 Project Overview

The **Healthcare Performance Analytics Dashboard** is an end-to-end operational analytics system designed to improve healthcare system efficiency through data-driven insights. This project integrates CMS hospital data, readmission datasets, and quality metrics to deliver actionable visibility into hospital performance across clinical, operational, and outcome dimensions.

The system:
- **Improves operational transparency** by centralizing fragmented hospital data into a unified performance view
- **Supports data-driven healthcare management** by surfacing KPIs that administrators, clinicians, and analysts need to make informed decisions
- **Helps institutions monitor performance** over time with trend analysis, benchmarking, and early-warning indicators

---

## 📊 Analytical Outputs

### Output 1 — Departmental Performance Summary

| Department | Avg LOS | 30-Day Readmission Rate | Bed Occupancy |
|---|---|---|---|
| Emergency Department | 4.2 hrs | 8.3% | 87% |
| Medical / Surgical | 3.8 days | **11.2%** ⚠ | 79% |
| Intensive Care Unit (ICU) | 5.1 days | 6.7% | **91%** ⚠ |
| Outpatient Services | 2.1 hrs | 3.1% | 74% |
| Pediatrics | 2.9 days | 5.4% | 68% |

> ⚠ Medical/Surgical exceeds CMS national benchmark (9.8%) by +1.4pp. ICU bed occupancy at 91% indicates near-capacity operations — an actionable insight for resource planning.

---

### Output 2 — 30-Day Readmission Analysis

| Metric | Value / Finding |
|---|---|
| Total Discharges Analyzed | 28,400 |
| 30-Day Readmissions Identified | 4,489 |
| Overall Readmission Rate | 15.8% (↑ +0.3pp vs prior year) |
| Highest Risk Diagnosis Category | Heart Failure — 21.2% readmission rate |
| Departments Above CMS Threshold (9.8%) | Medical/Surgical at 11.2% (+1.4pp above benchmark) |
| Estimated Annual Excess Bed-Days | 20,650 bed-days (4,489 readmissions × 4.6 day avg LOS) |
| Estimated Annual Cost Impact | ~$22.4M (20,650 days × $1,086 AHRQ avg daily cost) |

---

### Output 3 — Key Performance Insights

Analysis of the dataset identified that **Medical/Surgical units recorded the highest 30-day readmission rate at 11.2%**, exceeding the CMS national benchmark of 9.8% by 1.4 percentage points, indicating a priority area for discharge planning improvement and post-acute care coordination. Heart Failure emerged as the highest-risk diagnosis category at 21.2%, followed by COPD at 20.1% — both substantially above their respective CMS condition-specific benchmarks and representing the primary drivers of preventable readmission cost, estimated at approximately $22.4 million annually across 20,650 excess bed-days.

**ICU bed occupancy consistently exceeded 90% during weekday shifts** (Monday–Wednesday peak), signalling a critical capacity management opportunity. The pattern of near-capacity ICU operations combined with a 94% staffing utilisation rate suggests a structural supply-demand imbalance that, if unaddressed, carries meaningful risk of care quality degradation and staff burnout. A proactive bed management protocol, including earlier discharge planning and inter-departmental transfer coordination, is indicated.

**Outpatient Services demonstrated the strongest overall performance** with a 3.1% readmission rate — 6.7 percentage points below the CMS benchmark — and a 74% bed occupancy rate within the optimal range, alongside a 76% staffing utilisation rate. These operational metrics suggest that the scheduling, patient triage, and discharge coordination practices employed in Outpatient Services represent a transferable best-practice model that, if systematically applied to the Medical/Surgical and ICU units, could yield measurable improvement in readmission rates and resource utilisation across the broader facility.

---

## 📸 Dashboard Visualizations

### Executive Healthcare Operations Overview
![Executive Healthcare Operations Overview](outputs/Executive_Healthcare_Operations_Overview.png)

---

### 30-Day Readmission Rate Analysis
![30-Day Readmission Rate Analysis](outputs/30_Day_Readmission_Rate_Analysis.png)

---

### Resource Utilization and Capacity Dashboard
![Resource Utilization and Capacity Dashboard](outputs/Resource_Utilization_and_Capacity_Dashboard.png)

---

### Patient Flow and Length of Stay Analysis
![Patient Flow and Length of Stay Analysis](outputs/Patient_Flow_and_Length_of_Stay_Analysis.png)

---

## 🗂️ Repository Structure

```
healthcare-analytics/
│
├── README.md                        ← Project overview (you are here)
├── index.html                       ← Live interactive dashboard (GitHub Pages)
│
├── outputs/
│   ├── Executive_Healthcare_Operations_Overview.png
│   ├── 30_Day_Readmission_Rate_Analysis.png
│   ├── Resource_Utilization_and_Capacity_Dashboard.png
│   └── Patient_Flow_and_Length_of_Stay_Analysis.png
│
├── sql/
│   ├── 01_schema_setup.sql          ← Database schema & table definitions
│   ├── 02_data_cleaning.sql         ← Data cleaning & standardization
│   ├── 03_hospital_performance.sql  ← Hospital performance metric queries
│   ├── 04_operational_efficiency.sql← Operational efficiency queries
│   ├── 05_outcome_analytics.sql     ← Outcome & quality indicator queries
│   └── 06_views_and_aggregates.sql  ← Reusable views for Power BI
│
├── excel/
│   └── Excel_Setup_Guide.md         ← Excel data model instructions
│
├── powerbi/
│   ├── Dashboard_Build_Guide.md     ← Power BI build guide
│   └── healthcare_dashboard_mockup.html
│
├── data/
│   ├── sample_cms_hospital.csv      ← Sample CMS hospital data (anonymized)
│   ├── sample_readmissions.csv      ← Sample readmission dataset
│   └── sample_quality_metrics.csv   ← Sample quality indicators
│
└── docs/
    ├── Data_Sources.md              ← Dataset sources & access instructions
    ├── Dashboard_Guide.md           ← How to use the Power BI dashboard
    └── SQL_Query_Guide.md           ← Query documentation & usage notes
```

---

## 📊 Dashboard Components

### 1. Hospital Performance Metrics
| Metric | Description | Source |
|---|---|---|
| Readmission Rate | 30-day all-cause readmission % by hospital | CMS Hospital Readmissions |
| Patient Satisfaction | HCAHPS survey scores (overall & domain) | CMS HCAHPS Data |
| Average Length of Stay | Mean LOS by DRG, department & hospital | CMS Inpatient Data |

### 2. Operational Efficiency
| Metric | Description | Source |
|---|---|---|
| Patient Volume Trends | Monthly admissions & ED visits over time | Hospital discharge data |
| Department Utilization | Bed occupancy & throughput by department | CMS cost report data |

### 3. Outcome Analytics
| Metric | Description | Source |
|---|---|---|
| Quality Indicators | Mortality, complication, infection rates | CMS quality measures |
| Performance Comparisons | Peer benchmarking by hospital size/region | CMS compare datasets |

---

## 🛠️ Tools & Technologies

| Tool | Version | Purpose |
|---|---|---|
| **SQL** (PostgreSQL) | 14+ | Data storage, cleaning, transformation |
| **Microsoft Excel** | 2019+ | Data modeling, pivot analysis, staging |
| **Power BI Desktop** | Latest | Interactive dashboard & visualizations |

---

## 🚀 Getting Started

### Prerequisites
- PostgreSQL 14+ installed locally or cloud instance (Azure, AWS RDS)
- Microsoft Excel 2019 or Microsoft 365
- Power BI Desktop (free download from Microsoft)

### Step 1 — Set Up the Database
```sql
-- Run scripts in order
psql -U your_user -d your_db -f sql/01_schema_setup.sql
psql -U your_user -d your_db -f sql/02_data_cleaning.sql
psql -U your_user -d your_db -f sql/03_hospital_performance.sql
psql -U your_user -d your_db -f sql/04_operational_efficiency.sql
psql -U your_user -d your_db -f sql/05_outcome_analytics.sql
psql -U your_user -d your_db -f sql/06_views_and_aggregates.sql
```

### Step 2 — Load Sample Data
```sql
-- Load CSV data into staging tables
\COPY staging.cms_hospital FROM 'data/sample_cms_hospital.csv' CSV HEADER;
\COPY staging.readmissions FROM 'data/sample_readmissions.csv' CSV HEADER;
\COPY staging.quality_metrics FROM 'data/sample_quality_metrics.csv' CSV HEADER;
```

### Step 3 — Open Excel Data Model
1. Open `excel/Healthcare_Data_Model.xlsx`
2. Navigate to the **Data** tab → **Refresh All** to pull from your database
3. Review pivot tables on each sheet for pre-built summaries

### Step 4 — Connect Power BI Dashboard
1. Open `powerbi/Healthcare_Dashboard.pbix` in Power BI Desktop
2. Go to **Transform Data** → **Data Source Settings**
3. Update the server/database connection to your PostgreSQL instance
4. Click **Refresh** — all visuals will populate automatically

---

## 📁 Data Sources

| Dataset | Source | Access |
|---|---|---|
| CMS Hospital General Information | [data.cms.gov](https://data.cms.gov/provider-data/dataset/xubh-q36u) | Free / Public |
| Hospital Readmissions Reduction Program | [data.cms.gov](https://data.cms.gov/provider-data/dataset/9n3s-kdb3) | Free / Public |
| HCAHPS Patient Survey | [data.cms.gov](https://data.cms.gov/provider-data/dataset/dgck-syfz) | Free / Public |
| Hospital Compare Quality Measures | [data.cms.gov](https://data.cms.gov) | Free / Public |

> 📌 See `docs/Data_Sources.md` for full download instructions and field mapping.

---

## 📈 Key Insights This Dashboard Surfaces

- **Which hospitals have above-average readmission rates** compared to state and national benchmarks
- **Correlation between patient satisfaction scores and length of stay**
- **Department-level utilization bottlenecks** driving extended average LOS
- **Year-over-year trends** in quality indicators to track improvement initiatives
- **Peer group benchmarking** — compare similar hospitals by bed count, teaching status, and region

---

## 🤝 Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-metric`)
3. Commit your changes (`git commit -m 'Add new metric'`)
4. Push to the branch (`git push origin feature/new-metric`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

## 👤 Author

Built as a portfolio project demonstrating healthcare analytics capabilities using SQL, Excel, and Power BI.

> *Data used in this project is publicly available from CMS (Centers for Medicare & Medicaid Services) and does not contain any protected health information (PHI).*
