-- ClickHouse Actuarial Demo - Load Claims Data
-- Loads claims data optimized for loss triangle analysis

USE actuarial;

-- Load from Parquet (default format)
INSERT INTO claims
SELECT 
    claim_id,
    claim_number,
    policy_id,
    accident_date,
    report_date,
    accident_year,
    development_month,
    line_of_business,
    geography,
    claim_cause,
    claim_status,
    initial_reserve,
    paid_amount,
    outstanding_reserve,
    incurred_amount,
    claim_attributes
FROM file('/data/claims.parquet', 'Parquet')
SETTINGS input_format_parquet_import_nested = 1;

-- Alternative: Load from CSV
-- INSERT INTO claims
-- SELECT 
--     claim_id,
--     claim_number,
--     policy_id,
--     toDate(accident_date) as accident_date,
--     toDate(report_date) as report_date,
--     toUInt16(accident_year) as accident_year,
--     toUInt16(development_month) as development_month,
--     line_of_business,
--     geography,
--     claim_cause,
--     claim_status,
--     toDecimal64(initial_reserve, 2) as initial_reserve,
--     toDecimal64(paid_amount, 2) as paid_amount,
--     toDecimal64(outstanding_reserve, 2) as outstanding_reserve,
--     toDecimal64(incurred_amount, 2) as incurred_amount,
--     claim_attributes
-- FROM file('/data/claims.csv', 'CSVWithNames')
-- SETTINGS input_format_csv_detect_header = 1;

-- Verify load and show triangle structure
SELECT 
    'Claims loaded' as status,
    count() as total_claims,
    min(accident_date) as earliest_accident,
    max(accident_date) as latest_accident,
    uniq(accident_year) as accident_years,
    max(development_month) as max_development_month
FROM claims;

-- Show loss triangle preview
SELECT 
    accident_year,
    development_month,
    sum(paid_amount) as total_paid,
    sum(incurred_amount) as total_incurred,
    count() as claim_count
FROM claims
WHERE accident_year >= year(now()) - 3
GROUP BY accident_year, development_month
ORDER BY accident_year, development_month
LIMIT 20;