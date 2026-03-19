-- =============================================================================
-- Healthcare Performance Analytics Dashboard
-- Script 06: Reusable Views & Aggregates for Power BI and Excel
-- =============================================================================
-- Description: Creates analytics-schema views that Power BI and Excel connect
--              to directly. Views are denormalized for fast dashboard queries.
-- Run Order:   6 of 6 (final script)
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- VIEW 1: vw_hospital_scorecard
-- One row per hospital — primary data source for the overview dashboard page
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW analytics.vw_hospital_scorecard AS
WITH latest_readmit AS (
    SELECT
        fr.hospital_key,
        ROUND(AVG(fr.readmission_rate_pct), 2)      AS avg_readmission_rate_pct,
        ROUND(AVG(fr.excess_readmission_ratio), 4)  AS avg_excess_ratio,
        SUM(fr.number_of_discharges)                AS total_discharges,
        SUM(fr.number_of_readmissions)              AS total_readmissions
    FROM core.fact_readmissions fr
    JOIN core.dim_date d ON fr.end_date_key = d.date_key
    WHERE d.year = (SELECT MAX(year) FROM core.dim_date
                    WHERE date_key IN (SELECT end_date_key FROM core.fact_readmissions))
    GROUP BY fr.hospital_key
),
latest_satisfaction AS (
    SELECT
        fs.hospital_key,
        MAX(CASE WHEN m.measure_id = 'H-HSP-RATING-9-10' THEN fs.star_rating END)   AS overall_star_rating,
        MAX(CASE WHEN m.measure_id = 'H-RECMND-DY'       THEN fs.answer_percent END) AS pct_would_recommend,
        ROUND(AVG(CASE WHEN m.measure_id IN
                            ('H-COMP-1-A-P','H-COMP-2-A-P','H-COMP-3-A-P','H-COMP-5-A-P')
                       THEN fs.answer_percent END), 1)                               AS avg_communication_pct,
        ROUND(AVG(CASE WHEN m.measure_id IN ('H-CLEAN-HSP-A-P','H-QUIET-HSP-A-P')
                       THEN fs.answer_percent END), 1)                               AS avg_environment_pct
    FROM core.fact_patient_satisfaction fs
    JOIN core.dim_measure m ON fs.measure_key = m.measure_key
    JOIN core.dim_date    d ON fs.end_date_key = d.date_key
    WHERE d.year = (SELECT MAX(year) FROM core.dim_date
                    WHERE date_key IN (SELECT end_date_key FROM core.fact_patient_satisfaction))
    GROUP BY fs.hospital_key
),
latest_quality AS (
    SELECT
        qm.hospital_key,
        ROUND(AVG(CASE WHEN m.measure_category = 'Mortality' THEN qm.score END), 4) AS avg_mortality_rate,
        ROUND(AVG(CASE WHEN m.measure_category = 'Safety'    THEN qm.score END), 4) AS avg_hai_sir,
        COUNT(CASE WHEN qm.compared_to_national = 'Better than the National average' THEN 1 END) AS quality_above_national,
        COUNT(CASE WHEN qm.compared_to_national = 'Worse than the National average'  THEN 1 END) AS quality_below_national,
        COUNT(*)                                                                      AS quality_measures_total
    FROM core.fact_quality_metrics qm
    JOIN core.dim_measure m ON qm.measure_key = m.measure_key
    JOIN core.dim_date    d ON qm.end_date_key = d.date_key
    WHERE d.year = (SELECT MAX(year) FROM core.dim_date
                    WHERE date_key IN (SELECT end_date_key FROM core.fact_quality_metrics))
    GROUP BY qm.hospital_key
)
SELECT
    h.facility_id,
    h.facility_name,
    h.city,
    h.state,
    h.zip_code,
    h.county_name,
    h.hospital_type,
    h.hospital_ownership,
    h.emergency_services,
    h.overall_rating,
    h.readmission_group,
    h.safety_group,
    h.mortality_group,
    h.patient_exp_group,
    -- Readmission metrics
    r.avg_readmission_rate_pct,
    r.avg_excess_ratio,
    r.total_discharges,
    r.total_readmissions,
    -- Satisfaction metrics
    s.overall_star_rating,
    s.pct_would_recommend,
    s.avg_communication_pct,
    s.avg_environment_pct,
    -- Quality metrics
    q.avg_mortality_rate,
    q.avg_hai_sir,
    q.quality_above_national,
    q.quality_below_national,
    q.quality_measures_total,
    ROUND(q.quality_above_national::NUMERIC / NULLIF(q.quality_measures_total, 0) * 100, 1) AS pct_above_national,
    -- Performance tier
    CASE
        WHEN h.overall_rating >= 4
             AND COALESCE(r.avg_readmission_rate_pct, 99) < 15
             AND COALESCE(s.overall_star_rating, 0) >= 4     THEN 'Top Performer'
        WHEN h.overall_rating >= 3
             AND COALESCE(r.avg_readmission_rate_pct, 99) < 18 THEN 'Above Average'
        WHEN h.overall_rating = 3
             OR (r.avg_readmission_rate_pct BETWEEN 15 AND 20) THEN 'Average'
        WHEN h.overall_rating <= 2
             OR COALESCE(r.avg_readmission_rate_pct, 0) > 20 THEN 'Below Average'
        ELSE 'Insufficient Data'
    END                                                       AS performance_tier
