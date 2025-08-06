-- ClickHouse Actuarial Demo - IFRS 17 CSM Calculations
-- Demonstrates JSON handling and complex financial calculations for IFRS 17
-- Shows real-time contractual service margin analysis

USE actuarial;

-- =============================================================================
-- 1. IFRS 17 LIABILITY COMPONENTS SUMMARY
-- =============================================================================

-- Current IFRS 17 balance sheet position
SELECT 
    line_of_business,
    profitability_class,
    count() as contract_groups,
    -- Key IFRS 17 components
    round(sum(pv_premiums), 0) as total_pv_premiums,
    round(sum(pv_claims), 0) as total_pv_claims,
    round(sum(acquisition_costs), 0) as total_acquisition_costs,
    round(sum(risk_adjustment), 0) as total_risk_adjustment,
    round(sum(initial_csm), 0) as total_csm,
    round(sum(loss_component), 0) as total_loss_component,
    round(sum(liability_remaining_coverage), 0) as total_lrc,
    -- Profitability metrics
    round(
        sum(initial_csm) / nullif(sum(pv_premiums), 0), 4
    ) as csm_margin_ratio,
    round(
        sum(loss_component) / nullif(sum(pv_premiums), 0), 4
    ) as loss_ratio
FROM reserves
GROUP BY line_of_business, profitability_class
ORDER BY line_of_business, profitability_class;

-- =============================================================================
-- 2. CSM MOVEMENTS AND AMORTIZATION
-- =============================================================================

-- Track CSM movements over reporting periods
WITH csm_movements AS (
    SELECT 
        contract_group_id,
        line_of_business,
        geography,
        cohort_year,
        valuation_date,
        initial_csm,
        csm_amortization,
        -- Calculate closing CSM
        initial_csm - csm_amortization as closing_csm,
        coverage_units_current,
        coverage_units_total,
        -- Amortization rate
        round(
            csm_amortization / nullif(initial_csm, 0), 4
        ) as amortization_rate_period,
        -- Remaining coverage ratio
        round(
            coverage_units_current / nullif(coverage_units_total, 0), 4
        ) as remaining_coverage_ratio
    FROM reserves
    WHERE profitability_class = 'Profitable'
      AND initial_csm > 0
)
SELECT 
    line_of_business,
    toYear(valuation_date) as reporting_year,
    count() as profitable_contract_groups,
    round(sum(initial_csm), 0) as opening_csm,
    round(sum(csm_amortization), 0) as period_amortization,
    round(sum(closing_csm), 0) as closing_csm,
    -- Portfolio metrics
    round(avg(amortization_rate_period), 4) as avg_amortization_rate,
    round(avg(remaining_coverage_ratio), 4) as avg_remaining_coverage,
    -- Expected future amortization
    round(sum(closing_csm) * avg(amortization_rate_period), 0) as projected_next_period_amort
FROM csm_movements
GROUP BY line_of_business, toYear(valuation_date)
ORDER BY line_of_business, reporting_year DESC;

-- =============================================================================
-- 3. ONEROUS CONTRACT ANALYSIS
-- =============================================================================

-- Analyze loss components from onerous contracts
SELECT 
    line_of_business,
    geography,
    cohort_year,
    count() as onerous_contract_groups,
    round(sum(loss_component), 0) as total_loss_component,
    round(sum(pv_claims), 0) as total_pv_claims,
    round(sum(pv_premiums), 0) as total_pv_premiums,
    round(sum(risk_adjustment), 0) as total_risk_adjustment,
    -- Loss ratios
    round(
        sum(pv_claims) / nullif(sum(pv_premiums), 0), 4
    ) as claims_to_premium_ratio,
    round(
        sum(loss_component) / nullif(sum(pv_premiums), 0), 4
    ) as loss_component_ratio,
    -- Coverage analysis
    sum(coverage_units_total) as total_coverage_units,
    round(
        sum(loss_component) / nullif(sum(coverage_units_total), 0), 2
    ) as loss_per_coverage_unit
