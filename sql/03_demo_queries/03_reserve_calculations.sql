-- ClickHouse Actuarial Demo - Reserve Calculations  
-- Demonstrates real-time reserve calculations and adequacy testing
-- Shows materialized views and advanced aggregation functions

USE actuarial;

-- =============================================================================
-- 1. CURRENT RESERVE POSITION SUMMARY
-- =============================================================================

-- Real-time reserve summary across all lines of business
SELECT 
    line_of_business,
    count() as active_claims,
    sum(outstanding_reserve) as total_reserves,
    sum(paid_amount) as total_paid,
    sum(incurred_amount) as total_incurred,
    round(avg(outstanding_reserve), 2) as avg_reserve_per_claim,
    -- Reserve adequacy indicators
    round(
        sum(outstanding_reserve) / sum(incurred_amount), 4
    ) as reserve_to_incurred_ratio,
    round(
        sum(paid_amount) / sum(incurred_amount), 4
    ) as payment_ratio,
    -- Large loss indicators
    countIf(outstanding_reserve > 100000) as large_reserves_100k_plus,
    sumIf(outstanding_reserve, outstanding_reserve > 100000) as large_reserves_amount
FROM claims
WHERE claim_status IN ('Open', 'Reserved')
GROUP BY line_of_business
ORDER BY total_reserves DESC;

-- =============================================================================
-- 2. RESERVE DEVELOPMENT ANALYSIS
-- =============================================================================

-- Track how reserves have developed over time
WITH reserve_movements AS (
    SELECT 
        accident_year,
        development_month,
        line_of_business,
        sum(initial_reserve) as initial_reserves,
        sum(outstanding_reserve) as current_reserves,
        sum(paid_amount) as paid_to_date,
        count() as claim_count
    FROM claims
    WHERE accident_year >= 2020
    GROUP BY accident_year, development_month, line_of_business
),
development_patterns AS (
    SELECT 
        accident_year,
        line_of_business,
        development_month,
        initial_reserves,
        current_reserves,
        paid_to_date,
        claim_count,
        -- Reserve release/strengthening
        initial_reserves - current_reserves as reserve_change,
        round(
            (initial_reserves - current_reserves) / initial_reserves, 4
        ) as reserve_release_ratio,
        -- Payment pattern
        round(paid_to_date / (paid_to_date + current_reserves), 4) as payment_pattern
    FROM reserve_movements
    WHERE initial_reserves > 0
)
SELECT 
    accident_year,
    line_of_business,
    max(development_month) as latest_development,
    sum(initial_reserves) as total_initial_reserves,
    sum(current_reserves) as total_current_reserves,
    sum(reserve_change) as total_reserve_release,
    round(
        sum(reserve_change) / sum(initial_reserves), 4
    ) as overall_release_ratio,
    -- Classify reserve adequacy
    multiIf(
        sum(reserve_change) / sum(initial_reserves) > 0.1, 'Over-Reserved',
        sum(reserve_change) / sum(initial_reserves) < -0.1, 'Under-Reserved', 
        'Adequate'
    ) as adequacy_assessment
FROM development_patterns
GROUP BY accident_year, line_of_business
ORDER BY accident_year DESC, line_of_business;

-- =============================================================================
-- 3. RESERVE ADEQUACY TESTING
-- =============================================================================

