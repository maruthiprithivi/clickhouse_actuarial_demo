-- ClickHouse Actuarial Demo - Mortality Analysis
-- Demonstrates real-time mortality experience analysis and trend detection
-- Shows window functions and time series capabilities

USE actuarial;

-- =============================================================================
-- 1. MORTALITY EXPERIENCE BY DEMOGRAPHIC
-- =============================================================================

-- Basic mortality analysis by age band and gender
WITH mortality_data AS (
    SELECT 
        customer_age,
        customer_gender,
        -- Create age bands for analysis
        multiIf(
            customer_age < 25, '18-24',
            customer_age < 35, '25-34', 
            customer_age < 45, '35-44',
            customer_age < 55, '45-54',
            customer_age < 65, '55-64',
            customer_age < 75, '65-74',
            '75+'
        ) as age_band,
        count() as exposure_count,
        -- Simulate mortality events (in real data, this would be actual deaths)
        countIf(JSONExtractString(risk_factors, 'health_rating') = 'Standard') as standard_risk,
        countIf(customer_age > 65) as senior_policies
    FROM policies 
    WHERE line_of_business = 'Life'
    GROUP BY customer_age, customer_gender
)
SELECT 
    age_band,
    customer_gender,
    sum(exposure_count) as total_exposure,
    -- Simulated mortality rate (would be actual deaths / exposure in real data)
    round(
        sum(exposure_count) * 
        multiIf(
            age_band = '18-24', 0.0005,
            age_band = '25-34', 0.0008,
            age_band = '35-44', 0.0015,
            age_band = '45-54', 0.0035,
            age_band = '55-64', 0.0080,
            age_band = '65-74', 0.0180,
            0.0400
        ), 2
    ) as expected_deaths,
    -- Expected mortality rate per 1000
    round(
        multiIf(
            age_band = '18-24', 0.5,
            age_band = '25-34', 0.8,
            age_band = '35-44', 1.5,
            age_band = '45-54', 3.5,
            age_band = '55-64', 8.0,
            age_band = '65-74', 18.0,
            40.0
        ), 1
    ) as expected_rate_per_1000
FROM mortality_data
GROUP BY age_band, customer_gender
ORDER BY 
    CASE age_band 
        WHEN '18-24' THEN 1
        WHEN '25-34' THEN 2
        WHEN '35-44' THEN 3
        WHEN '45-54' THEN 4
        WHEN '55-64' THEN 5
        WHEN '65-74' THEN 6
        ELSE 7
    END,
    customer_gender;

-- =============================================================================
-- 2. TIME SERIES MORTALITY TRENDS
-- =============================================================================

-- Monthly mortality experience trends using window functions
WITH monthly_experience AS (
    SELECT 
        toYYYYMM(effective_date) as experience_month,
        toDate(toStartOfMonth(effective_date)) as month_start,
        customer_gender,
        multiIf(
            customer_age < 35, 'Young',
            customer_age < 55, 'Middle',
            'Senior'
        ) as age_group,
        count() as policies_inforce,
        -- Simulate actual vs expected deaths
        round(count() * 0.002, 1) as simulated_deaths,
        round(count() * 0.0025, 1) as expected_deaths
    FROM policies
    WHERE line_of_business = 'Life'
      AND effective_date >= '2022-01-01'
    GROUP BY experience_month, month_start, customer_gender, age_group
)
SELECT 
    month_start,
    age_group,
    customer_gender,
    policies_inforce,
    simulated_deaths as actual_deaths,
    expected_deaths,
    round(simulated_deaths / expected_deaths, 4) as actual_to_expected_ratio,
    -- 12-month rolling average A/E ratio
    round(
        avg(simulated_deaths / expected_deaths) OVER (
            PARTITION BY age_group, customer_gender
            ORDER BY month_start
            ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
        ), 4
    ) as rolling_12m_ae_ratio,
    -- Year-over-year comparison
    round(
        simulated_deaths / 
        lag(simulated_deaths, 12) OVER (
            PARTITION BY age_group, customer_gender
            ORDER BY month_start
        ), 4
    ) as yoy_mortality_ratio
FROM monthly_experience
WHERE simulated_deaths > 0
ORDER BY month_start DESC, age_group, customer_gender
LIMIT 50;

-- =============================================================================
-- 3. GEOGRAPHIC MORTALITY VARIATIONS
-- =============================================================================

