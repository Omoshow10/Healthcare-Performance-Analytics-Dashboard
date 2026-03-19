# SQL Query Guide

## Script Execution Order

Run all scripts in numbered order. Each script depends on the previous.

```
01_schema_setup.sql        → Creates schemas, tables, indexes, date dimension, measure seeds
02_data_cleaning.sql       → Loads staging → core (dim_hospital, fact tables)
03_hospital_performance.sql→ Ad-hoc queries: readmission rates, HCAHPS, correlation
04_operational_efficiency.sql → Ad-hoc queries: volume trends, utilization
05_outcome_analytics.sql   → Ad-hoc queries: mortality, HAI, benchmarking
06_views_and_aggregates.sql → Creates analytics.vw_* views for Power BI/Excel
```

---

## Schema Architecture

```
staging.*     ←── Raw CMS CSV data (no transformations)
    │
    ▼
core.*        ←── Cleaned dimensional model
  dim_hospital       (one row per hospital)
  dim_date           (one row per calendar day)
  dim_measure        (one row per CMS measure)
  fact_readmissions
  fact_patient_satisfaction
  fact_quality_metrics
    │
    ▼
analytics.*   ←── Aggregated views (Power BI connects here)
  vw_hospital_scorecard
  vw_readmission_trends
  vw_quality_summary
  vw_satisfaction_detail
  vw_state_benchmark
```

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
ORDER BY avg_readmission_pct ASC NULLS LAST;
```

### Top-performing hospitals (all dimensions)
```sql
SELECT facility_name, state, hospital_type,
       overall_star_rating, avg_readmission_rate_pct,
       avg_mortality_rate, performance_tier
FROM analytics.vw_hospital_scorecard
WHERE performance_tier = 'Top Performer'
ORDER BY overall_star_rating DESC, avg_readmission_rate_pct ASC;
```

---

## Data Suppression Handling

CMS suppresses values with placeholder text. The `analytics.clean_numeric()` function converts all of these to `NULL`:

| CMS Value | Meaning | Stored As |
|---|---|---|
| `Not Available` | Data not submitted | NULL |
| `Too Few to Report` | < 25 cases | NULL |
| `Not Applicable` | Hospital type exempt | NULL |
| `Footnote Applies` | See footnote | NULL |
| `--` | Suppressed | NULL |

To find hospitals with suppressed readmission data:
```sql
SELECT h.facility_name, h.state, COUNT(*) AS suppressed_measures
FROM staging.readmissions r
JOIN core.dim_hospital h ON TRIM(r.facility_id) = h.facility_id
WHERE r.number_of_readmissions IN
      ('Not Available','Too Few to Report','Not Applicable','--')
GROUP BY h.facility_name, h.state
ORDER BY suppressed_measures DESC;
```

---

## Performance Tips

- All fact tables are indexed on `hospital_key`, `measure_key`, and date keys
- The analytics views filter to the latest year by default — remove the year filter for full history
- For large exports (50k+ rows), use `COPY` instead of `SELECT`:
  ```sql
  COPY (SELECT * FROM analytics.vw_hospital_scorecard)
  TO '/tmp/hospital_scorecard.csv' CSV HEADER;
  ```
- Materialize frequently-used views for better Power BI performance:
  ```sql
  CREATE MATERIALIZED VIEW analytics.mv_hospital_scorecard AS
  SELECT * FROM analytics.vw_hospital_scorecard;

  CREATE INDEX ON analytics.mv_hospital_scorecard (state);
  CREATE INDEX ON analytics.mv_hospital_scorecard (performance_tier);
  -- Refresh after each data load:
  REFRESH MATERIALIZED VIEW analytics.mv_hospital_scorecard;
  ```