FROM reserves
WHERE profitability_class = 'Onerous'
GROUP BY line_of_business, geography, cohort_year
ORDER BY total_loss_component DESC;

-- =============================================================================
-- 4. DISCOUNT RATE SENSITIVITY ANALYSIS
-- =============================================================================

-- Analyze impact of discount rate changes on IFRS 17 measurements
WITH sensitivity_analysis AS (
    SELECT 
        contract_group_id,
        line_of_business,
        pv_claims,
        pv_premiums,
        pv_factor,
        -- Extract discount rate from metadata
        toFloat64(JSONExtractString(reserve_metadata, 'actuarial_assumptions.discount_rate')) as current_discount_rate,
        -- Simulate different discount rate scenarios
        pv_claims / pv_factor as undiscounted_claims,
        pv_premiums / pv_factor as undiscounted_premiums
    FROM reserves
    WHERE JSONHas(reserve_metadata, 'actuarial_assumptions.discount_rate')
),
scenario_calculations AS (
    SELECT 
        line_of_business,
        -- Base scenario (current rates)
        sum(pv_claims) as base_pv_claims,
        sum(pv_premiums) as base_pv_premiums,
        -- +100 basis points scenario
        sum(undiscounted_claims / pow(1 + current_discount_rate + 0.01, 5)) as up100bp_pv_claims,
        sum(undiscounted_premiums / pow(1 + current_discount_rate + 0.01, 5)) as up100bp_pv_premiums,
        -- -100 basis points scenario  
        sum(undiscounted_claims / pow(1 + current_discount_rate - 0.01, 5)) as down100bp_pv_claims,
        sum(undiscounted_premiums / pow(1 + current_discount_rate - 0.01, 5)) as down100bp_pv_premiums
    FROM sensitivity_analysis
    GROUP BY line_of_business
)
SELECT 
    line_of_business,
    round(base_pv_claims, 0) as base_pv_claims,
    round(base_pv_premiums, 0) as base_pv_premiums,
    round(base_pv_premiums - base_pv_claims, 0) as base_net_margin,
    -- Impact of +100bp rate increase
    round(up100bp_pv_claims - base_pv_claims, 0) as up100bp_claims_impact,
    round(up100bp_pv_premiums - base_pv_premiums, 0) as up100bp_premiums_impact,
    round((up100bp_pv_premiums - up100bp_pv_claims) - (base_pv_premiums - base_pv_claims), 0) as up100bp_net_impact,
    -- Impact of -100bp rate decrease
    round(down100bp_pv_claims - base_pv_claims, 0) as down100bp_claims_impact,
    round(down100bp_pv_premiums - base_pv_premiums, 0) as down100bp_premiums_impact,
    round((down100bp_pv_premiums - down100bp_pv_claims) - (base_pv_premiums - base_pv_claims), 0) as down100bp_net_impact
FROM scenario_calculations
ORDER BY abs(up100bp_net_impact) DESC;

-- =============================================================================
-- 5. COHORT PROFITABILITY ANALYSIS
-- =============================================================================

-- Analyze profitability trends by cohort year
WITH cohort_profitability AS (
    SELECT 
        cohort_year,
        line_of_business,
        count() as total_contract_groups,
        countIf(profitability_class = 'Profitable') as profitable_groups,
        countIf(profitability_class = 'Onerous') as onerous_groups,
        sum(pv_premiums) as total_pv_premiums,
        sum(pv_claims) as total_pv_claims,
        sum(initial_csm) as total_csm,
        sum(loss_component) as total_loss_component,
        -- Calculate net result
        sum(initial_csm) - sum(loss_component) as net_profitability
    FROM reserves
    GROUP BY cohort_year, line_of_business
)
SELECT 
    cohort_year,
    line_of_business,
    total_contract_groups,
    profitable_groups,
    onerous_groups,
    round(profitable_groups / total_contract_groups, 2) as profitable_ratio,
    round(total_pv_premiums, 0) as total_pv_premiums,
    round(total_pv_claims, 0) as total_pv_claims,
    round(total_csm, 0) as total_csm,
    round(total_loss_component, 0) as total_loss_component,
    round(net_profitability, 0) as net_profitability,
    -- Profitability metrics
    round(net_profitability / total_pv_premiums, 4) as profit_margin_ratio,
    round(total_pv_claims / total_pv_premiums, 4) as loss_ratio
