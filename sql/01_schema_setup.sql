-- =============================================================================
-- Healthcare Performance Analytics Dashboard
-- Script 01: Schema Setup & Table Definitions
-- =============================================================================
-- Description: Creates all schemas, staging tables, and core dimension/fact
--              tables for the Healthcare Analytics data warehouse.
-- Database:    Microsoft SQL Server 2019+
-- Run Order:   1 of 6
-- Execute:     sqlcmd -S your_server -d your_db -i sql\01_schema_setup.sql
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- SCHEMAS
-- ─────────────────────────────────────────────────────────────────────────────

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'staging')
    EXEC('CREATE SCHEMA staging');   -- Raw ingest from CMS CSVs
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'core')
    EXEC('CREATE SCHEMA core');      -- Cleaned, conformed dimensions & facts
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'analytics')
    EXEC('CREATE SCHEMA analytics'); -- Aggregated views for reporting
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- STAGING TABLES (raw CMS data — no transformations applied)
-- ─────────────────────────────────────────────────────────────────────────────

-- CMS Hospital General Information
IF OBJECT_ID('staging.cms_hospital', 'U') IS NOT NULL
    DROP TABLE staging.cms_hospital;
GO
CREATE TABLE staging.cms_hospital (
    facility_id             NVARCHAR(10),
    facility_name           NVARCHAR(200),
    address                 NVARCHAR(200),
    city                    NVARCHAR(100),
    state                   NCHAR(2),
    zip_code                NVARCHAR(10),
    county_name             NVARCHAR(100),
    phone_number            NVARCHAR(20),
    hospital_type           NVARCHAR(100),
    hospital_ownership      NVARCHAR(100),
    emergency_services      NVARCHAR(5),
    meets_criteria_ehr      NVARCHAR(5),
    hospital_overall_rating INT,
    mortality_group         NVARCHAR(50),
    safety_group            NVARCHAR(50),
    readmission_group       NVARCHAR(50),
    patient_exp_group       NVARCHAR(50),
    timeliness_group        NVARCHAR(50),
    raw_load_ts             DATETIME2 DEFAULT GETDATE()
);
GO

-- Hospital Readmissions Reduction Program
IF OBJECT_ID('staging.readmissions', 'U') IS NOT NULL
    DROP TABLE staging.readmissions;
GO
CREATE TABLE staging.readmissions (
    facility_id                 NVARCHAR(10),
    facility_name               NVARCHAR(200),
    state                       NCHAR(2),
    measure_name                NVARCHAR(200),
    number_of_discharges        NVARCHAR(20),   -- stored as NVARCHAR; cleaned in script 02
    footnote                    NVARCHAR(200),
    excess_readmission_ratio    NVARCHAR(20),
    predicted_readmission_rate  NVARCHAR(20),
    expected_readmission_rate   NVARCHAR(20),
    number_of_readmissions      NVARCHAR(20),
    start_date                  NVARCHAR(20),
    end_date                    NVARCHAR(20),
    raw_load_ts                 DATETIME2 DEFAULT GETDATE()
);
GO

-- HCAHPS Patient Satisfaction Survey
IF OBJECT_ID('staging.hcahps', 'U') IS NOT NULL
    DROP TABLE staging.hcahps;
GO
CREATE TABLE staging.hcahps (
    facility_id                             NVARCHAR(10),
    facility_name                           NVARCHAR(200),
    address                                 NVARCHAR(200),
    city                                    NVARCHAR(100),
    state                                   NCHAR(2),
    zip_code                                NVARCHAR(10),
    county_name                             NVARCHAR(100),
    phone_number                            NVARCHAR(20),
    hcahps_measure_id                       NVARCHAR(50),
    hcahps_question                         NVARCHAR(300),
    hcahps_answer_description               NVARCHAR(300),
    patient_survey_star_rating              NVARCHAR(10),
    patient_survey_star_rating_footnote     NVARCHAR(200),
    hcahps_answer_percent                   NVARCHAR(10),
    hcahps_answer_percent_footnote          NVARCHAR(200),
    number_of_completed_surveys             NVARCHAR(20),
    number_of_completed_surveys_footnote    NVARCHAR(200),
    survey_response_rate_percent            NVARCHAR(10),
    survey_response_rate_percent_footnote   NVARCHAR(200),
    start_date                              NVARCHAR(20),
    end_date                                NVARCHAR(20),
    raw_load_ts                             DATETIME2 DEFAULT GETDATE()
);
GO

