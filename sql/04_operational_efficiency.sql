-- =============================================================================
-- Healthcare Performance Analytics Dashboard
-- Script 04: Operational Efficiency
-- =============================================================================
-- Description: Queries for patient volume trends and department utilization.
--              Drives the "Operational Efficiency" page of the Power BI dashboard.
-- Database:    Microsoft SQL Server 2019+
-- Run Order:   4 of 6
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION A: PATIENT VOLUME TRENDS
-- ─────────────────────────────────────────────────────────────────────────────

-- A1. Annual Discharge Volume by Hospital
SELECT
    d.year,
    h.state,
    h.hospital_type,
    COUNT(DISTINCT h.hospital_key)         AS hospital_count,
    SUM(fr.number_of_discharges)           AS total_discharges,
    ROUND(AVG(CAST(fr.number_of_discharges AS DECIMAL(10,2))), 0)
                                           AS avg_discharges_per_hospital,
    SUM(fr.number_of_readmissions)         AS total_readmissions
FROM core.fact_readmissions fr
JOIN core.dim_hospital h ON fr.hospital_key = h.hospital_key
JOIN core.dim_date     d ON fr.end_date_key = d.date_key
WHERE fr.number_of_discharges IS NOT NULL
GROUP BY d.year, h.state, h.hospital_type
ORDER BY d.year, h.state, h.hospital_type;
GO

-- A2. YoY Volume Growth Rate by Hospital
WITH annual_vol AS (
    SELECT
        h.facility_id,
        h.facility_name,
        h.state,
        d.year,
        SUM(fr.number_of_discharges) AS total_discharges
    FROM core.fact_readmissions fr
    JOIN core.dim_hospital h ON fr.hospital_key = h.hospital_key
    JOIN core.dim_date     d ON fr.end_date_key = d.date_key
    WHERE fr.number_of_discharges IS NOT NULL
    GROUP BY h.facility_id, h.facility_name, h.state, d.year
)
SELECT
    curr.facility_id,
    curr.facility_name,
    curr.state,
    curr.year                                                     AS current_year,
    curr.total_discharges                                         AS current_discharges,
    prev.total_discharges                                         AS prior_year_discharges,
    curr.total_discharges - prev.total_discharges                 AS volume_change,
    ROUND(
        CAST(curr.total_discharges - prev.total_discharges AS DECIMAL(10,4))
        / NULLIF(prev.total_discharges, 0) * 100, 2)             AS yoy_growth_pct
FROM annual_vol curr
LEFT JOIN annual_vol prev
    ON  curr.facility_id = prev.facility_id
    AND curr.year        = prev.year + 1
ORDER BY curr.year DESC, yoy_growth_pct DESC;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION B: DEPARTMENT / CONDITION UTILIZATION
-- ─────────────────────────────────────────────────────────────────────────────

-- B1. Discharge Volume by Clinical Condition
SELECT
    d.year,
    CASE
        WHEN m.measure_name LIKE '%Heart Failure%'          THEN 'Heart Failure'
        WHEN m.measure_name LIKE '%Acute Myocardial%'
          OR m.measure_name LIKE '%Heart Attack%'           THEN 'Acute MI'
        WHEN m.measure_name LIKE '%Pneumonia%'              THEN 'Pneumonia'
        WHEN m.measure_name LIKE '%Hip%'
          OR m.measure_name LIKE '%Knee%'                   THEN 'Orthopaedics'
        WHEN m.measure_name LIKE '%CABG%'
          OR m.measure_name LIKE '%Bypass%'                 THEN 'Cardiac Surgery'
        WHEN m.measure_name LIKE '%COPD%'
          OR m.measure_name LIKE '%Pulmonary%'              THEN 'Pulmonary'
        ELSE 'Other'
    END                                                     AS clinical_category,
    h.state,
    COUNT(DISTINCT h.hospital_key)                          AS hospital_count,
    SUM(fr.number_of_discharges)                            AS total_discharges,
    SUM(fr.number_of_readmissions)                          AS total_readmissions,
    ROUND(AVG(fr.readmission_rate_pct), 2)                  AS avg_readmission_pct
