-- =============================================================================
-- Healthcare Performance Analytics Dashboard
-- Script 02: Data Cleaning & Standardization
-- =============================================================================
-- Description: Cleans staging data, handles nulls/suppressed values,
--              normalizes data types, and loads into core dimension/fact tables.
-- Database:    Microsoft SQL Server 2019+
-- Run Order:   2 of 6 (run after 01_schema_setup.sql)
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- UTILITY FUNCTIONS
-- CMS uses "Not Available", "Not Applicable", "Too Few to Report" as placeholders
-- SQL Server uses inline CASE expressions instead of stored functions for
-- type-safe cleaning across all INSERT statements below.
-- ─────────────────────────────────────────────────────────────────────────────

-- Helper: convert CMS date strings (MM/DD/YYYY or YYYY-MM-DD) to YYYYMMDD INT
-- Used inline via TRY_CAST and TRY_CONVERT throughout this script.

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 1: Load dim_hospital from staging.cms_hospital
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO core.dim_hospital (
    facility_id, facility_name, city, state, zip_code, county_name,
    hospital_type, hospital_ownership, emergency_services, overall_rating,
    mortality_group, safety_group, readmission_group, patient_exp_group
)
SELECT
    LTRIM(RTRIM(facility_id)),
    LTRIM(RTRIM(facility_name)),
    -- INITCAP equivalent in SQL Server using proper casing
    UPPER(LEFT(LTRIM(RTRIM(city)), 1)) + LOWER(SUBSTRING(LTRIM(RTRIM(city)), 2, LEN(city))),
    UPPER(LTRIM(RTRIM(state))),
    LTRIM(RTRIM(zip_code)),
    UPPER(LEFT(LTRIM(RTRIM(county_name)), 1)) + LOWER(SUBSTRING(LTRIM(RTRIM(county_name)), 2, LEN(county_name))),
    LTRIM(RTRIM(hospital_type)),
    LTRIM(RTRIM(hospital_ownership)),
    CASE WHEN UPPER(LTRIM(RTRIM(emergency_services))) = 'YES' THEN 1 ELSE 0 END,
    hospital_overall_rating,
    LTRIM(RTRIM(mortality_group)),
    LTRIM(RTRIM(safety_group)),
    LTRIM(RTRIM(readmission_group)),
    LTRIM(RTRIM(patient_exp_group))
FROM (
    -- Deduplicate: keep latest load per facility_id
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY facility_id ORDER BY raw_load_ts DESC) AS rn
    FROM staging.cms_hospital
    WHERE facility_id IS NOT NULL
      AND LTRIM(RTRIM(facility_id)) != ''
) AS deduped
WHERE rn = 1
  AND NOT EXISTS (
      SELECT 1 FROM core.dim_hospital dh
      WHERE dh.facility_id = LTRIM(RTRIM(deduped.facility_id))
  );
GO

-- Update existing hospitals with fresh data
UPDATE core.dim_hospital
SET
    facility_name     = LTRIM(RTRIM(s.facility_name)),
    overall_rating    = s.hospital_overall_rating,
    readmission_group = LTRIM(RTRIM(s.readmission_group)),
    patient_exp_group = LTRIM(RTRIM(s.patient_exp_group)),
    updated_at        = GETDATE()
