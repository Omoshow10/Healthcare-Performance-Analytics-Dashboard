# 🏥 Healthcare Performance Analytics Dashboard
## [Live Dashboard Demo](https://YOUR-USERNAME.github.io/healthcare-performance-analytics-dashboard/)

## [Live Dashboard Demo](https://YOUR-USERNAME.github.io/healthcare-performance-analytics-dashboard/)

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

## 🗂️ Repository Structure

```
healthcare-analytics/
│
├── README.md                        ← Project overview (you are here)
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
│   ├── Healthcare_Data_Model.xlsx   ← Cleaned dataset with pivot tables
│   └── Data_Dictionary.xlsx         ← Field definitions & source mapping
│
├── powerbi/
│   └── Healthcare_Dashboard.pbix    ← Power BI report file
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
