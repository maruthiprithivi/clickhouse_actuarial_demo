-- ClickHouse Actuarial Demo - Load Policies Data
-- Loads policy data from generated files (CSV or Parquet)

USE actuarial;

-- Load from Parquet (default format)
INSERT INTO policies
SELECT 
    policy_id,
    policy_number,
    effective_date,
    expiry_date,
    line_of_business,
    sum_insured,
    premium,
    geography,
    customer_age,
    customer_gender,
    risk_factors
FROM file('/data/policies.parquet', 'Parquet')
SETTINGS input_format_parquet_import_nested = 1;

-- Alternative: Load from CSV
-- INSERT INTO policies
-- SELECT 
--     policy_id,
--     policy_number,
--     toDate(effective_date) as effective_date,
--     toDate(expiry_date) as expiry_date,
--     line_of_business,
--     toDecimal64(sum_insured, 2) as sum_insured,
--     toDecimal64(premium, 2) as premium,
--     geography,
--     toUInt8(customer_age) as customer_age,
--     customer_gender,
--     risk_factors
-- FROM file('/data/policies.csv', 'CSVWithNames')
-- SETTINGS input_format_csv_detect_header = 1;

-- Verify load
SELECT 
    'Policies loaded' as status,
    count() as record_count,
    min(effective_date) as earliest_policy,
    max(effective_date) as latest_policy,
    uniq(line_of_business) as lob_count,
    uniq(geography) as geography_count
FROM policies;