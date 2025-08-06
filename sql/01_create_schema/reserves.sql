-- ClickHouse Actuarial Demo - Reserves Table
-- IFRS 17 compliant structure for CSM calculations and reserve analysis

USE actuarial;

CREATE TABLE IF NOT EXISTS reserves (
    contract_group_id String,
    line_of_business LowCardinality(String),
    geography LowCardinality(String), 
    cohort_year UInt16,
    valuation_date Date,
    policy_count UInt32,
    claim_count UInt32,
    total_incurred Decimal64(2),
    total_paid Decimal64(2),
    total_outstanding Decimal64(2),
    pv_factor Decimal64(6),
    pv_claims Decimal64(2),
    pv_premiums Decimal64(2),
    risk_adjustment Decimal64(2),
    acquisition_costs Decimal64(2),
    initial_csm Decimal64(2),
    loss_component Decimal64(2),
    profitability_class LowCardinality(String),
    coverage_units_total UInt64,
    coverage_units_current UInt64,
    csm_amortization Decimal64(2),
    best_estimate_liability Decimal64(2),
    liability_remaining_coverage Decimal64(2),
    reserve_adequacy_ratio Decimal64(4),
    reserve_metadata String  -- JSON string for actuarial assumptions
) ENGINE = MergeTree()
PARTITION BY (cohort_year, toYYYYMM(valuation_date))
ORDER BY (line_of_business, geography, cohort_year, valuation_date)
SETTINGS index_granularity = 8192;

-- Projection for IFRS 17 reporting
ALTER TABLE reserves ADD PROJECTION ifrs17_reporting (
    SELECT 
        line_of_business,
        profitability_class,
        toYear(valuation_date) as reporting_year,
        sum(initial_csm) as total_csm,
        sum(loss_component) as total_loss_component,
        sum(liability_remaining_coverage) as total_lrc,
        sum(best_estimate_liability) as total_bel,
        sum(risk_adjustment) as total_risk_adjustment
    GROUP BY line_of_business, profitability_class, reporting_year
);

-- Materialized view for CSM movements
CREATE MATERIALIZED VIEW IF NOT EXISTS csm_movements_mv
ENGINE = SummingMergeTree()
PARTITION BY toYear(valuation_date)
ORDER BY (valuation_date, line_of_business, geography)
AS SELECT 
    valuation_date,
    line_of_business,
    geography,
    profitability_class,
    sum(initial_csm) as opening_csm,
    sum(csm_amortization) as period_amortization,
    sum(initial_csm) - sum(csm_amortization) as closing_csm,
    count() as contract_group_count
FROM reserves
GROUP BY valuation_date, line_of_business, geography, profitability_class;

-- Materialized view for reserve adequacy monitoring
CREATE MATERIALIZED VIEW IF NOT EXISTS reserve_adequacy_mv
ENGINE = ReplacingMergeTree(valuation_date)
PARTITION BY cohort_year
ORDER BY (line_of_business, geography, cohort_year)
AS SELECT 
    line_of_business,
    geography,
    cohort_year,
    argMax(valuation_date, valuation_date) as latest_valuation,
    argMax(reserve_adequacy_ratio, valuation_date) as latest_adequacy_ratio,
    argMax(total_outstanding, valuation_date) as latest_outstanding,
    argMax(pv_claims, valuation_date) as latest_pv_claims,
    count() as valuation_count
FROM reserves
GROUP BY line_of_business, geography, cohort_year;

SHOW TABLES;