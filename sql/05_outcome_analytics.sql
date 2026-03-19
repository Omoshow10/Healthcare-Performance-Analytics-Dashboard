-- =============================================================================
-- Healthcare Performance Analytics Dashboard
-- Script 05: Outcome Analytics
-- =============================================================================
-- Description: Quality indicators, mortality rates, HAI rates, and peer
--              benchmarking / performance comparisons.
--              Drives the "Outcome Analytics" page of the Power BI dashboard.
-- Run Order:   5 of 6
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION A: QUALITY INDICATORS
-- ─────────────────────────────────────────────────────────────────────────────

-- A1. Mortality Rates by Hospital (Latest Period)
-- ───────────────────────────────────────────────
SELECT
    h.facility_id,
    h.facility_name,
    h.city,
    h.state,
    h.hospital_type,
    h.mortality_group,
    -- Per-condition mortality scores
    MAX(CASE WHEN m.measure_id = 'MORT-30-HF'   THEN qm.score END)  AS mort_heart_failure,
    MAX(CASE WHEN m.measure_id = 'MORT-30-AMI'  THEN qm.score END)  AS mort_acute_mi,
    MAX(CASE WHEN m.measure_id = 'MORT-30-PN'   THEN qm.score END)  AS mort_pneumonia,
    MAX(CASE WHEN m.measure_id = 'MORT-30-COPD' THEN qm.score END)  AS mort_copd,
    MAX(CASE WHEN m.measure_id = 'MORT-30-CABG' THEN qm.score END)  AS mort_cabg,
    -- Overall composite mortality (simple average)
    ROUND(
        AVG(CASE WHEN m.measure_category = 'Mortality' THEN qm.score END), 4
    )                                                                 AS composite_mortality_rate,
    -- National comparison flags
    STRING_AGG(
        CASE WHEN m.measure_category = 'Mortality'
                  AND qm.compared_to_national = 'Worse than the National average'
             THEN m.measure_id ELSE NULL END,
        ', ' ORDER BY m.measure_id
    )                                                                 AS worse_than_national
FROM core.fact_quality_metrics qm
JOIN core.dim_hospital h ON qm.hospital_key = h.hospital_key
JOIN core.dim_measure  m ON qm.measure_key  = m.measure_key
JOIN core.dim_date     d ON qm.end_date_key = d.date_key
WHERE m.measure_category = 'Mortality'
  AND d.year = (SELECT MAX(year) FROM core.dim_date
                WHERE date_key IN (SELECT end_date_key FROM core.fact_quality_metrics))
GROUP BY
    h.facility_id, h.facility_name, h.city, h.state,
    h.hospital_type, h.mortality_group
ORDER BY composite_mortality_rate DESC NULLS LAST;

-- A2. Hospital-Acquired Infection (HAI) Rates by Hospital (Latest Period)
-- ────────────────────────────────────────────────────────────────────────
SELECT
    h.facility_id,
    h.facility_name,
    h.city,
    h.state,
    h.hospital_type,
    h.safety_group,
    -- HAI SIR (Standardized Infection Ratio) scores
    MAX(CASE WHEN m.measure_id = 'HAI-1' THEN qm.score END)         AS clabsi_sir,
    MAX(CASE WHEN m.measure_id = 'HAI-2' THEN qm.score END)         AS cauti_sir,
    MAX(CASE WHEN m.measure_id = 'HAI-3' THEN qm.score END)         AS ssi_colon_sir,
    MAX(CASE WHEN m.measure_id = 'HAI-4' THEN qm.score END)         AS ssi_hysterectomy_sir,
    MAX(CASE WHEN m.measure_id = 'HAI-5' THEN qm.score END)         AS mrsa_sir,
    MAX(CASE WHEN m.measure_id = 'HAI-6' THEN qm.score END)         AS cdiff_sir,
    -- Composite HAI score (lower = better; national benchmark = 1.0)
    ROUND(
        AVG(CASE WHEN m.measure_category = 'Safety' THEN qm.score END), 4
    )                                                                 AS composite_hai_sir,
    -- Count of HAI measures worse than national
    COUNT(
        CASE WHEN m.measure_category = 'Safety'
                  AND qm.compared_to_national = 'Worse than the National average'
             THEN 1 END
    )                                                                 AS hai_worse_than_national_count
