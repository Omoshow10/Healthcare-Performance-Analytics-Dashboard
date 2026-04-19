# SQL Query Guide

## Script Execution Order

Run all scripts in numbered order using SQL Server Management Studio (SSMS) or sqlcmd. Each script depends on the previous.

```
01_schema_setup.sql         → Creates schemas, tables, indexes, date dimension, measure seeds
02_data_cleaning.sql        → Loads staging → core (dim_hospital, fact tables)
03_hospital_performance.sql → Ad-hoc queries: readmission rates, HCAHPS, correlation
04_operational_efficiency.sql → Ad-hoc queries: volume trends, utilisation
05_outcome_analytics.sql    → Ad-hoc queries: mortality, HAI, benchmarking
06_views_and_aggregates.sql → Creates analytics.vw_* views for Power BI and Excel
```

---

## Running Scripts in SSMS

Open SQL Server Management Studio → connect to your instance → open each script file → press **F5** to execute.

Via command line (sqlcmd):
```
sqlcmd -S your_server\instance -d your_database -i sql\01_schema_setup.sql
sqlcmd -S your_server\instance -d your_database -i sql\02_data_cleaning.sql
sqlcmd -S your_server\instance -d your_database -i sql\03_hospital_performance.sql
sqlcmd -S your_server\instance -d your_database -i sql\04_operational_efficiency.sql
sqlcmd -S your_server\instance -d your_database -i sql\05_outcome_analytics.sql
sqlcmd -S your_server\instance -d your_database -i sql\06_views_and_aggregates.sql
```

---

## Schema Architecture

```
staging.*     ←─ Raw CMS CSV data (no transformations)
    │
    ▼
core.*        ←─ Cleaned dimensional model
  dim_hospital       (one row per hospital)
  dim_date           (one row per calendar day 2019–2026)
  dim_measure        (one row per CMS quality/performance measure)
  fact_readmissions
  fact_patient_satisfaction
  fact_quality_metrics
    │
    ▼
analytics.*   ←─ Views Power BI connects to directly
  vw_hospital_scorecard
  vw_readmission_trends
  vw_quality_summary
  vw_satisfaction_detail
  vw_state_benchmark
```

---

## Key SQL Server Differences from Other Dialects

| PostgreSQL / Standard SQL | MS SQL Server Equivalent |
|---|---|
| `SERIAL PRIMARY KEY` | `INT IDENTITY(1,1) PRIMARY KEY` |
| `VARCHAR` | `NVARCHAR` (supports Unicode) |
| `TIMESTAMP DEFAULT NOW()` | `DATETIME2 DEFAULT GETDATE()` |
| `BOOLEAN` | `BIT` (0 = false, 1 = true) |
| `NUMERIC(8,4)` | `DECIMAL(8,4)` |
| `INITCAP(text)` | `UPPER(LEFT(col,1)) + LOWER(SUBSTRING(col,2,LEN(col)))` |
| `ILIKE '%text%'` | `LIKE '%text%'` (SQL Server LIKE is case-insensitive by default) |
| `COALESCE(x, y)` | `ISNULL(x, y)` or `COALESCE(x, y)` |
| `STDDEV(col)` | `STDEV(col)` |
| `CREATE SCHEMA IF NOT EXISTS` | `IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='x') EXEC('CREATE SCHEMA x')` |
| `DROP TABLE IF EXISTS` | `IF OBJECT_ID('schema.table','U') IS NOT NULL DROP TABLE schema.table` |
| `\COPY FROM CSV` | `BULK INSERT ... WITH (FORMAT='CSV')` |
| `GENERATE_SERIES(date, date, interval)` | `WHILE` loop with `DATEADD` |
| `TO_CHAR(date, 'YYYYMMDD')` | `FORMAT(date, 'yyyyMMdd')` |
| `TO_DATE(str, 'MM/DD/YYYY')` | `TRY_CONVERT(DATE, str, 101)` |
| `COMMENT ON TABLE` | Extended properties via `sp_addextendedproperty` |

---

## Key Query Patterns

### Get readmission rate for a specific hospital
```sql
SELECT
    h.facility_name,
    h.state,
    m.measure_name,
    fr.readmission_rate_pct,
    fr.excess_readmission_ratio
FROM core.fact_readmissions fr
JOIN core.dim_hospital h ON fr.hospital_key = h.hospital_key
JOIN core.dim_measure  m ON fr.measure_key  = m.measure_key
WHERE h.facility_id = '110001'   -- Replace with target Facility ID
ORDER BY m.measure_name;
```

### Get all hospitals worse than national average on readmissions
```sql
SELECT facility_name, state, avg_readmission_rate_pct, avg_excess_ratio
FROM analytics.vw_hospital_scorecard
WHERE avg_excess_ratio > 1.0
ORDER BY avg_excess_ratio DESC;
```

### State-level performance summary
```sql
SELECT *
FROM analytics.vw_state_benchmark
ORDER BY avg_readmission_pct ASC;
```

### Top-performing hospitals
```sql
SELECT facility_name, state, hospital_type,
       overall_star_rating, avg_readmission_rate_pct,
       avg_mortality_rate, performance_tier
FROM analytics.vw_hospital_scorecard
WHERE performance_tier = 'Top Performer'
ORDER BY overall_star_rating DESC, avg_readmission_rate_pct ASC;
```

---

## Loading CSV Data (BULK INSERT)

Update the file path and run after script 01:
```sql
BULK INSERT staging.cms_hospital
FROM 'C:\your_path\data\sample_cms_hospital.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n', TABLOCK);

BULK INSERT staging.readmissions
FROM 'C:\your_path\data\sample_readmissions.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n', TABLOCK);

BULK INSERT staging.quality_metrics
FROM 'C:\your_path\data\sample_quality_metrics.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n', TABLOCK);
```

---

## Data Suppression Handling

CMS suppresses values with placeholder text. Script 02 converts all of these to NULL using `TRY_CAST` with explicit CASE expressions:

| CMS Value | Meaning | Stored As |
|---|---|---|
| `Not Available` | Data not submitted | NULL |
| `Too Few to Report` | < 25 cases | NULL |
| `Not Applicable` | Hospital type exempt | NULL |
| `Footnote Applies` | See footnote | NULL |
| `--` | Suppressed | NULL |

---

## Connecting Power BI to SQL Server Views

1. Open Power BI Desktop
2. Home → Get Data → SQL Server
3. Server: `your_server\instance`
4. Database: `your_database`
5. Data Connectivity mode: **Import** (recommended) or DirectQuery
6. Navigate to **analytics** schema → select all `vw_*` views
7. Click **Load**

---

## Performance Tips

All fact tables are indexed on `hospital_key`, `measure_key`, and date keys. For large production datasets, consider materializing the analytics views as indexed views:

```sql
-- Example: materialize the scorecard for faster Power BI refresh
SELECT * INTO analytics.mv_hospital_scorecard
FROM analytics.vw_hospital_scorecard;

CREATE INDEX idx_mv_scorecard_state ON analytics.mv_hospital_scorecard(state);
CREATE INDEX idx_mv_scorecard_tier  ON analytics.mv_hospital_scorecard(performance_tier);

-- Refresh after each data load:
TRUNCATE TABLE analytics.mv_hospital_scorecard;
INSERT INTO analytics.mv_hospital_scorecard SELECT * FROM analytics.vw_hospital_scorecard;
```
