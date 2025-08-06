-- ClickHouse Actuarial Demo - Load Reserves Data
-- Loads IFRS 17 reserves and CSM data

USE actuarial;

-- Load from Parquet (default format)
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
FROM file('/data/reserves.parquet', 'Parquet')
SETTINGS input_format_parquet_import_nested = 1;

-- Verify load and show IFRS 17 summary
SELECT 
    'Reserves loaded' as status,
    count() as contract_groups,
    uniq(line_of_business) as lines_of_business,
    sum(initial_csm) as total_csm,
    sum(loss_component) as total_loss_component,
    sum(best_estimate_liability) as total_bel
FROM reserves;

-- IFRS 17 summary by profitability
SELECT 
    profitability_class,
    count() as contract_count,
    sum(initial_csm) as total_csm,
    sum(loss_component) as total_loss_component,
    sum(liability_remaining_coverage) as total_lrc,
    round(avg(reserve_adequacy_ratio), 4) as avg_adequacy_ratio
FROM reserves
GROUP BY profitability_class
ORDER BY profitability_class;

-- CSM by line of business
SELECT 
    line_of_business,
    sum(initial_csm) as total_csm,
    sum(csm_amortization) as period_amortization,
    sum(initial_csm) - sum(csm_amortization) as remaining_csm,
    count() as contract_groups
FROM reserves
WHERE profitability_class = 'Profitable'
GROUP BY line_of_business
ORDER BY total_csm DESC;