-- =============================================================================
-- Healthcare Performance Analytics Dashboard
-- Script 01: Schema Setup & Table Definitions
-- =============================================================================
-- Description: Creates all schemas, staging tables, and core dimension/fact
--              tables for the Healthcare Analytics data warehouse.
-- Run Order:   1 of 6
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- SCHEMAS
-- ─────────────────────────────────────────────────────────────────────────────

CREATE SCHEMA IF NOT EXISTS staging;   -- Raw ingest from CMS CSVs
CREATE SCHEMA IF NOT EXISTS core;      -- Cleaned, conformed dimensions & facts
CREATE SCHEMA IF NOT EXISTS analytics; -- Aggregated views for reporting

-- ─────────────────────────────────────────────────────────────────────────────
-- STAGING TABLES (raw CMS data — no transformations applied)
-- ─────────────────────────────────────────────────────────────────────────────

-- CMS Hospital General Information
DROP TABLE IF EXISTS staging.cms_hospital;
CREATE TABLE staging.cms_hospital (
    facility_id             VARCHAR(10),
    facility_name           VARCHAR(200),
    address                 VARCHAR(200),
    city                    VARCHAR(100),
    state                   CHAR(2),
    zip_code                VARCHAR(10),
    county_name             VARCHAR(100),
    phone_number            VARCHAR(20),
    hospital_type           VARCHAR(100),
    hospital_ownership      VARCHAR(100),
    emergency_services      VARCHAR(5),
    meets_criteria_ehr      VARCHAR(5),
    hospital_overall_rating INT,
    mortality_group         VARCHAR(50),
    safety_group            VARCHAR(50),
    readmission_group       VARCHAR(50),
    patient_exp_group       VARCHAR(50),
    timeliness_group        VARCHAR(50),
    raw_load_ts             TIMESTAMP DEFAULT NOW()
);

-- Hospital Readmissions Reduction Program
DROP TABLE IF EXISTS staging.readmissions;
CREATE TABLE staging.readmissions (
    facility_id             VARCHAR(10),
    facility_name           VARCHAR(200),
    state                   CHAR(2),
    measure_name            VARCHAR(200),
    number_of_discharges    VARCHAR(20),    -- stored as VARCHAR; cleaned in script 02
    footnote                VARCHAR(200),
    excess_readmission_ratio VARCHAR(20),
    predicted_readmission_rate VARCHAR(20),
    expected_readmission_rate VARCHAR(20),
    number_of_readmissions  VARCHAR(20),
    start_date              VARCHAR(20),
    end_date                VARCHAR(20),
    raw_load_ts             TIMESTAMP DEFAULT NOW()
);

-- HCAHPS Patient Satisfaction Survey
DROP TABLE IF EXISTS staging.hcahps;
CREATE TABLE staging.hcahps (
    facility_id             VARCHAR(10),
    facility_name           VARCHAR(200),
    address                 VARCHAR(200),
    city                    VARCHAR(100),
    state                   CHAR(2),
    zip_code                VARCHAR(10),
    county_name             VARCHAR(100),
    phone_number            VARCHAR(20),
    hcahps_measure_id       VARCHAR(50),
    hcahps_question         VARCHAR(300),
    hcahps_answer_description VARCHAR(300),
    patient_survey_star_rating VARCHAR(10),
    patient_survey_star_rating_footnote VARCHAR(200),
    hcahps_answer_percent   VARCHAR(10),
    hcahps_answer_percent_footnote VARCHAR(200),
    number_of_completed_surveys VARCHAR(20),
    number_of_completed_surveys_footnote VARCHAR(200),
    survey_response_rate_percent VARCHAR(10),
    survey_response_rate_percent_footnote VARCHAR(200),
    start_date              VARCHAR(20),
    end_date                VARCHAR(20),
    raw_load_ts             TIMESTAMP DEFAULT NOW()
);