FROM core.dim_hospital dh
INNER JOIN (
    SELECT facility_id, facility_name, hospital_overall_rating,
           readmission_group, patient_exp_group,
           ROW_NUMBER() OVER (PARTITION BY facility_id ORDER BY raw_load_ts DESC) AS rn
    FROM staging.cms_hospital
) AS s ON dh.facility_id = LTRIM(RTRIM(s.facility_id))
WHERE s.rn = 1;
GO

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
    -- Convert CMS date string to YYYYMMDD integer key
    TRY_CAST(FORMAT(TRY_CONVERT(DATE, r.start_date, 101), 'yyyyMMdd') AS INT),
    TRY_CAST(FORMAT(TRY_CONVERT(DATE, r.end_date,   101), 'yyyyMMdd') AS INT),
    -- Clean suppressed numeric values
    CASE WHEN r.number_of_discharges IN ('N/A','Not Available','Not Applicable',
         'Too Few to Report','Footnote Applies','--','') THEN NULL
         ELSE TRY_CAST(r.number_of_discharges AS INT) END,
    CASE WHEN r.number_of_readmissions IN ('N/A','Not Available','Not Applicable',
         'Too Few to Report','Footnote Applies','--','') THEN NULL
         ELSE TRY_CAST(r.number_of_readmissions AS INT) END,
    CASE WHEN r.predicted_readmission_rate IN ('N/A','Not Available','Not Applicable',
         'Too Few to Report','Footnote Applies','--','') THEN NULL
         ELSE TRY_CAST(r.predicted_readmission_rate AS DECIMAL(8,4)) END,
    CASE WHEN r.expected_readmission_rate IN ('N/A','Not Available','Not Applicable',
         'Too Few to Report','Footnote Applies','--','') THEN NULL
         ELSE TRY_CAST(r.expected_readmission_rate AS DECIMAL(8,4)) END,
    CASE WHEN r.excess_readmission_ratio IN ('N/A','Not Available','Not Applicable',
         'Too Few to Report','Footnote Applies','--','') THEN NULL
         ELSE TRY_CAST(r.excess_readmission_ratio AS DECIMAL(8,4)) END,
    -- Derive readmission rate pct
    CASE
        WHEN TRY_CAST(r.number_of_discharges AS INT) > 0
         AND TRY_CAST(r.number_of_readmissions AS INT) IS NOT NULL
        THEN ROUND(
            CAST(TRY_CAST(r.number_of_readmissions AS INT) AS DECIMAL(10,4))
            / CAST(TRY_CAST(r.number_of_discharges AS INT) AS DECIMAL(10,4)) * 100, 2)
        ELSE NULL
    END
FROM staging.readmissions r
JOIN core.dim_hospital h ON LTRIM(RTRIM(r.facility_id)) = h.facility_id
LEFT JOIN core.dim_measure m
    ON m.measure_id = CASE
        -- Map CMS measure names to standardized measure IDs
        WHEN r.measure_name LIKE '%Heart Failure%'               THEN 'READM-30-HF-HRRP'
        WHEN r.measure_name LIKE '%Acute Myocardial%'
          OR r.measure_name LIKE '%Heart Attack%'                THEN 'READM-30-AMI-HRRP'
        WHEN r.measure_name LIKE '%Pneumonia%'                   THEN 'READM-30-PN-HRRP'
        WHEN r.measure_name LIKE '%Hip%'
          OR r.measure_name LIKE '%Knee%'                        THEN 'READM-30-HIP-KNEE'
        WHEN r.measure_name LIKE '%CABG%'
          OR r.measure_name LIKE '%Bypass%'                      THEN 'READM-30-CABG'
        WHEN r.measure_name LIKE '%COPD%'
          OR r.measure_name LIKE '%Pulmonary%'                   THEN 'READM-30-COPD-HRRP'
        ELSE NULL
    END
WHERE LTRIM(RTRIM(r.facility_id)) != ''
  AND TRY_CAST(r.number_of_discharges AS INT) IS NOT NULL;
GO

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
    TRY_CAST(FORMAT(TRY_CONVERT(DATE, s.start_date, 101), 'yyyyMMdd') AS INT),
    TRY_CAST(FORMAT(TRY_CONVERT(DATE, s.end_date,   101), 'yyyyMMdd') AS INT),
    CASE WHEN s.patient_survey_star_rating IN ('N/A','Not Available','Not Applicable',
         'Too Few to Report','Footnote Applies','--','') THEN NULL
         ELSE TRY_CAST(s.patient_survey_star_rating AS DECIMAL(3,1)) END,
    CASE WHEN s.hcahps_answer_percent IN ('N/A','Not Available','Not Applicable',
         'Too Few to Report','Footnote Applies','--','') THEN NULL
         ELSE TRY_CAST(s.hcahps_answer_percent AS DECIMAL(5,2)) END,
    CASE WHEN s.number_of_completed_surveys IN ('N/A','Not Available','Not Applicable',
         'Too Few to Report','Footnote Applies','--','') THEN NULL
         ELSE TRY_CAST(s.number_of_completed_surveys AS INT) END,
    CASE WHEN s.survey_response_rate_percent IN ('N/A','Not Available','Not Applicable',
         'Too Few to Report','Footnote Applies','--','') THEN NULL
         ELSE TRY_CAST(s.survey_response_rate_percent AS DECIMAL(5,2)) END