-- CMS Quality Measures (Mortality, Complications, HAI)
IF OBJECT_ID('staging.quality_metrics', 'U') IS NOT NULL
    DROP TABLE staging.quality_metrics;
GO
CREATE TABLE staging.quality_metrics (
    facility_id             NVARCHAR(10),
    facility_name           NVARCHAR(200),
    address                 NVARCHAR(200),
    city                    NVARCHAR(100),
    state                   NCHAR(2),
    zip_code                NVARCHAR(10),
    county_name             NVARCHAR(100),
    phone_number            NVARCHAR(20),
    condition               NVARCHAR(200),
    measure_id              NVARCHAR(50),
    measure_name            NVARCHAR(300),
    compared_to_national    NVARCHAR(100),
    denominator             NVARCHAR(20),
    score                   NVARCHAR(20),
    lower_estimate          NVARCHAR(20),
    higher_estimate         NVARCHAR(20),
    footnote                NVARCHAR(300),
    start_date              NVARCHAR(20),
    end_date                NVARCHAR(20),
    raw_load_ts             DATETIME2 DEFAULT GETDATE()
);
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- CORE DIMENSION TABLES
-- ─────────────────────────────────────────────────────────────────────────────

-- Dimension: Hospital
IF OBJECT_ID('core.dim_hospital', 'U') IS NOT NULL
    DROP TABLE core.dim_hospital;
GO
CREATE TABLE core.dim_hospital (
    hospital_key        INT IDENTITY(1,1) PRIMARY KEY,
    facility_id         NVARCHAR(10)  NOT NULL,
    facility_name       NVARCHAR(200),
    city                NVARCHAR(100),
    state               NCHAR(2),
    zip_code            NVARCHAR(10),
    county_name         NVARCHAR(100),
    hospital_type       NVARCHAR(100),
    hospital_ownership  NVARCHAR(100),
    emergency_services  BIT,
    overall_rating      INT,
    mortality_group     NVARCHAR(50),
    safety_group        NVARCHAR(50),
    readmission_group   NVARCHAR(50),
    patient_exp_group   NVARCHAR(50),
    created_at          DATETIME2 DEFAULT GETDATE(),
    updated_at          DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT uq_dim_hospital_facility_id UNIQUE (facility_id)
);
GO

-- Dimension: Date
IF OBJECT_ID('core.dim_date', 'U') IS NOT NULL
    DROP TABLE core.dim_date;
GO
CREATE TABLE core.dim_date (
    date_key        INT PRIMARY KEY,        -- YYYYMMDD format
    full_date       DATE,
    year            INT,
    quarter         INT,
    month           INT,
    month_name      NVARCHAR(20),
    week_of_year    INT,
    day_of_week     INT,
    day_name        NVARCHAR(20),
    is_weekend      BIT,
    fiscal_year     INT,
    fiscal_quarter  INT
);
GO

-- Dimension: Measure
IF OBJECT_ID('core.dim_measure', 'U') IS NOT NULL
    DROP TABLE core.dim_measure;
GO
CREATE TABLE core.dim_measure (
    measure_key         INT IDENTITY(1,1) PRIMARY KEY,
    measure_id          NVARCHAR(50) NOT NULL,
    measure_name        NVARCHAR(300),
    measure_category    NVARCHAR(100),   -- 'Readmission', 'Mortality', 'Safety', 'Patient Experience'
    higher_is_better    BIT,
    unit_of_measure     NVARCHAR(50),    -- '%', 'Rate', 'Score', 'Days'
    CONSTRAINT uq_dim_measure_id UNIQUE (measure_id)
);
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- CORE FACT TABLES
-- ─────────────────────────────────────────────────────────────────────────────

-- Fact: Readmission Rates
IF OBJECT_ID('core.fact_readmissions', 'U') IS NOT NULL
    DROP TABLE core.fact_readmissions;
GO
CREATE TABLE core.fact_readmissions (
    readmission_key             INT IDENTITY(1,1) PRIMARY KEY,
    hospital_key                INT REFERENCES core.dim_hospital(hospital_key),
    measure_key                 INT REFERENCES core.dim_measure(measure_key),
    start_date_key              INT REFERENCES core.dim_date(date_key),
    end_date_key                INT REFERENCES core.dim_date(date_key),
    number_of_discharges        INT,
    number_of_readmissions      INT,
    predicted_readmission_rate  DECIMAL(8,4),
    expected_readmission_rate   DECIMAL(8,4),
    excess_readmission_ratio    DECIMAL(8,4),
    readmission_rate_pct        DECIMAL(8,4),   -- derived: readmissions / discharges * 100
    created_at                  DATETIME2 DEFAULT GETDATE()
);
GO