FROM core.fact_quality_metrics qm
JOIN core.dim_hospital h ON qm.hospital_key = h.hospital_key
JOIN core.dim_measure  m ON qm.measure_key  = m.measure_key
JOIN core.dim_date     d ON qm.end_date_key = d.date_key
WHERE m.measure_category = 'Safety'
  AND d.year = (SELECT MAX(year) FROM core.dim_date
                WHERE date_key IN (SELECT end_date_key FROM core.fact_quality_metrics))
GROUP BY
    h.facility_id, h.facility_name, h.city, h.state,
    h.hospital_type, h.safety_group
ORDER BY composite_hai_sir DESC NULLS LAST;

-- A3. Quality Indicator Trend — National Averages by Measure, Annual
-- ──────────────────────────────────────────────────────────────────
SELECT
    d.year,
    m.measure_category,
    m.measure_id,
    m.measure_name,
    COUNT(DISTINCT h.hospital_key)                AS hospital_count,
    ROUND(AVG(qm.score), 4)                       AS national_avg_score,
    ROUND(STDDEV(qm.score), 4)                    AS score_std_dev,
    ROUND(MIN(qm.score), 4)                       AS min_score,
    ROUND(MAX(qm.score), 4)                       AS max_score,
    -- Count hospitals in each comparison band
    COUNT(CASE WHEN qm.compared_to_national = 'Better than the National average' THEN 1 END)  AS better_than_national,
    COUNT(CASE WHEN qm.compared_to_national = 'No Different than the National average' THEN 1 END) AS same_as_national,
    COUNT(CASE WHEN qm.compared_to_national = 'Worse than the National average' THEN 1 END)   AS worse_than_national
FROM core.fact_quality_metrics qm
JOIN core.dim_hospital h ON qm.hospital_key = h.hospital_key
JOIN core.dim_measure  m ON qm.measure_key  = m.measure_key
JOIN core.dim_date     d ON qm.end_date_key = d.date_key
GROUP BY d.year, m.measure_category, m.measure_id, m.measure_name
ORDER BY d.year, m.measure_category, m.measure_name;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION B: PERFORMANCE COMPARISONS & BENCHMARKING
-- ─────────────────────────────────────────────────────────────────────────────

-- B1. Overall Performance Scorecard — Hospital vs National Benchmark
-- ──────────────────────────────────────────────────────────────────
WITH readmit_score AS (
    SELECT hospital_key,
           ROUND(AVG(readmission_rate_pct), 2) AS avg_readmission_pct
    FROM core.fact_readmissions
    GROUP BY hospital_key
),
satisfaction_score AS (
    SELECT fs.hospital_key,
           MAX(CASE WHEN m.measure_id = 'H-HSP-RATING-9-10' THEN fs.star_rating END) AS overall_stars
    FROM core.fact_patient_satisfaction fs
    JOIN core.dim_measure m ON fs.measure_key = m.measure_key
    GROUP BY fs.hospital_key
),
quality_score AS (
    SELECT
        hospital_key,
        COUNT(CASE WHEN compared_to_national = 'Better than the National average' THEN 1 END)  AS quality_better,
        COUNT(CASE WHEN compared_to_national = 'Worse than the National average'  THEN 1 END)  AS quality_worse,
        COUNT(*)                                                                                 AS quality_total
    FROM core.fact_quality_metrics
    GROUP BY hospital_key
)
SELECT
    h.facility_id,
    h.facility_name,
    h.city,
    h.state,
    h.hospital_type,
    h.hospital_ownership,
    h.overall_rating,
    -- Performance dimensions
    rs.avg_readmission_pct,
    ss.overall_stars,
    qs.quality_better,
    qs.quality_worse,
    qs.quality_total,
    ROUND(qs.quality_better::NUMERIC / NULLIF(qs.quality_total, 0) * 100, 1) AS pct_quality_above_national,
    -- Composite performance tier
    CASE
        WHEN h.overall_rating >= 4
             AND COALESCE(rs.avg_readmission_pct, 99) < 15
             AND COALESCE(ss.overall_stars, 0) >= 4          THEN 'Top Performer'
        WHEN h.overall_rating >= 3
             AND COALESCE(rs.avg_readmission_pct, 99) < 18   THEN 'Above Average'
        WHEN h.overall_rating = 3
             OR (rs.avg_readmission_pct BETWEEN 15 AND 20)   THEN 'Average'
        WHEN h.overall_rating <= 2
             OR COALESCE(rs.avg_readmission_pct, 0) > 20     THEN 'Below Average'
        ELSE 'Insufficient Data'
    END                                                       AS performance_tier
