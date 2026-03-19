-- =============================================================================
-- Healthcare Performance Analytics Dashboard
-- Script 04: Operational Efficiency
-- =============================================================================
-- Description: Queries for patient volume trends and department utilization.
--              Drives the "Operational Efficiency" page of the Power BI dashboard.
-- Run Order:   4 of 6
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION A: PATIENT VOLUME TRENDS
-- ─────────────────────────────────────────────────────────────────────────────

-- A1. Annual Discharge Volume by Hospital (for period-over-period comparison)
-- ──────────────────────────────────────────────────────────────────────────
SELECT
    d.year,
    h.state,
    h.hospital_type,
    COUNT(DISTINCT h.hospital_key)        AS hospital_count,
    SUM(fr.number_of_discharges)          AS total_discharges,
    ROUND(AVG(fr.number_of_discharges), 0) AS avg_discharges_per_hospital,
    SUM(fr.number_of_readmissions)        AS total_readmissions
FROM core.fact_readmissions fr
JOIN core.dim_hospital h ON fr.hospital_key = h.hospital_key
JOIN core.dim_date     d ON fr.end_date_key = d.date_key
WHERE fr.number_of_discharges IS NOT NULL
GROUP BY d.year, h.state, h.hospital_type
ORDER BY d.year, h.state, h.hospital_type;

-- A2. YoY Volume Growth Rate by Hospital
-- ──────────────────────────────────────
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
    curr.year                                               AS current_year,
    curr.total_discharges                                   AS current_discharges,
    prev.total_discharges                                   AS prior_year_discharges,
    curr.total_discharges - prev.total_discharges           AS volume_change,
    ROUND(
        (curr.total_discharges - prev.total_discharges)::NUMERIC
        / NULLIF(prev.total_discharges, 0) * 100, 2
    )                                                       AS yoy_growth_pct
FROM annual_vol curr
LEFT JOIN annual_vol prev
    ON  curr.facility_id = prev.facility_id
    AND curr.year        = prev.year + 1
ORDER BY curr.year DESC, yoy_growth_pct DESC NULLS LAST;

-- A3. Monthly Discharge Volume — Rolling 24 Months (National)
-- ──────────────────────────────────────────────────────────
-- Note: CMS data is typically annual; this approximates monthly from annual totals.
-- For true monthly, connect to a supplemental inpatient discharge dataset.
SELECT
    d.year,
    d.month,
    d.month_name,
    h.state,
    SUM(fr.number_of_discharges)          AS estimated_monthly_discharges,
    COUNT(DISTINCT h.hospital_key)        AS reporting_hospitals
FROM core.fact_readmissions fr
JOIN core.dim_hospital h ON fr.hospital_key = h.hospital_key
JOIN core.dim_date     d ON fr.end_date_key = d.date_key
WHERE d.year >= (SELECT MAX(year) - 1 FROM core.dim_date
                 WHERE date_key IN (SELECT end_date_key FROM core.fact_readmissions))
  AND d.month = 12   -- Use Dec (end of period) for annual proxy
GROUP BY d.year, d.month, d.month_name, h.state
ORDER BY d.year, d.month, h.state;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION B: DEPARTMENT / CONDITION UTILIZATION
-- ─────────────────────────────────────────────────────────────────────────────

-- B1. Discharge Volume by Clinical Condition (Measure Category Proxy)
-- ──────────────────────────────────────────────────────────────────
SELECT
    d.year,
    -- Derive clinical category from measure name
    CASE
        WHEN m.measure_name ILIKE '%Heart Failure%'         THEN 'Heart Failure'
        WHEN m.measure_name ILIKE '%Acute Myocardial%'
          OR m.measure_name ILIKE '%Heart Attack%'          THEN 'Acute MI'
        WHEN m.measure_name ILIKE '%Pneumonia%'             THEN 'Pneumonia'
        WHEN m.measure_name ILIKE '%Hip%'
          OR m.measure_name ILIKE '%Knee%'                  THEN 'Orthopaedics'
        WHEN m.measure_name ILIKE '%CABG%'
          OR m.measure_name ILIKE '%Bypass%'                THEN 'Cardiac Surgery'
        WHEN m.measure_name ILIKE '%COPD%'
          OR m.measure_name ILIKE '%Pulmonary%'             THEN 'Pulmonary'
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
GROUP BY d.year, clinical_category, h.state
ORDER BY d.year, total_discharges DESC;

-- B2. Utilization Intensity Index — Hospitals Sorted by Discharge Density
-- ───────────────────────────────────────────────────────────────────────
-- Discharge density = discharges per condition tracked (proxy for case mix breadth)
WITH condition_counts AS (
    SELECT
        h.facility_id,
        h.facility_name,
        h.city,
        h.state,
        h.hospital_type,
        d.year,
        SUM(fr.number_of_discharges)        AS total_discharges,
        COUNT(DISTINCT m.measure_key)       AS conditions_tracked,
        SUM(fr.number_of_readmissions)      AS total_readmissions
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
    ROUND(total_discharges::NUMERIC / NULLIF(conditions_tracked, 0), 0) AS discharge_density,
    ROUND(total_readmissions::NUMERIC / NULLIF(total_discharges, 0) * 100, 2) AS overall_readmit_pct,
    -- Utilization tier
    CASE
        WHEN total_discharges >= 10000 THEN 'High Volume'
        WHEN total_discharges >= 5000  THEN 'Mid Volume'
        WHEN total_discharges >= 1000  THEN 'Low-Mid Volume'
        ELSE 'Low Volume'
    END                                     AS volume_tier
FROM condition_counts
ORDER BY year DESC, total_discharges DESC;

-- B3. Bed Utilization Proxy — Readmission Burden per Discharge Block
-- ─────────────────────────────────────────────────────────────────
-- Estimates the additional patient days generated by preventable readmissions
-- using the national average LOS of 4.6 days as a constant proxy.
-- Replace 4.6 with actual LOS data if a supplemental dataset is available.
SELECT
    h.facility_id,
    h.facility_name,
    h.state,
    d.year,
    SUM(fr.number_of_discharges)                                    AS total_discharges,
    SUM(fr.number_of_readmissions)                                  AS total_readmissions,
    ROUND(AVG(fr.readmission_rate_pct), 2)                          AS avg_readmission_pct,
    -- Estimated additional bed-days from readmissions (4.6 day avg LOS proxy)
    ROUND(SUM(fr.number_of_readmissions) * 4.6, 0)                 AS est_readmission_bed_days,
    -- Readmission burden score (0-100 relative index within dataset)
    ROUND(
        PERCENT_RANK() OVER (
            PARTITION BY d.year
            ORDER BY AVG(fr.readmission_rate_pct) ASC NULLS LAST
        ) * 100, 1
    )                                                               AS efficiency_percentile
FROM core.fact_readmissions fr
JOIN core.dim_hospital h ON fr.hospital_key = h.hospital_key
JOIN core.dim_date     d ON fr.end_date_key = d.date_key
WHERE fr.number_of_discharges IS NOT NULL
GROUP BY h.facility_id, h.facility_name, h.state, d.year
ORDER BY d.year DESC, avg_readmission_pct DESC NULLS LAST;

-- ─────────────────────────────────────────────────────────────────────────────
-- END OF SCRIPT 04
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'Script 04 complete — operational efficiency queries ready.' AS status;
