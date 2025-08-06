-- ClickHouse Actuarial Demo - Policies Table
-- Optimized table structure for actuarial policy analysis

USE actuarial;

CREATE TABLE IF NOT EXISTS policies (
    policy_id UInt64,
    policy_number String,
    effective_date Date,
    expiry_date Date,
    line_of_business LowCardinality(String),
    sum_insured Decimal64(2),
    premium Decimal64(2),
    geography LowCardinality(String),
    customer_age UInt8,
    customer_gender LowCardinality(String),
    risk_factors String  -- JSON string for flexible risk attributes
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(effective_date)
ORDER BY (line_of_business, geography, policy_id)
SETTINGS index_granularity = 8192;

-- Create a projection for geography-based analysis
ALTER TABLE policies ADD PROJECTION geography_analysis (
    SELECT 
        geography,
        line_of_business,
        toYear(effective_date) as policy_year,
        count() as policy_count,
        sum(sum_insured) as total_exposure,
        sum(premium) as total_premium
    GROUP BY geography, line_of_business, policy_year
);

-- Materialized view for real-time policy summaries
CREATE MATERIALIZED VIEW IF NOT EXISTS policy_summary_mv
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(effective_date)
ORDER BY (line_of_business, geography, effective_date)
AS SELECT 
    line_of_business,
    geography,
    effective_date,
    count() as policy_count,
    sum(sum_insured) as total_sum_insured,
    sum(premium) as total_premium,
    avg(customer_age) as avg_customer_age
FROM policies
GROUP BY line_of_business, geography, effective_date;

SHOW TABLES;