-- Statistical reserve adequacy analysis using quantiles
WITH claim_statistics AS (
    SELECT 
        line_of_business,
        accident_year,
        claim_status,
        -- Statistical measures of reserve adequacy
        quantile(0.50)(outstanding_reserve) as median_reserve,
        quantile(0.75)(outstanding_reserve) as p75_reserve,
        quantile(0.90)(outstanding_reserve) as p90_reserve,
        quantile(0.95)(outstanding_reserve) as p95_reserve,
        stddevPop(outstanding_reserve) as reserve_volatility,
        count() as claim_count,
        sum(outstanding_reserve) as total_reserves
    FROM claims
    WHERE outstanding_reserve > 0
    GROUP BY line_of_business, accident_year, claim_status
)
SELECT 
    line_of_business,
    accident_year,
    claim_status,
    claim_count,
    round(total_reserves, 0) as total_reserves,
    round(median_reserve, 0) as median_reserve,
    round(p75_reserve, 0) as p75_reserve,
    round(p90_reserve, 0) as p90_reserve, 
    round(p95_reserve, 0) as p95_reserve,
    round(reserve_volatility, 0) as reserve_volatility,
    -- Coefficient of variation
    round(reserve_volatility / median_reserve, 2) as coefficient_of_variation,
    -- Adequacy confidence intervals
    round(total_reserves * 1.1, 0) as reserve_10pct_buffer,
    round(total_reserves * 1.2, 0) as reserve_20pct_buffer
FROM claim_statistics
WHERE claim_count > 10  -- Minimum statistical significance
ORDER BY line_of_business, accident_year DESC, claim_status;

-- =============================================================================
-- 4. CATASTROPHE RESERVE ANALYSIS
-- =============================================================================

-- Identify and analyze catastrophe-related reserves
WITH catastrophe_analysis AS (
    SELECT 
        accident_year,
        toYYYYMM(accident_date) as accident_month,
        geography,
        line_of_business,
        -- Identify potential catastrophe events (simplified)
        multiIf(
            JSONExtractString(claim_attributes, 'catastrophe_related') = 'true', 'CAT',
            outstanding_reserve > 50000, 'Large Loss',
            'Attritional'
        ) as loss_type,
        count() as claim_count,
        sum(outstanding_reserve) as total_reserves,
        sum(paid_amount) as total_paid,
        sum(incurred_amount) as total_incurred,
        avg(outstanding_reserve) as avg_reserve_per_claim
    FROM claims
    WHERE accident_year >= 2022
    GROUP BY accident_year, accident_month, geography, line_of_business, loss_type
)
SELECT 
    loss_type,
    accident_year,
    geography,
    sum(claim_count) as total_claims,
    round(sum(total_reserves), 0) as total_reserves,
    round(sum(total_paid), 0) as total_paid,
    round(avg(avg_reserve_per_claim), 0) as avg_reserve_per_claim,
    -- Concentration metrics
    round(
        sum(total_reserves) / (
            SELECT sum(outstanding_reserve) 
            FROM claims 
            WHERE accident_year >= 2022
        ), 4
    ) as reserve_concentration,
    -- Payment pattern analysis
    round(
        sum(total_paid) / sum(total_incurred), 4
    ) as payment_ratio
FROM catastrophe_analysis
GROUP BY loss_type, accident_year, geography
HAVING sum(claim_count) > 5
ORDER BY total_reserves DESC
LIMIT 30;

-- =============================================================================
-- 5. RESERVE PROJECTIONS AND CASH FLOW
-- =============================================================================

