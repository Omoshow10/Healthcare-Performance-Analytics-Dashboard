-- =============================================================================
-- Healthcare Performance Analytics Dashboard
-- Script 02: Data Cleaning & Standardization
-- =============================================================================
-- Description: Cleans staging data, handles nulls/suppressed values,
--              normalizes data types, and loads into core dimension/fact tables.
-- Run Order:   2 of 6 (run after 01_schema_setup.sql)
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- UTILITY: Flag suppressed / not available CMS values
-- CMS uses "Not Available", "Not Applicable", "Too Few to Report" as placeholders
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION analytics.clean_numeric(raw_val TEXT)
RETURNS NUMERIC AS $$
BEGIN
    IF raw_val IS NULL
       OR TRIM(raw_val) IN ('', 'N/A', 'Not Available', 'Not Applicable',
                            'Too Few to Report', 'Footnote Applies', '--')
    THEN RETURN NULL;
    END IF;
    RETURN raw_val::NUMERIC;
EXCEPTION WHEN others THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION analytics.clean_int(raw_val TEXT)
RETURNS INT AS $$
BEGIN
    IF raw_val IS NULL
       OR TRIM(raw_val) IN ('', 'N/A', 'Not Available', 'Not Applicable',
                            'Too Few to Report', 'Footnote Applies', '--')
    THEN RETURN NULL;
    END IF;
    RETURN ROUND(raw_val::NUMERIC)::INT;
EXCEPTION WHEN others THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION analytics.cms_date_to_key(raw_date TEXT)
RETURNS INT AS $$
DECLARE
    parsed_date DATE;
BEGIN
    IF raw_date IS NULL OR TRIM(raw_date) = '' THEN RETURN NULL; END IF;
    -- CMS dates come in multiple formats: MM/DD/YYYY or YYYY-MM-DD
    BEGIN
        parsed_date := TO_DATE(TRIM(raw_date), 'MM/DD/YYYY');
    EXCEPTION WHEN others THEN
        BEGIN
            parsed_date := TO_DATE(TRIM(raw_date), 'YYYY-MM-DD');
        EXCEPTION WHEN others THEN
            RETURN NULL;
        END;
    END;
    RETURN TO_CHAR(parsed_date, 'YYYYMMDD')::INT;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 1: Load dim_hospital from staging.cms_hospital
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO core.dim_hospital (
    facility_id, facility_name, city, state, zip_code, county_name,
    hospital_type, hospital_ownership, emergency_services, overall_rating,
    mortality_group, safety_group, readmission_group, patient_exp_group
)
SELECT DISTINCT ON (facility_id)
    TRIM(facility_id),
    TRIM(facility_name),
    INITCAP(TRIM(city)),
    UPPER(TRIM(state)),
    TRIM(zip_code),
    INITCAP(TRIM(county_name)),
    TRIM(hospital_type),
    TRIM(hospital_ownership),
    CASE UPPER(TRIM(emergency_services)) WHEN 'YES' THEN TRUE ELSE FALSE END,
    analytics.clean_int(hospital_overall_rating::TEXT),
    TRIM(mortality_group),
    TRIM(safety_group),
    TRIM(readmission_group),
    TRIM(patient_exp_group)
FROM staging.cms_hospital
WHERE facility_id IS NOT NULL
  AND TRIM(facility_id) != ''
ORDER BY facility_id, raw_load_ts DESC
ON CONFLICT (facility_id) DO UPDATE SET
    facility_name     = EXCLUDED.facility_name,
    overall_rating    = EXCLUDED.overall_rating,
    readmission_group = EXCLUDED.readmission_group,
    patient_exp_group = EXCLUDED.patient_exp_group,
    updated_at        = NOW();

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 2: Load fact_readmissions from staging.readmissions
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO core.fact_readmissions (
    hospital_key, measure_key,
    start_date_key, end_date_key,
    number_of_discharges, number_of_readmissions,
    predicted_readmission_rate, expected_readmission_rate,
    excess_readmission_ratio, readmission_rate_pct
)
SELECT
    h.hospital_key,
    m.measure_key,
    analytics.cms_date_to_key(r.start_date),
    analytics.cms_date_to_key(r.end_date),
    analytics.clean_int(r.number_of_discharges),
    analytics.clean_int(r.number_of_readmissions),
    analytics.clean_numeric(r.predicted_readmission_rate),
    analytics.clean_numeric(r.expected_readmission_rate),
    analytics.clean_numeric(r.excess_readmission_ratio),
    -- Derive readmission rate pct
    CASE
        WHEN analytics.clean_int(r.number_of_discharges) > 0
        THEN ROUND(
            analytics.clean_int(r.number_of_readmissions)::NUMERIC
            / analytics.clean_int(r.number_of_discharges)::NUMERIC * 100, 2)
        ELSE NULL
    END
