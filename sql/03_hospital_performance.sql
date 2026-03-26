-- =============================================================================
-- Healthcare Performance Analytics Dashboard
-- Script 03: Hospital Performance Metrics
-- =============================================================================
-- Description: Queries covering readmission rates, patient satisfaction scores,
--              and average length of stay. These drive the "Hospital Performance"
--              page of the Power BI dashboard.
-- Database:    Microsoft SQL Server 2019+
-- Run Order:   3 of 6
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION A: READMISSION RATES
-- ─────────────────────────────────────────────────────────────────────────────

-- A1. Overall 30-Day Readmission Rate by Hospital (Latest Period)
SELECT
    h.facility_id,
    h.facility_name,
    h.city,
    h.state,
    h.hospital_type,
    h.readmission_group,
    ROUND(AVG(fr.excess_readmission_ratio), 4)   AS avg_excess_readmission_ratio,
    ROUND(AVG(fr.readmission_rate_pct), 2)        AS avg_readmission_rate_pct,
    ROUND(AVG(fr.predicted_readmission_rate), 4)  AS avg_predicted_rate,
    ROUND(AVG(fr.expected_readmission_rate), 4)   AS avg_expected_rate,
    SUM(fr.number_of_discharges)                  AS total_discharges,
    SUM(fr.number_of_readmissions)                AS total_readmissions,
    COUNT(DISTINCT fr.measure_key)                AS measure_count
FROM core.fact_readmissions fr
JOIN core.dim_hospital h ON fr.hospital_key = h.hospital_key
JOIN core.dim_date     d ON fr.end_date_key = d.date_key
WHERE d.year = (
    SELECT MAX(year) FROM core.dim_date
    WHERE date_key IN (SELECT end_date_key FROM core.fact_readmissions)
)
GROUP BY
    h.facility_id, h.facility_name, h.city, h.state,
    h.hospital_type, h.readmission_group
ORDER BY avg_readmission_rate_pct DESC;
GO

-- A2. Readmission Rate by Condition / Measure (Latest Period)
SELECT
    m.measure_name,
    m.measure_id,
    h.state,
    COUNT(DISTINCT h.hospital_key)              AS hospital_count,
    ROUND(AVG(fr.excess_readmission_ratio), 4)  AS national_avg_excess_ratio,
    ROUND(AVG(fr.readmission_rate_pct), 2)      AS national_avg_readmission_pct,
    ROUND(MIN(fr.readmission_rate_pct), 2)      AS min_readmission_pct,
    ROUND(MAX(fr.readmission_rate_pct), 2)      AS max_readmission_pct,
    -- Percentiles using PERCENTILE_CONT (SQL Server 2012+)
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY fr.readmission_rate_pct)
          OVER (PARTITION BY m.measure_id, h.state), 2) AS p25,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY fr.readmission_rate_pct)
          OVER (PARTITION BY m.measure_id, h.state), 2) AS median_pct,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY fr.readmission_rate_pct)
          OVER (PARTITION BY m.measure_id, h.state), 2) AS p75
FROM core.fact_readmissions fr
JOIN core.dim_hospital h ON fr.hospital_key = h.hospital_key
JOIN core.dim_measure  m ON fr.measure_key  = m.measure_key
JOIN core.dim_date     d ON fr.end_date_key = d.date_key
WHERE m.measure_category = 'Readmission'
  AND d.year = (
      SELECT MAX(year) FROM core.dim_date
      WHERE date_key IN (SELECT end_date_key FROM core.fact_readmissions)
  )
GROUP BY m.measure_name, m.measure_id, h.state,
         fr.readmission_rate_pct  -- required for window function
ORDER BY m.measure_name, h.state;
GO

-- A3. 30-Day Readmission Trend — Annual, by Condition
SELECT
    d.year,
    m.measure_name,
    COUNT(DISTINCT h.hospital_key)             AS hospital_count,
    ROUND(AVG(fr.excess_readmission_ratio), 4) AS avg_excess_ratio,
    ROUND(AVG(fr.readmission_rate_pct), 2)     AS avg_readmission_pct
FROM core.fact_readmissions fr
JOIN core.dim_hospital h ON fr.hospital_key = h.hospital_key
JOIN core.dim_measure  m ON fr.measure_key  = m.measure_key
JOIN core.dim_date     d ON fr.end_date_key = d.date_key
WHERE m.measure_category = 'Readmission'
GROUP BY d.year, m.measure_name
ORDER BY d.year, m.measure_name;
GO

-- A4. Hospitals with Excess Readmission Ratio > 1.0 (Above Expected — At Risk)
SELECT
    h.facility_id,
    h.facility_name,
    h.city,
    h.state,
    h.hospital_type,
    m.measure_name,
    ROUND(fr.excess_readmission_ratio, 4)  AS excess_ratio,
    ROUND(fr.readmission_rate_pct, 2)      AS readmission_rate_pct,
    fr.number_of_discharges,
    fr.number_of_readmissions
FROM core.fact_readmissions fr
JOIN core.dim_hospital h ON fr.hospital_key = h.hospital_key
JOIN core.dim_measure  m ON fr.measure_key  = m.measure_key
JOIN core.dim_date     d ON fr.end_date_key = d.date_key
WHERE fr.excess_readmission_ratio > 1.0
  AND d.year = (
      SELECT MAX(year) FROM core.dim_date
      WHERE date_key IN (SELECT end_date_key FROM core.fact_readmissions)
  )
ORDER BY fr.excess_readmission_ratio DESC;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION B: PATIENT SATISFACTION (HCAHPS)
-- ─────────────────────────────────────────────────────────────────────────────

