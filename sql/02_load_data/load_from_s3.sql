-- ClickHouse Actuarial Demo - S3 Data Loading
-- Demonstrates cloud data loading using S3 table functions
-- Replace bucket and credentials with your actual values

USE actuarial;

-- Set S3 configuration (adjust as needed)
-- For production, use proper IAM roles or environment variables
SET s3_max_single_read_retries = 5;

-- Load policies from S3 Parquet
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
FROM s3(
    'https://your-actuarial-bucket.s3.amazonaws.com/policies/*.parquet',
    'YOUR_ACCESS_KEY',
    'YOUR_SECRET_KEY',
    'Parquet'
)
SETTINGS input_format_parquet_import_nested = 1;

-- Load claims from S3 Parquet
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
FROM s3(
    'https://your-actuarial-bucket.s3.amazonaws.com/claims/*.parquet',
    'YOUR_ACCESS_KEY',
    'YOUR_SECRET_KEY',
    'Parquet'
)
SETTINGS input_format_parquet_import_nested = 1;

-- Load reserves from S3 Parquet
INSERT INTO reserves
SELECT 
    contract_group_id,
    line_of_business,
    geography,
    cohort_year,
    valuation_date,
    policy_count,
    claim_count,
    total_incurred,
    total_paid,
    total_outstanding,
    pv_factor,
    pv_claims,
    pv_premiums,
    risk_adjustment,
    acquisition_costs,
    initial_csm,
    loss_component,
    profitability_class,
    coverage_units_total,
    coverage_units_current,
    csm_amortization,
    best_estimate_liability,
    liability_remaining_coverage,
    reserve_adequacy_ratio,
    reserve_metadata
FROM s3(
    'https://your-actuarial-bucket.s3.amazonaws.com/reserves/*.parquet',
    'YOUR_ACCESS_KEY',
    'YOUR_SECRET_KEY',
    'Parquet'
)
SETTINGS input_format_parquet_import_nested = 1;

-- Alternative: Using s3Cluster for distributed loading (if you have a cluster)
-- INSERT INTO policies
-- SELECT * FROM s3Cluster(
--     'default',
--     'https://your-actuarial-bucket.s3.amazonaws.com/policies/*.parquet',
--     'YOUR_ACCESS_KEY',
--     'YOUR_SECRET_KEY',
--     'Parquet'
-- );

-- Verify S3 load
SELECT 
    'S3 Load Complete' as status,
    (SELECT count() FROM policies) as policies_loaded,
    (SELECT count() FROM claims) as claims_loaded,
    (SELECT count() FROM reserves) as reserves_loaded;