FROM core.dim_hospital h
LEFT JOIN latest_readmit    r ON h.hospital_key = r.hospital_key
LEFT JOIN latest_satisfaction s ON h.hospital_key = s.hospital_key
LEFT JOIN latest_quality    q ON h.hospital_key = q.hospital_key;

COMMENT ON VIEW analytics.vw_hospital_scorecard IS
'One row per hospital — primary source for Power BI Overview page. Joins latest readmission, satisfaction, and quality metrics.';

-- ─────────────────────────────────────────────────────────────────────────────
-- VIEW 2: vw_readmission_trends
-- Annual readmission trends by state, condition, and hospital type
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW analytics.vw_readmission_trends AS
SELECT
    d.year,
    d.quarter,
    h.state,
    h.hospital_type,
    m.measure_id,
    m.measure_name,
    CASE
        WHEN m.measure_name ILIKE '%Heart Failure%'     THEN 'Heart Failure'
        WHEN m.measure_name ILIKE '%Acute Myocardial%'
          OR m.measure_name ILIKE '%Heart Attack%'      THEN 'Acute MI'
        WHEN m.measure_name ILIKE '%Pneumonia%'         THEN 'Pneumonia'
        WHEN m.measure_name ILIKE '%Hip%'
          OR m.measure_name ILIKE '%Knee%'              THEN 'Orthopaedics'
        WHEN m.measure_name ILIKE '%CABG%'              THEN 'Cardiac Surgery'
        WHEN m.measure_name ILIKE '%COPD%'              THEN 'Pulmonary'
        ELSE 'Other'
    END                                                 AS clinical_category,
    COUNT(DISTINCT h.hospital_key)                      AS hospital_count,
    SUM(fr.number_of_discharges)                        AS total_discharges,
    SUM(fr.number_of_readmissions)                      AS total_readmissions,
    ROUND(AVG(fr.readmission_rate_pct), 2)              AS avg_readmission_pct,
    ROUND(AVG(fr.excess_readmission_ratio), 4)          AS avg_excess_ratio,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP
          (ORDER BY fr.readmission_rate_pct), 2)        AS median_readmission_pct
FROM core.fact_readmissions fr
JOIN core.dim_hospital h ON fr.hospital_key = h.hospital_key
JOIN core.dim_measure  m ON fr.measure_key  = m.measure_key
JOIN core.dim_date     d ON fr.end_date_key = d.date_key
WHERE fr.number_of_discharges IS NOT NULL
GROUP BY d.year, d.quarter, h.state, h.hospital_type, m.measure_id, m.measure_name;

COMMENT ON VIEW analytics.vw_readmission_trends IS
'Annual readmission trends by state, hospital type, and clinical condition. Drives trend line charts in Power BI.';

-- ─────────────────────────────────────────────────────────────────────────────
-- VIEW 3: vw_quality_summary
-- Rolled-up quality and safety measures for dashboard KPI cards
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW analytics.vw_quality_summary AS
SELECT
    d.year,
    h.state,
    h.hospital_type,
    m.measure_category,
    m.measure_id,
    m.measure_name,
    COUNT(DISTINCT h.hospital_key)                                   AS hospital_count,
    ROUND(AVG(qm.score), 4)                                          AS national_avg_score,
    ROUND(STDDEV(qm.score), 4)                                       AS score_std_dev,
    ROUND(MIN(qm.score), 4)                                          AS min_score,
    ROUND(MAX(qm.score), 4)                                          AS max_score,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY qm.score), 4) AS median_score,
    COUNT(CASE WHEN qm.compared_to_national = 'Better than the National average' THEN 1 END)      AS hospitals_better,
    COUNT(CASE WHEN qm.compared_to_national = 'No Different than the National average' THEN 1 END) AS hospitals_same,
    COUNT(CASE WHEN qm.compared_to_national = 'Worse than the National average'  THEN 1 END)      AS hospitals_worse,
    ROUND(COUNT(CASE WHEN qm.compared_to_national = 'Better than the National average' THEN 1 END)::NUMERIC
          / NULLIF(COUNT(*), 0) * 100, 1)                            AS pct_better_than_national
FROM core.fact_quality_metrics qm
JOIN core.dim_hospital h ON qm.hospital_key = h.hospital_key
JOIN core.dim_measure  m ON qm.measure_key  = m.measure_key
JOIN core.dim_date     d ON qm.end_date_key = d.date_key
WHERE qm.score IS NOT NULL
GROUP BY d.year, h.state, h.hospital_type, m.measure_category, m.measure_id, m.measure_name;

COMMENT ON VIEW analytics.vw_quality_summary IS
'Quality and safety measure aggregates by year, state, and hospital type. Drives KPI cards and quality heatmaps.';