-- B1. Overall Hospital Star Rating by Hospital
SELECT
    h.facility_id,
    h.facility_name,
    h.city,
    h.state,
    h.hospital_type,
    h.patient_exp_group,
    MAX(CASE WHEN m.measure_id = 'H-HSP-RATING-9-10' THEN fs.star_rating END)   AS overall_star_rating,
    MAX(CASE WHEN m.measure_id = 'H-RECMND-DY'       THEN fs.answer_percent END) AS pct_recommend,
    ROUND(AVG(CASE WHEN m.measure_id IN ('H-COMP-1-A-P','H-COMP-2-A-P',
                                         'H-COMP-3-A-P','H-COMP-5-A-P')
                   THEN fs.answer_percent END), 1)   AS avg_communication_score,
    ROUND(AVG(CASE WHEN m.measure_id IN ('H-CLEAN-HSP-A-P','H-QUIET-HSP-A-P')
                   THEN fs.answer_percent END), 1)   AS avg_environment_score,
    MAX(fs.completed_surveys)                        AS completed_surveys,
    MAX(fs.response_rate_pct)                        AS response_rate_pct
FROM core.fact_patient_satisfaction fs
JOIN core.dim_hospital h ON fs.hospital_key = h.hospital_key
JOIN core.dim_measure  m ON fs.measure_key  = m.measure_key
JOIN core.dim_date     d ON fs.end_date_key = d.date_key
WHERE d.year = (
    SELECT MAX(year) FROM core.dim_date
    WHERE date_key IN (SELECT end_date_key FROM core.fact_patient_satisfaction)
)
GROUP BY
    h.facility_id, h.facility_name, h.city, h.state,
    h.hospital_type, h.patient_exp_group
ORDER BY overall_star_rating DESC, pct_recommend DESC;
GO

-- B2. HCAHPS Domain Scores — State Averages
SELECT
    h.state,
    m.measure_id,
    m.measure_name,
    COUNT(DISTINCT h.hospital_key)             AS hospital_count,
    ROUND(AVG(fs.answer_percent), 1)           AS avg_pct_always,
    ROUND(AVG(fs.star_rating), 2)              AS avg_star_rating,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY fs.answer_percent)
          OVER (PARTITION BY h.state, m.measure_id), 1) AS median_pct_always
FROM core.fact_patient_satisfaction fs
JOIN core.dim_hospital h ON fs.hospital_key = h.hospital_key
JOIN core.dim_measure  m ON fs.measure_key  = m.measure_key
JOIN core.dim_date     d ON fs.end_date_key = d.date_key
WHERE m.measure_category = 'Patient Experience'
  AND d.year = (
      SELECT MAX(year) FROM core.dim_date
      WHERE date_key IN (SELECT end_date_key FROM core.fact_patient_satisfaction)
  )
GROUP BY h.state, m.measure_id, m.measure_name, fs.answer_percent
ORDER BY h.state, m.measure_name;
GO

-- B3. Patient Satisfaction Trend — Annual Overall Rating
SELECT
    d.year,
    h.state,
    ROUND(AVG(fs.star_rating), 2)          AS avg_star_rating,
    ROUND(AVG(fs.answer_percent), 1)       AS avg_answer_pct,
    COUNT(DISTINCT h.hospital_key)         AS hospital_count
FROM core.fact_patient_satisfaction fs
JOIN core.dim_hospital h ON fs.hospital_key = h.hospital_key
JOIN core.dim_measure  m ON fs.measure_key  = m.measure_key
JOIN core.dim_date     d ON fs.end_date_key = d.date_key
WHERE m.measure_id = 'H-HSP-RATING-9-10'
GROUP BY d.year, h.state
ORDER BY d.year, h.state;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION C: CORRELATION — Readmission Rate vs Patient Satisfaction
-- ─────────────────────────────────────────────────────────────────────────────

WITH readmit AS (
    SELECT
        fr.hospital_key,
        ROUND(AVG(fr.readmission_rate_pct), 2)      AS avg_readmission_pct,
        ROUND(AVG(fr.excess_readmission_ratio), 4)  AS avg_excess_ratio
    FROM core.fact_readmissions fr
    JOIN core.dim_date d ON fr.end_date_key = d.date_key
    WHERE d.year = (
        SELECT MAX(year) FROM core.dim_date
        WHERE date_key IN (SELECT end_date_key FROM core.fact_readmissions)
    )
    GROUP BY fr.hospital_key
),
satisfaction AS (
    SELECT
        fs.hospital_key,
        MAX(CASE WHEN m.measure_id = 'H-HSP-RATING-9-10' THEN fs.star_rating END)   AS overall_star_rating,
        MAX(CASE WHEN m.measure_id = 'H-RECMND-DY'       THEN fs.answer_percent END) AS pct_would_recommend
    FROM core.fact_patient_satisfaction fs
    JOIN core.dim_measure m ON fs.measure_key  = m.measure_key
    JOIN core.dim_date    d ON fs.end_date_key = d.date_key
    WHERE d.year = (
        SELECT MAX(year) FROM core.dim_date
        WHERE date_key IN (SELECT end_date_key FROM core.fact_patient_satisfaction)
    )
    GROUP BY fs.hospital_key
)
SELECT
    h.facility_id,
    h.facility_name,
    h.state,
    h.hospital_type,
    r.avg_readmission_pct,
    r.avg_excess_ratio,
    s.overall_star_rating,
    s.pct_would_recommend
FROM readmit r
JOIN satisfaction  s ON r.hospital_key = s.hospital_key
JOIN core.dim_hospital h ON r.hospital_key = h.hospital_key
WHERE r.avg_readmission_pct IS NOT NULL
  AND s.overall_star_rating IS NOT NULL
ORDER BY r.avg_readmission_pct DESC;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- END OF SCRIPT 03
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'Script 03 complete — hospital performance queries ready.' AS status;
GO