FROM core.fact_readmissions fr
JOIN core.dim_hospital h ON fr.hospital_key = h.hospital_key
JOIN core.dim_measure  m ON fr.measure_key  = m.measure_key
JOIN core.dim_date     d ON fr.end_date_key = d.date_key
WHERE fr.number_of_discharges IS NOT NULL
GROUP BY d.year, h.state,
    CASE
        WHEN m.measure_name LIKE '%Heart Failure%'          THEN 'Heart Failure'
        WHEN m.measure_name LIKE '%Acute Myocardial%'
          OR m.measure_name LIKE '%Heart Attack%'           THEN 'Acute MI'
        WHEN m.measure_name LIKE '%Pneumonia%'              THEN 'Pneumonia'
        WHEN m.measure_name LIKE '%Hip%'
          OR m.measure_name LIKE '%Knee%'                   THEN 'Orthopaedics'
        WHEN m.measure_name LIKE '%CABG%'
          OR m.measure_name LIKE '%Bypass%'                 THEN 'Cardiac Surgery'
        WHEN m.measure_name LIKE '%COPD%'
          OR m.measure_name LIKE '%Pulmonary%'              THEN 'Pulmonary'
        ELSE 'Other'
    END
ORDER BY d.year, total_discharges DESC;
GO

-- B2. Utilization Intensity Index
WITH condition_counts AS (
    SELECT
        h.facility_id,
        h.facility_name,
        h.city,
        h.state,
        h.hospital_type,
        d.year,
        SUM(fr.number_of_discharges)   AS total_discharges,
        COUNT(DISTINCT m.measure_key)  AS conditions_tracked,
        SUM(fr.number_of_readmissions) AS total_readmissions
    FROM core.fact_readmissions fr
    JOIN core.dim_hospital h ON fr.hospital_key = h.hospital_key
    JOIN core.dim_measure  m ON fr.measure_key  = m.measure_key
    JOIN core.dim_date     d ON fr.end_date_key = d.date_key
    WHERE fr.number_of_discharges IS NOT NULL
    GROUP BY h.facility_id, h.facility_name, h.city, h.state, h.hospital_type, d.year
)
SELECT
    facility_id,
    facility_name,
    city,
    state,
    hospital_type,
    year,
    total_discharges,
    conditions_tracked,
    total_readmissions,
    ROUND(CAST(total_discharges AS DECIMAL(10,2))
          / NULLIF(conditions_tracked, 0), 0)                     AS discharge_density,
    ROUND(CAST(total_readmissions AS DECIMAL(10,4))
          / NULLIF(total_discharges, 0) * 100, 2)                 AS overall_readmit_pct,
    CASE
        WHEN total_discharges >= 10000 THEN 'High Volume'
        WHEN total_discharges >= 5000  THEN 'Mid Volume'
        WHEN total_discharges >= 1000  THEN 'Low-Mid Volume'
        ELSE 'Low Volume'
    END                                                           AS volume_tier,
    -- Efficiency percentile using PERCENT_RANK window function
    ROUND(
        PERCENT_RANK() OVER (
            PARTITION BY year
            ORDER BY CAST(total_readmissions AS DECIMAL(10,4)) / NULLIF(total_discharges, 0) ASC
        ) * 100, 1)                                               AS efficiency_percentile
FROM condition_counts
ORDER BY year DESC, total_discharges DESC;
GO

-- B3. Bed Utilization Proxy — Readmission Burden
-- Estimates additional patient-days from preventable readmissions
-- using 4.6-day national average LOS (AHRQ reference)
SELECT
    h.facility_id,
    h.facility_name,
    h.state,
    d.year,
    SUM(fr.number_of_discharges)                              AS total_discharges,
    SUM(fr.number_of_readmissions)                            AS total_readmissions,
    ROUND(AVG(fr.readmission_rate_pct), 2)                    AS avg_readmission_pct,
    ROUND(SUM(fr.number_of_readmissions) * 4.6, 0)           AS est_readmission_bed_days,
    ROUND(
        PERCENT_RANK() OVER (
            PARTITION BY d.year
            ORDER BY AVG(fr.readmission_rate_pct) ASC
        ) * 100, 1)                                           AS efficiency_percentile
FROM core.fact_readmissions fr
JOIN core.dim_hospital h ON fr.hospital_key = h.hospital_key
JOIN core.dim_date     d ON fr.end_date_key = d.date_key
WHERE fr.number_of_discharges IS NOT NULL
GROUP BY h.facility_id, h.facility_name, h.state, d.year,
         fr.readmission_rate_pct  -- required for PERCENT_RANK
ORDER BY d.year DESC, avg_readmission_pct DESC;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- END OF SCRIPT 04
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'Script 04 complete — operational efficiency queries ready.' AS status;
GO
