-- ClickHouse Actuarial Demo - Claims Table
-- Optimized for loss triangle analysis and development factor calculations

USE actuarial;

CREATE TABLE IF NOT EXISTS claims (
    claim_id UInt64,
    claim_number String,
    policy_id UInt64,
    accident_date Date,
    report_date Date,
    accident_year UInt16,
    development_month UInt16,
    line_of_business LowCardinality(String),
    geography LowCardinality(String),
    claim_cause LowCardinality(String),
    claim_status LowCardinality(String),
    initial_reserve Decimal64(2),
    paid_amount Decimal64(2),
    outstanding_reserve Decimal64(2),
    incurred_amount Decimal64(2),
    claim_attributes String  -- JSON string for flexible claim attributes
) ENGINE = MergeTree()
PARTITION BY (accident_year, toYYYYMM(accident_date))
ORDER BY (line_of_business, geography, accident_year, development_month, claim_id)
SETTINGS index_granularity = 8192;

-- Projection for loss triangle analysis
ALTER TABLE claims ADD PROJECTION loss_triangle_analysis (
    SELECT 
        accident_year,
        development_month,
        line_of_business,
        geography,
        sum(paid_amount) as cumulative_paid,
        sum(incurred_amount) as cumulative_incurred,
        sum(outstanding_reserve) as total_outstanding,
        count() as claim_count
    GROUP BY accident_year, development_month, line_of_business, geography
);

-- Materialized view for real-time triangle data
CREATE MATERIALIZED VIEW IF NOT EXISTS loss_triangle_mv
ENGINE = SummingMergeTree()
PARTITION BY accident_year
ORDER BY (accident_year, development_month, line_of_business, geography)
AS SELECT 
    accident_year,
    development_month,
    line_of_business,
    geography,
    sum(paid_amount) as total_paid,
    sum(incurred_amount) as total_incurred,
    sum(outstanding_reserve) as total_outstanding,
    count() as claim_count
FROM claims
GROUP BY accident_year, development_month, line_of_business, geography;

-- Materialized view for monthly claim summaries
CREATE MATERIALIZED VIEW IF NOT EXISTS monthly_claims_mv
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(accident_date)
ORDER BY (toYYYYMM(accident_date), line_of_business, geography)
AS SELECT 
    toYYYYMM(accident_date) as accident_month,
    line_of_business,
    geography,
    claim_status,
    count() as claim_count,
    sum(incurred_amount) as total_incurred,
    sum(paid_amount) as total_paid,
    avg(datediff('day', accident_date, report_date)) as avg_report_delay
FROM claims
GROUP BY accident_month, line_of_business, geography, claim_status;

SHOW TABLES;