FROM staging.readmissions r
JOIN core.dim_hospital h ON TRIM(r.facility_id) = h.facility_id
LEFT JOIN core.dim_measure m
    ON m.measure_id = CASE
        -- Map CMS measure names to standardized measure IDs
        WHEN r.measure_name ILIKE '%Heart Failure%'          THEN 'READM-30-HF-HRRP'
        WHEN r.measure_name ILIKE '%Acute Myocardial%'
          OR r.measure_name ILIKE '%Heart Attack%'           THEN 'READM-30-AMI-HRRP'
        WHEN r.measure_name ILIKE '%Pneumonia%'              THEN 'READM-30-PN-HRRP'
        WHEN r.measure_name ILIKE '%Hip%' OR
             r.measure_name ILIKE '%Knee%'                   THEN 'READM-30-HIP-KNEE'
        WHEN r.measure_name ILIKE '%CABG%'
          OR r.measure_name ILIKE '%Bypass%'                 THEN 'READM-30-CABG'
        WHEN r.measure_name ILIKE '%COPD%'
          OR r.measure_name ILIKE '%Pulmonary%'              THEN 'READM-30-COPD-HRRP'
        ELSE NULL
    END
WHERE TRIM(r.facility_id) != ''
  AND analytics.clean_int(r.number_of_discharges) IS NOT NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 3: Load fact_patient_satisfaction from staging.hcahps
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO core.fact_patient_satisfaction (
    hospital_key, measure_key,
    start_date_key, end_date_key,
    star_rating, answer_percent, completed_surveys, response_rate_pct
)
SELECT
    h.hospital_key,
    m.measure_key,
    analytics.cms_date_to_key(s.start_date),
    analytics.cms_date_to_key(s.end_date),
    analytics.clean_numeric(s.patient_survey_star_rating),
    analytics.clean_numeric(s.hcahps_answer_percent),
    analytics.clean_int(s.number_of_completed_surveys),
    analytics.clean_numeric(s.survey_response_rate_percent)
FROM staging.hcahps s
JOIN core.dim_hospital h  ON TRIM(s.facility_id) = h.facility_id
LEFT JOIN core.dim_measure m ON TRIM(s.hcahps_measure_id) = m.measure_id
WHERE TRIM(s.facility_id) != ''
  AND s.hcahps_measure_id IS NOT NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 4: Load fact_quality_metrics from staging.quality_metrics
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO core.fact_quality_metrics (
    hospital_key, measure_key,
    start_date_key, end_date_key,
    condition, score, lower_estimate, higher_estimate,
    denominator, compared_to_national
)
SELECT
    h.hospital_key,
    m.measure_key,
    analytics.cms_date_to_key(q.start_date),
    analytics.cms_date_to_key(q.end_date),
    TRIM(q.condition),
    analytics.clean_numeric(q.score),
    analytics.clean_numeric(q.lower_estimate),
    analytics.clean_numeric(q.higher_estimate),
    analytics.clean_int(q.denominator),
    TRIM(q.compared_to_national)
FROM staging.quality_metrics q
JOIN core.dim_hospital h  ON TRIM(q.facility_id) = h.facility_id
LEFT JOIN core.dim_measure m ON TRIM(q.measure_id) = m.measure_id
WHERE TRIM(q.facility_id) != ''
  AND q.measure_id IS NOT NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- DATA QUALITY REPORT
-- ─────────────────────────────────────────────────────────────────────────────

SELECT 'dim_hospital'            AS table_name, COUNT(*) AS row_count FROM core.dim_hospital
UNION ALL
SELECT 'fact_readmissions',        COUNT(*) FROM core.fact_readmissions
UNION ALL
SELECT 'fact_patient_satisfaction',COUNT(*) FROM core.fact_patient_satisfaction
UNION ALL
SELECT 'fact_quality_metrics',     COUNT(*) FROM core.fact_quality_metrics
ORDER BY table_name;

-- ─────────────────────────────────────────────────────────────────────────────
-- NULL AUDIT — check for hospitals in facts but not in dim
-- ─────────────────────────────────────────────────────────────────────────────

SELECT 'readmissions with no hospital match' AS issue,
       COUNT(*) AS count
FROM staging.readmissions r
LEFT JOIN core.dim_hospital h ON TRIM(r.facility_id) = h.facility_id
WHERE h.hospital_key IS NULL
  AND TRIM(r.facility_id) != ''

UNION ALL

SELECT 'readmissions with no measure match',
       COUNT(*)
FROM core.fact_readmissions
WHERE measure_key IS NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- END OF SCRIPT 02
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'Script 02 complete — data cleaned and loaded into core schema.' AS status;
