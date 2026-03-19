## Excel Files Guide

### Healthcare_Data_Model.xlsx

This workbook serves as both a data staging tool and an exploratory analysis layer between the raw CMS CSV files and the Power BI dashboard.

**Sheets included:**

| Sheet Name | Purpose |
|---|---|
| `README` | Setup instructions and sheet guide |
| `Hospital_Data` | Cleaned CMS hospital general information |
| `Readmissions` | HRRP readmission data by hospital and condition |
| `HCAHPS_Satisfaction` | Patient satisfaction survey scores |
| `Quality_Metrics` | Mortality, HAI, and safety measure scores |
| `State_Summary` | Pivot table — state-level performance averages |
| `Condition_Summary` | Pivot table — readmission rates by condition |
| `Performance_Scorecard` | Hospital scorecard with conditional formatting |
| `Charts` | Pre-built charts for quick review |

**How to use:**
1. Download the four CMS CSV files (see docs/Data_Sources.md)
2. Paste data into the corresponding raw sheets (grey-shaded area)
3. The cleaned sheets auto-update via Excel formulas and Power Query
4. Refresh pivot tables: Data → Refresh All
5. Review Charts sheet for summary visuals

**Power Query connections** (Data → Queries & Connections):
- `CMS_Hospital_Raw` → loads sample_cms_hospital.csv
- `Readmissions_Raw` → loads sample_readmissions.csv
- `Quality_Raw` → loads sample_quality_metrics.csv

---

### Data_Dictionary.xlsx

Field-level documentation for all datasets.

**Sheets included:**

| Sheet Name | Contents |
|---|---|
| `CMS_Hospital_Fields` | All fields from CMS General Information dataset |
| `Readmission_Fields` | All fields from HRRP dataset |
| `HCAHPS_Fields` | All fields from HCAHPS survey dataset |
| `Quality_Fields` | All fields from quality measures dataset |
| `Measure_Reference` | All CMS measure IDs used in this project |
| `Suppression_Codes` | Guide to CMS data suppression values |

---

### Excel Formulas Reference

**Calculate readmission rate:**
```excel
=IF(AND(ISNUMBER([@[Number of Readmissions]]),[@[Number of Discharges]]>0),
   [@[Number of Readmissions]]/[@[Number of Discharges]]*100,
   "")
```

**Flag excess readmission ratio above 1.0:**
```excel
=IF([@[Excess Readmission Ratio]]>1,"Above Expected",
   IF([@[Excess Readmission Ratio]]<1,"Below Expected","At Expected"))
```

**Conditional formatting for performance tiers:**
- Green fill: Overall Rating = 4 or 5
- Yellow fill: Overall Rating = 3
- Red fill: Overall Rating = 1 or 2
- Rule type: Cell value → equal to [value]

**XLOOKUP to join hospital names to readmission data:**
```excel
=XLOOKUP([@[Facility ID]], Hospital_Data[Facility ID],
         Hospital_Data[Hospital Type], "Not Found")
```

---

### Pivot Table Setup

**Readmission Rate by State and Condition:**
- Rows: State
- Columns: Condition (from Measure Name)
- Values: Average of Readmission Rate % (Average)
- Filter: Year

**Patient Satisfaction Heatmap:**
- Rows: State
- Columns: HCAHPS Measure ID
- Values: Average of Answer Percent (Average)
- Apply conditional formatting (Color Scale: Red-Yellow-Green)

**Hospital Count by Performance Tier:**
- Rows: Performance Tier
- Values: Count of Facility ID
- Sort: Descending by count