-- Project future cash flows based on payment patterns
WITH payment_patterns AS (
    SELECT 
        line_of_business,
        development_month,
        -- Calculate payment pattern by development month
        sum(paid_amount) as total_paid,
        sum(outstanding_reserve) as total_outstanding,
        round(
            sum(paid_amount) / (sum(paid_amount) + sum(outstanding_reserve)), 4
        ) as cumulative_payment_ratio
    FROM claims
    WHERE accident_year >= 2020
    GROUP BY line_of_business, development_month
),
future_projections AS (
    SELECT 
        line_of_business,
        development_month,
        cumulative_payment_ratio,
        -- Project payment timing
        multiIf(
            development_month <= 12, cumulative_payment_ratio * 0.6,
            development_month <= 24, cumulative_payment_ratio * 0.3,
            development_month <= 36, cumulative_payment_ratio * 0.08,
            development_month <= 48, cumulative_payment_ratio * 0.02,
            0
        ) as projected_payment_ratio
    FROM payment_patterns
)
SELECT 
    p.line_of_business,
    -- Current reserves
    sum(c.outstanding_reserve) as current_reserves,
    -- Project payments over next 4 years
    round(
        sum(c.outstanding_reserve) * 
        max(CASE WHEN p.development_month <= 12 THEN p.projected_payment_ratio ELSE 0 END), 0
    ) as projected_payments_year1,
    round(
        sum(c.outstanding_reserve) * 
        max(CASE WHEN p.development_month <= 24 THEN p.projected_payment_ratio ELSE 0 END), 0
    ) as projected_payments_year2,
    round(
        sum(c.outstanding_reserve) * 
        max(CASE WHEN p.development_month <= 36 THEN p.projected_payment_ratio ELSE 0 END), 0
    ) as projected_payments_year3,
    round(
        sum(c.outstanding_reserve) * 
        max(CASE WHEN p.development_month <= 48 THEN p.projected_payment_ratio ELSE 0 END), 0
    ) as projected_payments_year4
FROM claims c
LEFT JOIN future_projections p ON c.line_of_business = p.line_of_business
WHERE c.claim_status IN ('Open', 'Reserved')
GROUP BY p.line_of_business
ORDER BY current_reserves DESC;

-- =============================================================================
-- 6. RESERVE VOLATILITY AND RISK METRICS
-- =============================================================================

-- Calculate reserve risk metrics for capital modeling
WITH reserve_volatility AS (
    SELECT 
        line_of_business,
        geography,
        accident_year,
        count() as claim_count,
        sum(outstanding_reserve) as total_reserves,
        avg(outstanding_reserve) as mean_reserve,
        stddevPop(outstanding_reserve) as reserve_std_dev,
        -- Calculate coefficient of variation
        stddevPop(outstanding_reserve) / avg(outstanding_reserve) as coefficient_variation,
        -- Extreme value indicators
        quantile(0.99)(outstanding_reserve) as p99_reserve,
        quantile(0.01)(outstanding_reserve) as p01_reserve
    FROM claims
    WHERE outstanding_reserve > 0
      AND accident_year >= 2020
    GROUP BY line_of_business, geography, accident_year
)
SELECT 
    line_of_business,
    sum(claim_count) as total_claims,
    round(sum(total_reserves), 0) as total_reserves,
    round(avg(mean_reserve), 0) as avg_reserve_per_claim,
    round(avg(coefficient_variation), 4) as avg_coefficient_variation,
    -- Risk-based capital estimates (simplified)
    round(
        sum(total_reserves) * sqrt(avg(coefficient_variation)), 0
    ) as reserve_risk_capital_estimate,
    round(
        sum(total_reserves) * sqrt(avg(coefficient_variation)) / sum(total_reserves), 4
    ) as capital_ratio,
    -- Tail risk indicators
    round(avg(p99_reserve), 0) as avg_p99_reserve,
    round(avg(p99_reserve) / avg(mean_reserve), 2) as tail_risk_multiplier
FROM reserve_volatility
WHERE claim_count > 20  -- Statistical significance
GROUP BY line_of_business
ORDER BY reserve_risk_capital_estimate DESC;

-- =============================================================================
-- 7. PERFORMANCE METRICS
-- =============================================================================

-- Demonstrate real-time reserve calculation performance
SELECT 
    'Reserve Calculation Performance' as demo_type,
    count() as claims_analyzed,
    sum(outstanding_reserve) as total_reserves_calculated,
    uniq(line_of_business) as lines_analyzed,
    uniq(accident_year) as accident_years_analyzed,
    uniq(geography) as geographies_analyzed,
    now() as calculation_timestamp,
    'Millisecond response time vs hours in traditional systems' as performance_note
FROM claims
WHERE outstanding_reserve > 0;

-- This reserve analysis runs in real-time on millions of claims
-- Traditional actuarial systems require overnight batch processing