-- Mortality variations by geography (useful for pricing)
SELECT 
    geography,
    count() as life_policies,
    sum(sum_insured) as total_coverage,
    round(avg(customer_age), 1) as avg_age,
    -- Simulate mortality variations by state
    round(
        count() * multiIf(
            geography IN ('FL', 'AZ'), 0.0035,  -- Higher retirement states
            geography IN ('CA', 'NY'), 0.0025,  -- Urban states
            geography IN ('TX', 'IL'), 0.0028,  -- Mixed demographics
            0.0030  -- Other states
        ), 1
    ) as expected_annual_deaths,
    -- Calculate credibility
    round(sqrt(count()) / 100, 2) as credibility_factor,
    -- Risk-adjusted pricing indication
    round(
        multiIf(
            geography IN ('FL', 'AZ'), 1.15,
            geography IN ('CA', 'NY'), 0.95,
            geography IN ('TX', 'IL'), 1.02,
            1.08
        ), 3
    ) as geographic_pricing_factor
FROM policies
WHERE line_of_business = 'Life'
GROUP BY geography
HAVING count() > 1000  -- Minimum credibility threshold
ORDER BY expected_annual_deaths DESC;

-- =============================================================================
-- 4. COHORT MORTALITY ANALYSIS
-- =============================================================================

-- Mortality analysis by policy cohort (issue year)
WITH cohort_analysis AS (
    SELECT 
        toYear(effective_date) as issue_year,
        customer_age,
        customer_gender,
        count() as cohort_size,
        avg(sum_insured) as avg_coverage,
        -- Calculate policy duration in years
        round(
            avg(dateDiff('year', effective_date, now())), 1
        ) as avg_duration_years
    FROM policies
    WHERE line_of_business = 'Life'
      AND effective_date >= '2020-01-01'
    GROUP BY issue_year, customer_age, customer_gender
),
mortality_rates AS (
    SELECT 
        issue_year,
        customer_age,
        customer_gender,
        cohort_size,
        avg_coverage,
        avg_duration_years,
        -- Expected mortality based on standard tables
        multiIf(
            customer_age < 30, 0.0008,
            customer_age < 40, 0.0015,
            customer_age < 50, 0.0035,
            customer_age < 60, 0.0080,
            customer_age < 70, 0.0180,
            0.0400
        ) as base_mortality_rate,
        -- Adjust for duration (mortality improvement/deterioration)
        base_mortality_rate * (1 - avg_duration_years * 0.01) as duration_adjusted_rate
    FROM cohort_analysis
)
SELECT 
    issue_year,
    customer_gender,
    sum(cohort_size) as total_policies,
    round(avg(customer_age), 1) as avg_issue_age,
    round(avg(avg_duration_years), 1) as avg_duration,
    round(
        sum(cohort_size * duration_adjusted_rate), 1
    ) as expected_annual_deaths,
    round(
        sum(cohort_size * duration_adjusted_rate) / sum(cohort_size) * 1000, 2
    ) as mortality_rate_per_1000
FROM mortality_rates
GROUP BY issue_year, customer_gender
ORDER BY issue_year DESC, customer_gender;

-- =============================================================================
-- 5. ADVANCED MORTALITY MODELING
-- =============================================================================

-- Mortality shock testing and sensitivity analysis
WITH base_assumptions AS (
    SELECT 
        line_of_business,
        geography,
        customer_gender,
        count() as policy_count,
        sum(sum_insured) as total_coverage,
        avg(customer_age) as avg_age,
        -- Base mortality assumption
        sum(sum_insured) * 0.003 as base_expected_claims
    FROM policies
    WHERE line_of_business = 'Life'
    GROUP BY line_of_business, geography, customer_gender
)
SELECT 
    geography,
    customer_gender,
    policy_count,
    round(total_coverage, 0) as total_coverage,
    round(avg_age, 1) as avg_age,
    round(base_expected_claims, 0) as base_expected_claims,
    -- Mortality shock scenarios
    round(base_expected_claims * 1.15, 0) as pandemic_shock_15pct,
    round(base_expected_claims * 1.25, 0) as severe_pandemic_25pct,
    round(base_expected_claims * 0.95, 0) as improvement_5pct,
    -- Calculate impact on reserves/pricing
    round((base_expected_claims * 1.15 - base_expected_claims), 0) as pandemic_impact,
    round(
        (base_expected_claims * 1.15 - base_expected_claims) / base_expected_claims, 4
    ) as impact_ratio
FROM base_assumptions
WHERE policy_count > 500
ORDER BY pandemic_impact DESC
LIMIT 20;

-- =============================================================================
-- 6. PERFORMANCE METRICS
-- =============================================================================

-- Query performance demonstration
SELECT 
    'Mortality Analysis Performance' as demo_type,
    count() as life_policies_analyzed,
    uniq(customer_age) as age_cohorts,
    uniq(geography) as geographic_regions,
    uniqExact(customer_gender) as gender_categories,
    round(sum(sum_insured), 0) as total_coverage_analyzed,
    now() as analysis_timestamp
FROM policies
WHERE line_of_business = 'Life';

-- This type of analysis traditionally takes hours in spreadsheets
-- ClickHouse delivers results in milliseconds, enabling real-time pricing