FROM core.dim_hospital h
LEFT JOIN readmit_score     rs ON h.hospital_key = rs.hospital_key
LEFT JOIN satisfaction_score ss ON h.hospital_key = ss.hospital_key
LEFT JOIN quality_score     qs ON h.hospital_key = qs.hospital_key
ORDER BY h.overall_rating DESC NULLS LAST, rs.avg_readmission_pct ASC NULLS LAST;

-- B2. State-Level Peer Benchmarking
-- ─────────────────────────────────
SELECT
    h.state,
    COUNT(DISTINCT h.hospital_key)                          AS hospital_count,
    -- Readmissions
    ROUND(AVG(fr.readmission_rate_pct), 2)                  AS state_avg_readmission_pct,
    ROUND(AVG(fr.excess_readmission_ratio), 4)              AS state_avg_excess_ratio,
    -- Satisfaction
    ROUND(AVG(fs.star_rating), 2)                           AS state_avg_star_rating,
    -- Quality
    ROUND(AVG(CASE WHEN m_q.measure_category = 'Mortality'
                   THEN qm.score END), 4)                   AS state_avg_mortality,
    ROUND(AVG(CASE WHEN m_q.measure_category = 'Safety'
                   THEN qm.score END), 4)                   AS state_avg_hai_sir,
    -- Overall rating distribution
    COUNT(CASE WHEN h.overall_rating = 5 THEN 1 END)       AS five_star_hospitals,
    COUNT(CASE WHEN h.overall_rating = 4 THEN 1 END)       AS four_star_hospitals,
    COUNT(CASE WHEN h.overall_rating <= 2 THEN 1 END)      AS low_rated_hospitals
FROM core.dim_hospital h
LEFT JOIN core.fact_readmissions fr        ON h.hospital_key = fr.hospital_key
LEFT JOIN core.fact_patient_satisfaction fs ON h.hospital_key = fs.hospital_key
LEFT JOIN core.fact_quality_metrics qm     ON h.hospital_key = qm.hospital_key
LEFT JOIN core.dim_measure m_q             ON qm.measure_key = m_q.measure_key
GROUP BY h.state
ORDER BY state_avg_readmission_pct ASC NULLS LAST;

-- B3. Hospital Type Comparison (Teaching vs Community vs Critical Access)
-- ─────────────────────────────────────────────────────────────────────
SELECT
    h.hospital_type,
    COUNT(DISTINCT h.hospital_key)                  AS hospital_count,
    ROUND(AVG(fr.excess_readmission_ratio), 4)      AS avg_excess_readmission_ratio,
    ROUND(AVG(fr.readmission_rate_pct), 2)          AS avg_readmission_pct,
    ROUND(AVG(fs.star_rating), 2)                   AS avg_satisfaction_stars,
    ROUND(AVG(CASE WHEN m.measure_category = 'Mortality'
                   THEN qm.score END), 4)           AS avg_mortality_rate,
    ROUND(AVG(CASE WHEN m.measure_category = 'Safety'
                   THEN qm.score END), 4)           AS avg_hai_sir
FROM core.dim_hospital h
LEFT JOIN core.fact_readmissions fr        ON h.hospital_key = fr.hospital_key
LEFT JOIN core.fact_patient_satisfaction fs ON h.hospital_key = fs.hospital_key
LEFT JOIN core.fact_quality_metrics qm     ON h.hospital_key = qm.hospital_key
LEFT JOIN core.dim_measure m               ON qm.measure_key = m.measure_key
GROUP BY h.hospital_type
ORDER BY avg_readmission_pct ASC NULLS LAST;

-- ─────────────────────────────────────────────────────────────────────────────
-- END OF SCRIPT 05
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'Script 05 complete — outcome analytics queries ready.' AS status;
