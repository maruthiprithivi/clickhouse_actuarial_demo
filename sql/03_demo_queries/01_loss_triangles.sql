-- ClickHouse Actuarial Demo - Loss Development Triangles
-- Demonstrates array functions for actuarial triangle construction and analysis
-- Shows sub-second performance on millions of claims

USE actuarial;

-- =============================================================================
-- 1. BASIC LOSS TRIANGLE CONSTRUCTION
-- =============================================================================

-- Traditional triangle view - paid amounts by accident year and development month
SELECT 
    accident_year,
    development_month,
    sum(paid_amount) as cumulative_paid,
    sum(incurred_amount) as cumulative_incurred,
    count() as claim_count
FROM claims
WHERE accident_year >= 2020
GROUP BY accident_year, development_month
ORDER BY accident_year, development_month
LIMIT 50;

-- =============================================================================
-- 2. ARRAY-BASED TRIANGLE CONSTRUCTION (ClickHouse Power!)
-- =============================================================================

-- Build triangles using ClickHouse array functions
-- This is where ClickHouse shines vs traditional databases
WITH triangle_data AS (
    SELECT 
        accident_year,
        development_month,
        sum(paid_amount) as cumulative_paid,
        sum(incurred_amount) as cumulative_incurred
    FROM claims 
    WHERE accident_year >= 2020
    GROUP BY accident_year, development_month
),
triangle_arrays AS (
    SELECT 
        accident_year,
        -- Create arrays of development data
        groupArray(cumulative_paid) as paid_array,
        groupArray(cumulative_incurred) as incurred_array,
        groupArray(development_month) as development_months,
        -- Calculate incremental amounts using arrayDifference
        arrayDifference(groupArray(cumulative_paid)) as incremental_paid
    FROM triangle_data 
    GROUP BY accident_year
    ORDER BY accident_year
)
SELECT 
    accident_year,
    -- Show first 12 months of development
    arraySlice(paid_array, 1, 12) as paid_triangle_12m,
    arraySlice(incremental_paid, 1, 12) as incremental_paid_12m,
    -- Ultimate loss estimate (sum of all incremental)
    arraySum(incremental_paid) as ultimate_loss_estimate,
    -- Array length shows development tail
    length(paid_array) as development_periods
FROM triangle_arrays;

-- =============================================================================
-- 3. DEVELOPMENT FACTOR CALCULATIONS
-- =============================================================================

-- Calculate age-to-age development factors using window functions
WITH development_data AS (
    SELECT 
        accident_year,
        development_month,
        sum(paid_amount) as cumulative_paid
    FROM claims
    WHERE accident_year >= 2020
    GROUP BY accident_year, development_month
),
factors AS (
    SELECT 
        accident_year,
        development_month,
        cumulative_paid,
        -- Previous development month paid amount
        lag(cumulative_paid) OVER (
            PARTITION BY accident_year 
            ORDER BY development_month
        ) as prior_paid,
        -- Development factor calculation
        CASE 
            WHEN lag(cumulative_paid) OVER (
                PARTITION BY accident_year 
                ORDER BY development_month
            ) > 0 
            THEN cumulative_paid / lag(cumulative_paid) OVER (
                PARTITION BY accident_year 
                ORDER BY development_month
            )
            ELSE 1.0 
        END as development_factor
    FROM development_data
)
SELECT 
    development_month,
    count(*) as data_points,
    round(avg(development_factor), 4) as avg_factor,
    round(median(development_factor), 4) as median_factor,
    round(stddevPop(development_factor), 4) as factor_volatility,
    -- Selected factor using volume-weighted average
    round(
        sum(prior_paid * development_factor) / sum(prior_paid), 4
    ) as selected_factor
FROM factors
WHERE development_factor IS NOT NULL 
  AND prior_paid > 1000  -- Credibility threshold
GROUP BY development_month
HAVING count(*) >= 3  -- Minimum credibility
ORDER BY development_month
LIMIT 24;  -- Show first 24 months

-- =============================================================================
-- 4. CHAIN LADDER PROJECTIONS
-- =============================================================================

-- Ultimate loss projections using chain ladder method
WITH triangle_base AS (
    SELECT 
        accident_year,
        development_month,
        sum(paid_amount) as cumulative_paid
    FROM claims
    WHERE accident_year >= 2020
    GROUP BY accident_year, development_month
),
-- Selected development factors (simplified - use results from query above)
selected_factors AS (
    SELECT 
        development_month,
        multiIf(
            development_month = 1, 2.50,
            development_month = 2, 1.45,
            development_month = 3, 1.25, 
            development_month = 4, 1.15,
            development_month = 5, 1.10,
            development_month <= 12, 1.05,
            development_month <= 24, 1.02,
            1.00
        ) as factor
    FROM (SELECT DISTINCT development_month FROM triangle_base)
),
projections AS (
    SELECT 
        t.accident_year,
        t.development_month,
        t.cumulative_paid,
        f.factor,
        -- Project to ultimate using remaining factors
        t.cumulative_paid * arrayProduct(
            arraySlice(
                groupArray(f.factor) OVER (ORDER BY f.development_month),
                t.development_month,
                50  -- Project 50 periods forward
            )
        ) as ultimate_projection
    FROM triangle_base t
    LEFT JOIN selected_factors f ON t.development_month = f.development_month
)
SELECT 
    accident_year,
    max(cumulative_paid) as latest_paid,
    max(ultimate_projection) as ultimate_projection,
    max(ultimate_projection) - max(cumulative_paid) as ibnr_estimate,
    round(
        (max(ultimate_projection) - max(cumulative_paid)) / max(cumulative_paid), 4
    ) as ibnr_ratio
FROM projections
GROUP BY accident_year
ORDER BY accident_year DESC;

-- =============================================================================
-- 5. LINE OF BUSINESS TRIANGLES
-- =============================================================================

-- Multi-dimensional triangles by line of business
SELECT 
    line_of_business,
    accident_year,
    -- Use arrayMap to transform the array
    arrayMap(x -> round(x, 0), 
        arraySlice(groupArray(cumulative_paid ORDER BY development_month), 1, 12)
    ) as paid_triangle_12m,
    sum(cumulative_paid) as total_paid_to_date
FROM (
    SELECT 
        line_of_business,
        accident_year,
        development_month,
        sum(paid_amount) as cumulative_paid
    FROM claims
    WHERE accident_year >= 2022
    GROUP BY line_of_business, accident_year, development_month
)
GROUP BY line_of_business, accident_year
ORDER BY line_of_business, accident_year
LIMIT 20;

-- =============================================================================
-- 6. PERFORMANCE DEMONSTRATION
-- =============================================================================

-- Show query performance on large dataset
SELECT 
    'Performance Test' as demo,
    count() as total_claims_processed,
    uniq(accident_year) as accident_years,
    max(development_month) as max_development_period,
    uniq(line_of_business) as lines_of_business,
    now() as query_timestamp
FROM claims;

-- This query typically runs in milliseconds on millions of claims
-- Traditional databases would take minutes or hours for similar analysis