FROM cohort_profitability
ORDER BY cohort_year DESC, line_of_business;

-- =============================================================================
-- 6. COVERAGE UNITS AND SERVICE PATTERNS
-- =============================================================================

-- Analyze coverage units for CSM amortization patterns
SELECT 
    line_of_business,
    profitability_class,
    count() as contract_groups,
    sum(coverage_units_total) as total_coverage_units,
    sum(coverage_units_current) as current_coverage_units,
    round(
        sum(coverage_units_current) / sum(coverage_units_total), 4
    ) as remaining_coverage_ratio,
    -- Service pattern analysis
    round(avg(coverage_units_total), 0) as avg_total_units_per_group,
    round(stddevPop(coverage_units_total), 0) as std_dev_coverage_units,
    -- CSM amortization implications
    round(
        sum(initial_csm) * (sum(coverage_units_current) / sum(coverage_units_total)), 0
    ) as expected_remaining_csm,
    round(
        sum(csm_amortization) / nullif(sum(initial_csm), 0), 4
    ) as period_amortization_rate
FROM reserves
WHERE coverage_units_total > 0
GROUP BY line_of_business, profitability_class
ORDER BY line_of_business, profitability_class;

-- =============================================================================
-- 7. RISK ADJUSTMENT ANALYSIS
-- =============================================================================

-- Analyze risk adjustment components and adequacy
WITH risk_analysis AS (
    SELECT 
        line_of_business,
        geography,
        sum(risk_adjustment) as total_risk_adjustment,
        sum(pv_claims) as total_pv_claims,
        sum(best_estimate_liability) as total_bel,
        -- Extract confidence level from metadata
        avg(toFloat64(JSONExtractString(reserve_metadata, 'confidence_level'))) as avg_confidence_level,
        count() as contract_groups
    FROM reserves
    WHERE JSONHas(reserve_metadata, 'confidence_level')
    GROUP BY line_of_business, geography
)
SELECT 
    line_of_business,
    geography,
    contract_groups,
    round(total_risk_adjustment, 0) as total_risk_adjustment,
    round(total_pv_claims, 0) as total_pv_claims,
    round(total_bel, 0) as total_bel,
    round(avg_confidence_level, 2) as avg_confidence_level,
    -- Risk adjustment ratios
    round(total_risk_adjustment / total_pv_claims, 4) as ra_to_claims_ratio,
    round(total_risk_adjustment / total_bel, 4) as ra_to_bel_ratio,
    -- Risk adjustment adequacy assessment
    multiIf(
        total_risk_adjustment / total_pv_claims > 0.10, 'High',
        total_risk_adjustment / total_pv_claims > 0.05, 'Moderate',
        'Low'
    ) as risk_adjustment_level
FROM risk_analysis
ORDER BY total_risk_adjustment DESC;

-- =============================================================================
-- 8. IFRS 17 PERFORMANCE METRICS
-- =============================================================================

-- Demonstrate real-time IFRS 17 calculation performance
SELECT 
    'IFRS 17 CSM Calculation Performance' as demo_type,
    count() as contract_groups_processed,
    sum(initial_csm) as total_csm_calculated,
    sum(loss_component) as total_loss_component_calculated,
    uniq(line_of_business) as lines_analyzed,
    uniq(cohort_year) as cohort_years_analyzed,
    uniq(profitability_class) as profitability_classes,
    now() as calculation_timestamp,
    'Complex IFRS 17 calculations in milliseconds vs days in traditional systems' as performance_note
FROM reserves;

-- Traditional IFRS 17 calculations require complex spreadsheets and days of processing
-- ClickHouse enables real-time CSM analysis and scenario testing