-- Fact: Patient Satisfaction (HCAHPS)
IF OBJECT_ID('core.fact_patient_satisfaction', 'U') IS NOT NULL
    DROP TABLE core.fact_patient_satisfaction;
GO
CREATE TABLE core.fact_patient_satisfaction (
    satisfaction_key    INT IDENTITY(1,1) PRIMARY KEY,
    hospital_key        INT REFERENCES core.dim_hospital(hospital_key),
    measure_key         INT REFERENCES core.dim_measure(measure_key),
    start_date_key      INT REFERENCES core.dim_date(date_key),
    end_date_key        INT REFERENCES core.dim_date(date_key),
    star_rating         DECIMAL(3,1),
    answer_percent      DECIMAL(5,2),
    completed_surveys   INT,
    response_rate_pct   DECIMAL(5,2),
    created_at          DATETIME2 DEFAULT GETDATE()
);
GO

-- Fact: Quality Metrics (Mortality, Complications, Infections)
IF OBJECT_ID('core.fact_quality_metrics', 'U') IS NOT NULL
    DROP TABLE core.fact_quality_metrics;
GO
CREATE TABLE core.fact_quality_metrics (
    quality_key         INT IDENTITY(1,1) PRIMARY KEY,
    hospital_key        INT REFERENCES core.dim_hospital(hospital_key),
    measure_key         INT REFERENCES core.dim_measure(measure_key),
    start_date_key      INT REFERENCES core.dim_date(date_key),
    end_date_key        INT REFERENCES core.dim_date(date_key),
    condition           NVARCHAR(200),
    score               DECIMAL(10,4),
    lower_estimate      DECIMAL(10,4),
    higher_estimate     DECIMAL(10,4),
    denominator         INT,
    compared_to_national NVARCHAR(100),
    created_at          DATETIME2 DEFAULT GETDATE()
);
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- INDEXES FOR QUERY PERFORMANCE
-- ─────────────────────────────────────────────────────────────────────────────

CREATE INDEX idx_fact_readmissions_hospital ON core.fact_readmissions(hospital_key);
CREATE INDEX idx_fact_readmissions_measure  ON core.fact_readmissions(measure_key);
CREATE INDEX idx_fact_readmissions_dates    ON core.fact_readmissions(start_date_key, end_date_key);
GO

CREATE INDEX idx_fact_satisfaction_hospital ON core.fact_patient_satisfaction(hospital_key);
CREATE INDEX idx_fact_satisfaction_measure  ON core.fact_patient_satisfaction(measure_key);
GO

CREATE INDEX idx_fact_quality_hospital  ON core.fact_quality_metrics(hospital_key);
CREATE INDEX idx_fact_quality_measure   ON core.fact_quality_metrics(measure_key);
CREATE INDEX idx_fact_quality_condition ON core.fact_quality_metrics(condition);
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- POPULATE DATE DIMENSION (2019–2026)
-- ─────────────────────────────────────────────────────────────────────────────

DECLARE @start_date DATE = '2019-01-01';
DECLARE @end_date   DATE = '2026-12-31';
DECLARE @date       DATE = @start_date;