-- CMS Quality Measures (Mortality, Complications, HAI)
DROP TABLE IF EXISTS staging.quality_metrics;
CREATE TABLE staging.quality_metrics (
    facility_id             VARCHAR(10),
    facility_name           VARCHAR(200),
    address                 VARCHAR(200),
    city                    VARCHAR(100),
    state                   CHAR(2),
    zip_code                VARCHAR(10),
    county_name             VARCHAR(100),
    phone_number            VARCHAR(20),
    condition               VARCHAR(200),
    measure_id              VARCHAR(50),
    measure_name            VARCHAR(300),
    compared_to_national    VARCHAR(100),
    denominator             VARCHAR(20),
    score                   VARCHAR(20),
    lower_estimate          VARCHAR(20),
    higher_estimate         VARCHAR(20),
    footnote                VARCHAR(300),
    start_date              VARCHAR(20),
    end_date                VARCHAR(20),
    raw_load_ts             TIMESTAMP DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- CORE DIMENSION TABLES
-- ─────────────────────────────────────────────────────────────────────────────

-- Dimension: Hospital
DROP TABLE IF EXISTS core.dim_hospital;
CREATE TABLE core.dim_hospital (
    hospital_key            SERIAL PRIMARY KEY,
    facility_id             VARCHAR(10)  NOT NULL UNIQUE,
    facility_name           VARCHAR(200),
    city                    VARCHAR(100),
    state                   CHAR(2),
    zip_code                VARCHAR(10),
    county_name             VARCHAR(100),
    hospital_type           VARCHAR(100),
    hospital_ownership      VARCHAR(100),
    emergency_services      BOOLEAN,
    overall_rating          INT,
    mortality_group         VARCHAR(50),
    safety_group            VARCHAR(50),
    readmission_group       VARCHAR(50),
    patient_exp_group       VARCHAR(50),
    created_at              TIMESTAMP DEFAULT NOW(),
    updated_at              TIMESTAMP DEFAULT NOW()
);

-- Dimension: Date
DROP TABLE IF EXISTS core.dim_date;
CREATE TABLE core.dim_date (
    date_key                INT PRIMARY KEY,   -- YYYYMMDD format
    full_date               DATE,
    year                    INT,
    quarter                 INT,
    month                   INT,
    month_name              VARCHAR(20),
    week_of_year            INT,
    day_of_week             INT,
    day_name                VARCHAR(20),
    is_weekend              BOOLEAN,
    fiscal_year             INT,
    fiscal_quarter          INT
);

-- Dimension: Measure
DROP TABLE IF EXISTS core.dim_measure;
CREATE TABLE core.dim_measure (
    measure_key             SERIAL PRIMARY KEY,
    measure_id              VARCHAR(50) NOT NULL UNIQUE,
    measure_name            VARCHAR(300),
    measure_category        VARCHAR(100),   -- 'Readmission', 'Mortality', 'Safety', 'Patient Experience'
    higher_is_better        BOOLEAN,
    unit_of_measure         VARCHAR(50)     -- '%', 'Rate', 'Score', 'Days'
);

-- ─────────────────────────────────────────────────────────────────────────────
-- CORE FACT TABLES
-- ─────────────────────────────────────────────────────────────────────────────

-- Fact: Readmission Rates
DROP TABLE IF EXISTS core.fact_readmissions;
CREATE TABLE core.fact_readmissions (
    readmission_key         SERIAL PRIMARY KEY,
    hospital_key            INT REFERENCES core.dim_hospital(hospital_key),
    measure_key             INT REFERENCES core.dim_measure(measure_key),
    start_date_key          INT REFERENCES core.dim_date(date_key),
    end_date_key            INT REFERENCES core.dim_date(date_key),
    number_of_discharges    INT,
    number_of_readmissions  INT,
    predicted_readmission_rate NUMERIC(8,4),
    expected_readmission_rate NUMERIC(8,4),
    excess_readmission_ratio  NUMERIC(8,4),
    readmission_rate_pct    NUMERIC(8,4),    -- derived: readmissions / discharges * 100
    created_at              TIMESTAMP DEFAULT NOW()
);

-- Fact: Patient Satisfaction (HCAHPS)
DROP TABLE IF EXISTS core.fact_patient_satisfaction;
CREATE TABLE core.fact_patient_satisfaction (
    satisfaction_key        SERIAL PRIMARY KEY,
    hospital_key            INT REFERENCES core.dim_hospital(hospital_key),
    measure_key             INT REFERENCES core.dim_measure(measure_key),
    start_date_key          INT REFERENCES core.dim_date(date_key),
    end_date_key            INT REFERENCES core.dim_date(date_key),
    star_rating             NUMERIC(3,1),
    answer_percent          NUMERIC(5,2),
    completed_surveys       INT,
    response_rate_pct       NUMERIC(5,2),
    created_at              TIMESTAMP DEFAULT NOW()
);

-- Fact: Quality Metrics (Mortality, Complications, Infections)
DROP TABLE IF EXISTS core.fact_quality_metrics;
CREATE TABLE core.fact_quality_metrics (
    quality_key             SERIAL PRIMARY KEY,
    hospital_key            INT REFERENCES core.dim_hospital(hospital_key),
    measure_key             INT REFERENCES core.dim_measure(measure_key),
    start_date_key          INT REFERENCES core.dim_date(date_key),
    end_date_key            INT REFERENCES core.dim_date(date_key),
    condition               VARCHAR(200),
    score                   NUMERIC(10,4),
    lower_estimate          NUMERIC(10,4),
    higher_estimate         NUMERIC(10,4),
    denominator             INT,
    compared_to_national    VARCHAR(100),
    created_at              TIMESTAMP DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- INDEXES FOR QUERY PERFORMANCE
-- ─────────────────────────────────────────────────────────────────────────────

CREATE INDEX idx_fact_readmissions_hospital ON core.fact_readmissions(hospital_key);
CREATE INDEX idx_fact_readmissions_measure  ON core.fact_readmissions(measure_key);
CREATE INDEX idx_fact_readmissions_dates    ON core.fact_readmissions(start_date_key, end_date_key);

CREATE INDEX idx_fact_satisfaction_hospital ON core.fact_patient_satisfaction(hospital_key);
CREATE INDEX idx_fact_satisfaction_measure  ON core.fact_patient_satisfaction(measure_key);

CREATE INDEX idx_fact_quality_hospital      ON core.fact_quality_metrics(hospital_key);
CREATE INDEX idx_fact_quality_measure       ON core.fact_quality_metrics(measure_key);
CREATE INDEX idx_fact_quality_condition     ON core.fact_quality_metrics(condition);

-- ─────────────────────────────────────────────────────────────────────────────
-- POPULATE DATE DIMENSION (2019–2026)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO core.dim_date
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT           AS date_key,
    d                                      AS full_date,
    EXTRACT(YEAR FROM d)::INT              AS year,
    EXTRACT(QUARTER FROM d)::INT           AS quarter,
    EXTRACT(MONTH FROM d)::INT             AS month,
    TO_CHAR(d, 'Month')                    AS month_name,
    EXTRACT(WEEK FROM d)::INT              AS week_of_year,
    EXTRACT(DOW FROM d)::INT               AS day_of_week,
    TO_CHAR(d, 'Day')                      AS day_name,
    EXTRACT(DOW FROM d) IN (0,6)           AS is_weekend,
    CASE WHEN EXTRACT(MONTH FROM d) >= 10
         THEN EXTRACT(YEAR FROM d)::INT + 1
         ELSE EXTRACT(YEAR FROM d)::INT
    END                                    AS fiscal_year,
    CASE
        WHEN EXTRACT(MONTH FROM d) BETWEEN 10 AND 12 THEN 1
        WHEN EXTRACT(MONTH FROM d) BETWEEN 1  AND 3  THEN 2
        WHEN EXTRACT(MONTH FROM d) BETWEEN 4  AND 6  THEN 3
        ELSE 4
    END                                    AS fiscal_quarter
FROM GENERATE_SERIES('2019-01-01'::DATE, '2026-12-31'::DATE, '1 day') AS d
ON CONFLICT (date_key) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- SEED MEASURE DIMENSION
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO core.dim_measure (measure_id, measure_name, measure_category, higher_is_better, unit_of_measure)
VALUES
    -- Readmission Measures
    ('READM-30-HF-HRRP',    '30-Day Readmission Rate - Heart Failure',           'Readmission', FALSE, '%'),
    ('READM-30-AMI-HRRP',   '30-Day Readmission Rate - Acute MI',                'Readmission', FALSE, '%'),
    ('READM-30-PN-HRRP',    '30-Day Readmission Rate - Pneumonia',               'Readmission', FALSE, '%'),
    ('READM-30-HIP-KNEE',   '30-Day Readmission Rate - Hip/Knee Replacement',    'Readmission', FALSE, '%'),
    ('READM-30-CABG',       '30-Day Readmission Rate - CABG Surgery',            'Readmission', FALSE, '%'),
    ('READM-30-COPD-HRRP',  '30-Day Readmission Rate - COPD',                   'Readmission', FALSE, '%'),
    -- Mortality Measures
    ('MORT-30-HF',          '30-Day Mortality Rate - Heart Failure',             'Mortality',   FALSE, 'Rate'),
    ('MORT-30-AMI',         '30-Day Mortality Rate - Acute MI',                  'Mortality',   FALSE, 'Rate'),
    ('MORT-30-PN',          '30-Day Mortality Rate - Pneumonia',                 'Mortality',   FALSE, 'Rate'),
    ('MORT-30-CABG',        '30-Day Mortality Rate - CABG',                      'Mortality',   FALSE, 'Rate'),
    ('MORT-30-COPD',        '30-Day Mortality Rate - COPD',                      'Mortality',   FALSE, 'Rate'),
    -- Safety / HAI Measures
    ('HAI-1',               'Central Line-Associated Bloodstream Infection',      'Safety',      FALSE, 'Rate'),
    ('HAI-2',               'Catheter-Associated Urinary Tract Infection',        'Safety',      FALSE, 'Rate'),
    ('HAI-3',               'Surgical Site Infection - Colon Surgery',           'Safety',      FALSE, 'Rate'),
    ('HAI-4',               'Surgical Site Infection - Abdominal Hysterectomy',  'Safety',      FALSE, 'Rate'),
    ('HAI-5',               'MRSA Bacteremia',                                   'Safety',      FALSE, 'Rate'),
    ('HAI-6',               'Clostridioides difficile Infection',                'Safety',      FALSE, 'Rate'),
    -- Patient Experience Measures
    ('H-COMP-1-A-P',        'Communication with Nurses - Always',                'Patient Experience', TRUE, '%'),
    ('H-COMP-2-A-P',        'Communication with Doctors - Always',               'Patient Experience', TRUE, '%'),
    ('H-COMP-3-A-P',        'Responsiveness of Hospital Staff - Always',         'Patient Experience', TRUE, '%'),
    ('H-COMP-5-A-P',        'Communication about Medicines - Always',            'Patient Experience', TRUE, '%'),
    ('H-CLEAN-HSP-A-P',     'Cleanliness of Hospital Environment - Always',      'Patient Experience', TRUE, '%'),
    ('H-QUIET-HSP-A-P',     'Quietness of Hospital Environment - Always',        'Patient Experience', TRUE, '%'),
    ('H-HSP-RATING-9-10',   'Overall Hospital Rating 9-10',                      'Patient Experience', TRUE, '%'),
    ('H-RECMND-DY',         'Would Recommend Hospital - Definitely Yes',         'Patient Experience', TRUE, '%')
ON CONFLICT (measure_id) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- COMMENTS
-- ─────────────────────────────────────────────────────────────────────────────

COMMENT ON SCHEMA staging IS 'Raw data loaded directly from CMS CSV exports — no transformations.';
COMMENT ON SCHEMA core    IS 'Cleaned, conformed dimensional model for analytics.';
COMMENT ON SCHEMA analytics IS 'Pre-aggregated views and materialized tables for Power BI and Excel.';

COMMENT ON TABLE core.dim_hospital            IS 'Hospital dimension — one row per CMS facility ID.';
COMMENT ON TABLE core.dim_date                IS 'Date dimension — one row per calendar day 2019–2026.';
COMMENT ON TABLE core.dim_measure             IS 'Measure dimension — one row per CMS quality/performance measure.';
COMMENT ON TABLE core.fact_readmissions       IS 'Readmission rates from the Hospital Readmissions Reduction Program.';
COMMENT ON TABLE core.fact_patient_satisfaction IS 'HCAHPS patient satisfaction survey results by hospital and measure.';
COMMENT ON TABLE core.fact_quality_metrics    IS 'CMS quality measures including mortality, complications, and HAIs.';

-- ─────────────────────────────────────────────────────────────────────────────
-- END OF SCRIPT 01
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'Script 01 complete — schema and tables created.' AS status;