FROM staging.hcahps s
JOIN core.dim_hospital h  ON LTRIM(RTRIM(s.facility_id)) = h.facility_id
LEFT JOIN core.dim_measure m ON LTRIM(RTRIM(s.hcahps_measure_id)) = m.measure_id
WHERE LTRIM(RTRIM(s.facility_id)) != ''
  AND s.hcahps_measure_id IS NOT NULL;
GO

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
    TRY_CAST(FORMAT(TRY_CONVERT(DATE, q.start_date, 101), 'yyyyMMdd') AS INT),
    TRY_CAST(FORMAT(TRY_CONVERT(DATE, q.end_date,   101), 'yyyyMMdd') AS INT),
    LTRIM(RTRIM(q.condition)),
    CASE WHEN q.score IN ('N/A','Not Available','Not Applicable',
         'Too Few to Report','Footnote Applies','--','') THEN NULL
         ELSE TRY_CAST(q.score AS DECIMAL(10,4)) END,
    CASE WHEN q.lower_estimate IN ('N/A','Not Available','Not Applicable',
         'Too Few to Report','Footnote Applies','--','') THEN NULL
         ELSE TRY_CAST(q.lower_estimate AS DECIMAL(10,4)) END,
    CASE WHEN q.higher_estimate IN ('N/A','Not Available','Not Applicable',
         'Too Few to Report','Footnote Applies','--','') THEN NULL
         ELSE TRY_CAST(q.higher_estimate AS DECIMAL(10,4)) END,
    CASE WHEN q.denominator IN ('N/A','Not Available','Not Applicable',
         'Too Few to Report','Footnote Applies','--','') THEN NULL
         ELSE TRY_CAST(q.denominator AS INT) END,
    LTRIM(RTRIM(q.compared_to_national))
FROM staging.quality_metrics q
JOIN core.dim_hospital h  ON LTRIM(RTRIM(q.facility_id)) = h.facility_id
LEFT JOIN core.dim_measure m ON LTRIM(RTRIM(q.measure_id)) = m.measure_id
WHERE LTRIM(RTRIM(q.facility_id)) != ''
  AND q.measure_id IS NOT NULL;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- DATA QUALITY REPORT
-- ─────────────────────────────────────────────────────────────────────────────

SELECT 'dim_hospital'             AS table_name, COUNT(*) AS row_count FROM core.dim_hospital
UNION ALL
SELECT 'fact_readmissions',       COUNT(*) FROM core.fact_readmissions
UNION ALL
SELECT 'fact_patient_satisfaction',COUNT(*) FROM core.fact_patient_satisfaction
UNION ALL
SELECT 'fact_quality_metrics',    COUNT(*) FROM core.fact_quality_metrics
ORDER BY table_name;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- NULL AUDIT — hospitals in staging not matched to dim
-- ─────────────────────────────────────────────────────────────────────────────

SELECT 'readmissions with no hospital match' AS issue, COUNT(*) AS cnt
FROM staging.readmissions r
LEFT JOIN core.dim_hospital h ON LTRIM(RTRIM(r.facility_id)) = h.facility_id
WHERE h.hospital_key IS NULL
  AND LTRIM(RTRIM(r.facility_id)) != ''

UNION ALL

SELECT 'readmissions with no measure match', COUNT(*)
FROM core.fact_readmissions
WHERE measure_key IS NULL;
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- END OF SCRIPT 02
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'Script 02 complete — data cleaned and loaded into core schema.' AS status;
GO