WHILE @date <= @end_date
BEGIN
    IF NOT EXISTS (SELECT 1 FROM core.dim_date WHERE date_key = CAST(FORMAT(@date, 'yyyyMMdd') AS INT))
    BEGIN
        INSERT INTO core.dim_date (
            date_key, full_date, year, quarter, month, month_name,
            week_of_year, day_of_week, day_name, is_weekend,
            fiscal_year, fiscal_quarter
        )
        VALUES (
            CAST(FORMAT(@date, 'yyyyMMdd') AS INT),
            @date,
            YEAR(@date),
            DATEPART(QUARTER, @date),
            MONTH(@date),
            DATENAME(MONTH, @date),
            DATEPART(WEEK, @date),
            DATEPART(WEEKDAY, @date),
            DATENAME(WEEKDAY, @date),
            CASE WHEN DATEPART(WEEKDAY, @date) IN (1, 7) THEN 1 ELSE 0 END,
            -- Fiscal year: Oct–Sep
            CASE WHEN MONTH(@date) >= 10 THEN YEAR(@date) + 1 ELSE YEAR(@date) END,
            -- Fiscal quarter
            CASE
                WHEN MONTH(@date) BETWEEN 10 AND 12 THEN 1
                WHEN MONTH(@date) BETWEEN 1  AND 3  THEN 2
                WHEN MONTH(@date) BETWEEN 4  AND 6  THEN 3
                ELSE 4
            END
        );
    END
    SET @date = DATEADD(DAY, 1, @date);
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- SEED MEASURE DIMENSION
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO core.dim_measure (measure_id, measure_name, measure_category, higher_is_better, unit_of_measure)
SELECT v.measure_id, v.measure_name, v.measure_category, v.higher_is_better, v.unit_of_measure
FROM (VALUES
    -- Readmission Measures
    ('READM-30-HF-HRRP',   '30-Day Readmission Rate - Heart Failure',           'Readmission', 0, '%'),
    ('READM-30-AMI-HRRP',  '30-Day Readmission Rate - Acute MI',                'Readmission', 0, '%'),
    ('READM-30-PN-HRRP',   '30-Day Readmission Rate - Pneumonia',               'Readmission', 0, '%'),
    ('READM-30-HIP-KNEE',  '30-Day Readmission Rate - Hip/Knee Replacement',    'Readmission', 0, '%'),
    ('READM-30-CABG',      '30-Day Readmission Rate - CABG Surgery',            'Readmission', 0, '%'),
    ('READM-30-COPD-HRRP', '30-Day Readmission Rate - COPD',                   'Readmission', 0, '%'),
    -- Mortality Measures
    ('MORT-30-HF',  '30-Day Mortality Rate - Heart Failure', 'Mortality', 0, 'Rate'),
    ('MORT-30-AMI', '30-Day Mortality Rate - Acute MI',      'Mortality', 0, 'Rate'),
    ('MORT-30-PN',  '30-Day Mortality Rate - Pneumonia',     'Mortality', 0, 'Rate'),
    ('MORT-30-CABG','30-Day Mortality Rate - CABG',          'Mortality', 0, 'Rate'),
    ('MORT-30-COPD','30-Day Mortality Rate - COPD',          'Mortality', 0, 'Rate'),
    -- Safety / HAI Measures
    ('HAI-1', 'Central Line-Associated Bloodstream Infection',     'Safety', 0, 'Rate'),
    ('HAI-2', 'Catheter-Associated Urinary Tract Infection',       'Safety', 0, 'Rate'),
    ('HAI-3', 'Surgical Site Infection - Colon Surgery',          'Safety', 0, 'Rate'),
    ('HAI-4', 'Surgical Site Infection - Abdominal Hysterectomy', 'Safety', 0, 'Rate'),
    ('HAI-5', 'MRSA Bacteremia',                                   'Safety', 0, 'Rate'),
    ('HAI-6', 'Clostridioides difficile Infection',                'Safety', 0, 'Rate'),
    -- Patient Experience Measures
    ('H-COMP-1-A-P',    'Communication with Nurses - Always',                'Patient Experience', 1, '%'),
    ('H-COMP-2-A-P',    'Communication with Doctors - Always',               'Patient Experience', 1, '%'),
    ('H-COMP-3-A-P',    'Responsiveness of Hospital Staff - Always',         'Patient Experience', 1, '%'),
    ('H-COMP-5-A-P',    'Communication about Medicines - Always',            'Patient Experience', 1, '%'),
    ('H-CLEAN-HSP-A-P', 'Cleanliness of Hospital Environment - Always',      'Patient Experience', 1, '%'),
    ('H-QUIET-HSP-A-P', 'Quietness of Hospital Environment - Always',        'Patient Experience', 1, '%'),
    ('H-HSP-RATING-9-10','Overall Hospital Rating 9-10',                     'Patient Experience', 1, '%'),
    ('H-RECMND-DY',     'Would Recommend Hospital - Definitely Yes',         'Patient Experience', 1, '%')
) AS v(measure_id, measure_name, measure_category, higher_is_better, unit_of_measure)
WHERE NOT EXISTS (
    SELECT 1 FROM core.dim_measure dm WHERE dm.measure_id = v.measure_id
);
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- LOAD CSV DATA USING BULK INSERT
-- Update file paths to match your local environment before running
-- ─────────────────────────────────────────────────────────────────────────────

/*
BULK INSERT staging.cms_hospital
FROM 'C:\your_path\data\sample_cms_hospital.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n', TABLOCK);

BULK INSERT staging.readmissions
FROM 'C:\your_path\data\sample_readmissions.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n', TABLOCK);

BULK INSERT staging.quality_metrics
FROM 'C:\your_path\data\sample_quality_metrics.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n', TABLOCK);
*/

-- ─────────────────────────────────────────────────────────────────────────────
-- END OF SCRIPT 01
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'Script 01 complete — schema and tables created.' AS status;
GO
