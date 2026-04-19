# Power BI Dashboard - Setup Notes

## File: Healthcare_Dashboard.pbix

The `.pbix` file is a binary Power BI Desktop file. Because binary files cannot be 
stored as readable text in a repository, this folder contains this setup guide instead.

## How to Build the Dashboard from Scratch

After running all SQL scripts and connecting to your SQL database, 
build the dashboard by importing these five views as separate tables:

### Data Model Imports (Power BI - Get Data - SQL)

Connect to schema: `analytics`

| Table in Power BI | Source View |
|---|---|
| `HospitalScorecard` | `analytics.vw_hospital_scorecard` |
| `ReadmissionTrends` | `analytics.vw_readmission_trends` |
| `QualitySummary` | `analytics.vw_quality_summary` |
| `SatisfactionDetail` | `analytics.vw_satisfaction_detail` |
| `StateBenchmark` | `analytics.vw_state_benchmark` |

### Relationships

In Power BI Model view, create these relationships:

```
HospitalScorecard[facility_id]  →  ReadmissionTrends[facility_id]  (1:*)
HospitalScorecard[facility_id]  →  SatisfactionDetail[facility_id] (1:*)
HospitalScorecard[state]        →  StateBenchmark[state]           (1:1)
```

### Page 1 - Hospital Performance Metrics

1. **Readmission Rate Bar Chart**
   - Axis: `facility_name`
   - Value: `avg_readmission_rate_pct`
   - Sort: Descending
   - Top N filter: 20

2. **State Map (Filled Map)**
   - Location: `state`
   - Color saturation: `avg_readmission_pct` from StateBenchmark
   - Data colors: Diverging (green = low, red = high)

3. **Patient Satisfaction Gauge**
   - Value: Average of `overall_star_rating`
   - Min: 1, Max: 5, Target: 4

4. **HCAHPS Domain Radar/Spider Chart** (use custom visual: Radar Chart)
   - Category: `measure_name` (filter to domain measures only)
   - Values: `avg_answer_pct`

5. **Performance Tier Donut**
   - Legend: `performance_tier`
   - Values: Count of `facility_id`

### Page 2 - Operational Efficiency

1. **Annual Volume Line Chart**
   - Axis: `year`
   - Values: `total_discharges`
   - Legend: `state` (or filter to national)

2. **Clinical Category Stacked Bar**
   - Axis: `year`
   - Legend: `clinical_category`
   - Value: `total_discharges`

3. **Utilization Heatmap (Matrix)**
   - Rows: `state`
   - Columns: `clinical_category`
   - Values: `avg_readmission_pct`
   - Conditional formatting: Background color scale

### Page 3 - Outcome Analytics

1. **Mortality Trend Multi-line**
   - Axis: `year`
   - Legend: `measure_name` (Mortality measures)
   - Value: `national_avg_score`

2. **HAI SIR Clustered Bar**
   - Axis: `measure_name` (HAI measures)
   - Value: `national_avg_score`
   - Reference line: 1.0 (national benchmark)

3. **Better/Same/Worse 100% Stacked Bar**
   - Axis: `measure_name`
   - Values: `hospitals_better`, `hospitals_same`, `hospitals_worse`

4. **State Performance Filled Map**
   - Location: `state`
   - Color: `avg_overall_rating`

### Slicers (add to all pages)

- **Year** - single select, from `ReadmissionTrends[year]`
- **State** - multi-select, from `HospitalScorecard[state]`
- **Hospital Type** - multi-select, from `HospitalScorecard[hospital_type]`

### Theme

Recommended theme colors (healthcare professional palette):
```json
{
  "name": "Healthcare Analytics",
  "dataColors": ["#1F4E79","#2E75B6","#5BA3D9","#A9C6E8","#D9E8F5","#C00000","#FF6B6B","#FFB347","#4CAF50","#8BC34A"],
  "background": "#FFFFFF",
  "foreground": "#1F4E79",
  "tableAccent": "#2E75B6"
}
```

Save as `Healthcare_Theme.json` and apply via: View - Themes - Browse for themes