-- ─────────────────────────────────────────────────────────────────────────────
-- VIEW 4: vw_satisfaction_detail
-- HCAHPS domain-level scores for comparison and drill-through
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW analytics.vw_satisfaction_detail AS
SELECT
    d.year,
    h.facility_id,
    h.facility_name,
    h.city,
    h.state,
    h.hospital_type,
    h.patient_exp_group,
    m.measure_id,
    m.measure_name,
    ROUND(AVG(fs.star_rating), 2)    AS avg_star_rating,
    ROUND(AVG(fs.answer_percent), 1) AS avg_answer_pct,
    MAX(fs.completed_surveys)        AS completed_surveys,
    MAX(fs.response_rate_pct)        AS response_rate_pct
FROM core.fact_patient_satisfaction fs
JOIN core.dim_hospital h ON fs.hospital_key = h.hospital_key
JOIN core.dim_measure  m ON fs.measure_key  = m.measure_key
JOIN core.dim_date     d ON fs.end_date_key = d.date_key
GROUP BY
    d.year, h.facility_id, h.facility_name, h.city, h.state,
    h.hospital_type, h.patient_exp_group, m.measure_id, m.measure_name;

COMMENT ON VIEW analytics.vw_satisfaction_detail IS
'HCAHPS survey scores at hospital + measure level. Supports domain drill-through and star rating distribution charts.';

-- ─────────────────────────────────────────────────────────────────────────────
-- VIEW 5: vw_state_benchmark
-- State-level summary for choropleth map and state comparison tables
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW analytics.vw_state_benchmark AS
SELECT
    h.state,
    COUNT(DISTINCT h.hospital_key)                       AS hospital_count,
    ROUND(AVG(h.overall_rating::NUMERIC), 2)             AS avg_overall_rating,
    -- Readmissions
    ROUND(AVG(fr.readmission_rate_pct), 2)               AS avg_readmission_pct,
    ROUND(AVG(fr.excess_readmission_ratio), 4)           AS avg_excess_ratio,
    SUM(fr.number_of_discharges)                         AS total_discharges,
    -- Satisfaction
    ROUND(AVG(fs.star_rating), 2)                        AS avg_star_rating,
    ROUND(AVG(CASE WHEN m_s.measure_id = 'H-RECMND-DY'
                   THEN fs.answer_percent END), 1)       AS avg_pct_recommend,
    -- Quality
    ROUND(AVG(CASE WHEN m_q.measure_category = 'Mortality'
                   THEN qm.score END), 4)                AS avg_mortality_rate,
    ROUND(AVG(CASE WHEN m_q.measure_category = 'Safety'
                   THEN qm.score END), 4)                AS avg_hai_sir,
    -- Rating distribution
    COUNT(CASE WHEN h.overall_rating = 5 THEN 1 END)    AS hospitals_5star,
    COUNT(CASE WHEN h.overall_rating = 4 THEN 1 END)    AS hospitals_4star,
    COUNT(CASE WHEN h.overall_rating = 3 THEN 1 END)    AS hospitals_3star,
    COUNT(CASE WHEN h.overall_rating <= 2 THEN 1 END)   AS hospitals_1_2star
FROM core.dim_hospital h
LEFT JOIN core.fact_readmissions fr        ON h.hospital_key = fr.hospital_key
LEFT JOIN core.fact_patient_satisfaction fs ON h.hospital_key = fs.hospital_key
LEFT JOIN core.dim_measure m_s             ON fs.measure_key = m_s.measure_key
LEFT JOIN core.fact_quality_metrics qm     ON h.hospital_key = qm.hospital_key
LEFT JOIN core.dim_measure m_q             ON qm.measure_key = m_q.measure_key
GROUP BY h.state;

COMMENT ON VIEW analytics.vw_state_benchmark IS
'State-level aggregates for choropleth maps and state comparison tables in Power BI.';

-- ─────────────────────────────────────────────────────────────────────────────
-- GRANT READ ACCESS TO REPORTING ROLE
-- (Uncomment and replace 'powerbi_reader' with your service account name)
-- ─────────────────────────────────────────────────────────────────────────────

-- CREATE ROLE powerbi_reader;
-- GRANT USAGE ON SCHEMA analytics TO powerbi_reader;
-- GRANT USAGE ON SCHEMA core      TO powerbi_reader;
-- GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO powerbi_reader;
-- GRANT SELECT ON ALL TABLES IN SCHEMA core      TO powerbi_reader;

-- ─────────────────────────────────────────────────────────────────────────────
-- VERIFY VIEWS
-- ─────────────────────────────────────────────────────────────────────────────

SELECT schemaname, viewname, pg_size_pretty(0) AS est_size
FROM pg_views
WHERE schemaname = 'analytics'
ORDER BY viewname;

-- ─────────────────────────────────────────────────────────────────────────────
-- END OF SCRIPT 06
-- All SQL objects created. Ready to connect Power BI to analytics.* views.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'Script 06 complete — all analytics views created. Database setup complete!' AS status;
