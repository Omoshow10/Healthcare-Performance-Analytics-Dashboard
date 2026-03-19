# Power BI Dashboard Guide

## Overview

The `Healthcare_Dashboard.pbix` file contains three report pages that map directly to the three dashboard components of this project. This guide explains how to connect, refresh, and navigate the dashboard.

---

## Connection Setup

### Step 1 — Open the File
Open `powerbi/Healthcare_Dashboard.pbix` in **Power BI Desktop** (free download: https://powerbi.microsoft.com/desktop).

### Step 2 — Update Data Source Connection
1. Click **Home** → **Transform Data** → **Data Source Settings**
2. Select the PostgreSQL connection → click **Change Source**
3. Enter your server details:
   - **Server:** `localhost` (or your remote host / Azure endpoint)
   - **Database:** your database name (e.g., `healthcare_analytics`)
   - **Port:** `5432` (default PostgreSQL)
4. Click **OK** → **Close**
5. Enter your PostgreSQL credentials when prompted

### Step 3 — Refresh Data
Click **Home** → **Refresh** — all visuals will populate from the analytics views.

---

## Dashboard Pages

### Page 1 — Hospital Performance

**Data Source:** `analytics.vw_hospital_scorecard`

| Visual | Type | Description |
|---|---|---|
| Readmission Rate by Hospital | Bar Chart | Top 20 hospitals by avg 30-day readmission rate |
| Readmission Rate Map | Filled Map | State-level readmission rates (color scale) |
| Patient Satisfaction Stars | Card + Gauge | National average star rating |
| Satisfaction by Domain | Radar Chart | HCAHPS domain scores (Nurses, Doctors, Staff, Medicines, Cleanliness, Quiet) |
| Average LOS Proxy | Scatter Plot | Discharge volume vs readmission rate (LOS proxy via readmit burden) |
| Performance Tier Distribution | Donut Chart | Top/Above/Average/Below performer breakdown |
| Hospital Detail Table | Table | Drillthrough-enabled hospital list with all KPIs |

**Key Slicers:** State, Hospital Type, Hospital Ownership, Year, Performance Tier

---

### Page 2 — Operational Efficiency

**Data Sources:** `analytics.vw_readmission_trends`, `analytics.vw_hospital_scorecard`

| Visual | Type | Description |
|---|---|---|
| Patient Volume Trend | Line Chart | Annual discharge volume trend (national & by state) |
| Volume by Clinical Category | Stacked Bar | Discharges split by condition (HF, AMI, Pneumonia, COPD, Ortho, CABG) |
| YoY Volume Change | Waterfall Chart | Discharge growth/decline by state vs prior year |
| Department Utilization Heatmap | Matrix | Readmission rate by condition × state (color intensity) |
| Efficiency Percentile | Bar Chart | Hospitals ranked by operational efficiency percentile |
| Readmission Burden | KPI Card | Estimated excess bed-days from preventable readmissions |
| Volume Tier Distribution | Treemap | Hospital count by volume tier (High / Mid / Low) |

**Key Slicers:** Year, State, Clinical Category, Hospital Type, Volume Tier

---

### Page 3 — Outcome Analytics

**Data Sources:** `analytics.vw_quality_summary`, `analytics.vw_state_benchmark`, `analytics.vw_satisfaction_detail`

| Visual | Type | Description |
|---|---|---|
| Mortality Rate Trend | Multi-line Chart | 30-day mortality rates by condition, annual trend |
| HAI Rates Dashboard | Clustered Bar | SIR scores for CLABSI, CAUTI, SSI, MRSA, C.diff |
| Quality vs National | 100% Stacked Bar | Better / Same / Worse than national split by measure |
| State Performance Map | Filled Map | Composite quality score by state |
| Hospital Type Comparison | Grouped Bar | Performance dimensions by hospital type (Teaching vs Community vs Critical Access) |
| Peer Benchmarking Table | Table | Sortable multi-metric comparison across all hospitals |
| Quality Scatter | Scatter | Mortality rate vs HAI SIR (quadrant analysis) |

**Key Slicers:** Year, State, Hospital Type, Measure Category, Compared to National

---

## Drillthrough Setup

The **Hospital Detail** drillthrough page (hidden from nav) can be accessed by:
1. Right-clicking any hospital in any table or chart
2. Selecting **Drillthrough** → **Hospital Detail**

The detail page shows all metrics for a single hospital with historical trend lines.

---

## DAX Measures Reference

Key calculated measures used in the dashboard:

```dax
-- National Average Readmission Rate
Nat Avg Readmission % =
CALCULATE(
    AVERAGE(vw_hospital_scorecard[avg_readmission_rate_pct]),
    ALL(vw_hospital_scorecard)
)

-- Readmission Rate vs National Benchmark
Readmission vs National =
[Selected Readmission Rate] - [Nat Avg Readmission %]

-- % Hospitals Above National Quality Benchmark
% Above National Quality =
DIVIDE(
    COUNTROWS(FILTER(vw_hospital_scorecard, vw_hospital_scorecard[pct_above_national] > 50)),
    COUNTROWS(vw_hospital_scorecard),
    0
)

-- Top Performer Count
Top Performers =
CALCULATE(
    COUNTROWS(vw_hospital_scorecard),
    vw_hospital_scorecard[performance_tier] = "Top Performer"
)

-- Estimated Excess Bed Days (National)
Total Excess Bed Days =
SUMX(
    vw_hospital_scorecard,
    vw_hospital_scorecard[total_readmissions] * 4.6
)
```

---

## Publishing to Power BI Service

1. Click **File** → **Publish** → **Publish to Power BI**
2. Select your workspace
3. In the Power BI Service, configure a **scheduled refresh** (requires an on-premises data gateway for PostgreSQL)
4. Set refresh frequency to **Weekly** (aligned with CMS data update cadence)

---

## Troubleshooting

| Issue | Solution |
|---|---|
| Blank visuals after refresh | Check PostgreSQL connection credentials; verify views exist in `analytics` schema |
| Map visual shows "Can't display map" | Enable map visuals: File → Options → Security → Map and filled map visuals |
| Slow refresh | Add database indexes (script 01 includes indexes); consider materializing views |
| Missing data for a state | CMS data suppression — state may have too few hospitals reporting a measure |
