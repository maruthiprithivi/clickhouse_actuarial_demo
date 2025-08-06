-- ClickHouse Actuarial Demo - Real-Time Catastrophe Response
-- Demonstrates rapid exposure analysis and loss estimation for catastrophic events
-- Shows sub-second response capabilities for emergency decision making

USE actuarial;

-- =============================================================================
-- 1. GEOGRAPHIC EXPOSURE CONCENTRATION
-- =============================================================================

-- Identify exposure concentrations by geography (catastrophe modeling foundation)
SELECT 
    geography,
    line_of_business,
    count() as policy_count,
    round(sum(sum_insured), 0) as total_exposure,
    round(sum(premium), 0) as total_premium,
    round(avg(sum_insured), 0) as avg_policy_size,
    round(max(sum_insured), 0) as largest_policy,
    -- Concentration metrics
    round(
        sum(sum_insured) / (
            SELECT sum(sum_insured) FROM policies 
            WHERE line_of_business IN ('Motor', 'Property')
        ), 4
    ) as exposure_concentration_pct,
    -- Risk indicators
    countIf(sum_insured > 1000000) as high_value_policies,
    sumIf(sum_insured, sum_insured > 1000000) as high_value_exposure
FROM policies
WHERE line_of_business IN ('Motor', 'Property')  -- Cat-exposed lines
GROUP BY geography, line_of_business
ORDER BY total_exposure DESC
LIMIT 20;

-- =============================================================================
-- 2. SIMULATED HURRICANE EXPOSURE ANALYSIS
-- =============================================================================

-- Simulate hurricane impact on portfolio (replace with actual catastrophe zone data)
WITH hurricane_zones AS (
    -- Simulate Hurricane impact zones (in reality, this would be from cat models)
    SELECT 
        geography,
        multiIf(
            geography IN ('FL', 'LA', 'TX'), 'Hurricane_Zone_1',  -- High impact
            geography IN ('NC', 'SC', 'GA'), 'Hurricane_Zone_2', -- Medium impact  
            geography IN ('VA', 'MD'), 'Hurricane_Zone_3',       -- Low impact
            'No_Impact'
        ) as hurricane_zone,
        multiIf(
            geography IN ('FL', 'LA', 'TX'), 0.08,  -- 8% expected loss ratio
            geography IN ('NC', 'SC', 'GA'), 0.04,  -- 4% expected loss ratio
            geography IN ('VA', 'MD'), 0.02,        -- 2% expected loss ratio  
            0.00
        ) as expected_loss_ratio
    FROM (SELECT DISTINCT geography FROM policies)
),
exposure_analysis AS (
    SELECT 
        h.hurricane_zone,
        p.line_of_business,
        count() as exposed_policies,
        sum(p.sum_insured) as total_exposure,
        sum(p.premium) as total_premium,
        h.expected_loss_ratio,
        -- Calculate expected losses
        sum(p.sum_insured) * h.expected_loss_ratio as expected_gross_loss,
        -- Apply reinsurance recovery (simplified)
        sum(p.sum_insured) * h.expected_loss_ratio * 0.7 as expected_net_loss
    FROM policies p
    JOIN hurricane_zones h ON p.geography = h.geography
    WHERE h.hurricane_zone != 'No_Impact'
      AND p.line_of_business IN ('Motor', 'Property')
    GROUP BY h.hurricane_zone, p.line_of_business, h.expected_loss_ratio
)
SELECT 
    hurricane_zone,
    line_of_business,
    exposed_policies,
    round(total_exposure, 0) as total_exposure,
    round(total_premium, 0) as total_premium,
    round(expected_loss_ratio * 100, 1) as expected_loss_ratio_pct,
    round(expected_gross_loss, 0) as expected_gross_loss,
    round(expected_net_loss, 0) as expected_net_loss,
    -- Impact ratios
    round(expected_gross_loss / total_premium, 2) as loss_to_premium_ratio,
    round(expected_net_loss / total_exposure, 4) as net_loss_ratio
FROM exposure_analysis
ORDER BY expected_gross_loss DESC;

-- =============================================================================
-- 3. REAL-TIME CATASTROPHE CLAIMS MONITORING
-- =============================================================================

-- Monitor catastrophe claims as they develop (simulated event)
WITH catastrophe_claims AS (
    SELECT 
        claim_id,
        accident_date,
        geography,
        line_of_business,
        claim_status,
        incurred_amount,
        paid_amount,
        outstanding_reserve,
        -- Simulate catastrophe identification
        multiIf(
            JSONExtractString(claim_attributes, 'catastrophe_related') = 'true', 'CAT_2024_001',
            incurred_amount > 100000 AND geography IN ('FL', 'TX', 'LA'), 'CAT_2024_001',
            'Non-CAT'
        ) as event_code,
        -- Time since event
        dateDiff('hour', accident_date, now()) as hours_since_event
    FROM claims
    WHERE accident_date >= '2024-01-01'  -- Recent claims only
),
cat_summary AS (
    SELECT 
        event_code,
        geography,
        line_of_business,
        count() as claim_count,
        sum(incurred_amount) as total_incurred,
        sum(paid_amount) as total_paid,
        sum(outstanding_reserve) as total_outstanding,
        avg(incurred_amount) as avg_claim_severity,
        max(incurred_amount) as max_claim_severity,
        -- Development indicators
        round(sum(paid_amount) / sum(incurred_amount), 4) as payment_ratio,
        min(hours_since_event) as min_hours_since_event,
        max(hours_since_event) as max_hours_since_event
    FROM catastrophe_claims
    WHERE event_code != 'Non-CAT'
    GROUP BY event_code, geography, line_of_business
)
SELECT 
    event_code,
    geography,
    line_of_business,
    claim_count,
    round(total_incurred, 0) as total_incurred,
    round(total_paid, 0) as total_paid,
    round(total_outstanding, 0) as total_outstanding,
    round(avg_claim_severity, 0) as avg_claim_severity,
    round(max_claim_severity, 0) as max_claim_severity,
    payment_ratio,
    round(min_hours_since_event / 24.0, 1) as min_days_since_event,
    round(max_hours_since_event / 24.0, 1) as max_days_since_event,
    -- Status indicators
    multiIf(
        payment_ratio > 0.5, 'Fast Development',
        payment_ratio > 0.2, 'Normal Development',
        'Slow Development'
    ) as development_status
FROM cat_summary
ORDER BY total_incurred DESC;

-- =============================================================================
-- 4. PORTFOLIO STRESS TESTING
-- =============================================================================

-- Stress test portfolio against various catastrophe scenarios
WITH stress_scenarios AS (
    SELECT 
        'Major Hurricane' as scenario_name,
        0.12 as loss_ratio,
        'FL,TX,LA,NC,SC' as affected_states
    UNION ALL
    SELECT 
        'Widespread Tornado',
        0.06,
        'TX,OK,KS,MO,IL'
    UNION ALL
    SELECT 
        'California Earthquake',
        0.15,
        'CA'
    UNION ALL
    SELECT 
        'Northeast Winter Storm',  
        0.04,
        'NY,MA,CT,NJ,PA'
),
portfolio_exposure AS (
    SELECT 
        geography,
        line_of_business,
        sum(sum_insured) as total_exposure,
        sum(premium) as total_premium,
        count() as policy_count
    FROM policies
    WHERE line_of_business IN ('Motor', 'Property')
    GROUP BY geography, line_of_business
),
stress_results AS (
    SELECT 
        s.scenario_name,
        s.loss_ratio,
        sum(CASE WHEN position(p.geography IN s.affected_states) > 0 
            THEN p.total_exposure ELSE 0 END) as exposed_sum_insured,
        sum(CASE WHEN position(p.geography IN s.affected_states) > 0 
            THEN p.total_premium ELSE 0 END) as exposed_premium,
        sum(CASE WHEN position(p.geography IN s.affected_states) > 0 
            THEN p.policy_count ELSE 0 END) as exposed_policies
    FROM stress_scenarios s
    CROSS JOIN portfolio_exposure p
    GROUP BY s.scenario_name, s.loss_ratio
)
SELECT 
    scenario_name,
    round(loss_ratio * 100, 1) as loss_ratio_pct,
    exposed_policies,
    round(exposed_sum_insured, 0) as exposed_sum_insured,
    round(exposed_premium, 0) as exposed_premium,
    round(exposed_sum_insured * loss_ratio, 0) as estimated_gross_loss,
    round(exposed_sum_insured * loss_ratio * 0.75, 0) as estimated_net_loss,
    -- Impact metrics
    round(
        (exposed_sum_insured * loss_ratio) / exposed_premium, 2
    ) as loss_to_premium_ratio,
    round(
        exposed_sum_insured / (SELECT sum(sum_insured) FROM policies), 4
    ) as exposure_concentration
FROM stress_results
ORDER BY estimated_gross_loss DESC;

-- =============================================================================
-- 5. REINSURANCE OPTIMIZATION ANALYSIS
-- =============================================================================

-- Analyze reinsurance program effectiveness against catastrophe scenarios
WITH reinsurance_layers AS (
    -- Simulate reinsurance program structure
    SELECT 1 as layer, 10000000 as attachment, 40000000 as limit, 0.85 as recovery_rate
    UNION ALL
    SELECT 2, 50000000, 50000000, 0.90
    UNION ALL  
    SELECT 3, 100000000, 100000000, 0.95
),
catastrophe_losses AS (
    -- Simulate range of catastrophe loss scenarios
    SELECT 
        'Scenario_' || toString(number) as scenario,
        15000000 + number * 25000000 as gross_loss  -- $15M to $515M range
    FROM numbers(1, 21)  -- 21 scenarios
),
recovery_analysis AS (
    SELECT 
        c.scenario,
        c.gross_loss,
        -- Calculate reinsurance recoveries
        greatest(0, least(c.gross_loss - r1.attachment, r1.limit)) * r1.recovery_rate +
        greatest(0, least(c.gross_loss - r2.attachment, r2.limit)) * r2.recovery_rate +
        greatest(0, least(c.gross_loss - r3.attachment, r3.limit)) * r3.recovery_rate as total_recovery,
        c.gross_loss - (
            greatest(0, least(c.gross_loss - r1.attachment, r1.limit)) * r1.recovery_rate +
            greatest(0, least(c.gross_loss - r2.attachment, r2.limit)) * r2.recovery_rate +
            greatest(0, least(c.gross_loss - r3.attachment, r3.limit)) * r3.recovery_rate
        ) as net_loss
    FROM catastrophe_losses c
    CROSS JOIN (SELECT * FROM reinsurance_layers WHERE layer = 1) r1
    CROSS JOIN (SELECT * FROM reinsurance_layers WHERE layer = 2) r2  
    CROSS JOIN (SELECT * FROM reinsurance_layers WHERE layer = 3) r3
)
SELECT 
    scenario,
    round(gross_loss, 0) as gross_loss,
    round(total_recovery, 0) as reinsurance_recovery,
    round(net_loss, 0) as net_loss,
    round(total_recovery / gross_loss, 3) as recovery_ratio,
    round(net_loss / gross_loss, 3) as net_retention_ratio,
    -- Risk assessment
    multiIf(
        net_loss > 200000000, 'Severe Impact',
        net_loss > 100000000, 'Major Impact', 
        net_loss > 50000000, 'Moderate Impact',
        'Manageable Impact'
    ) as impact_assessment
FROM recovery_analysis
ORDER BY gross_loss;

-- =============================================================================
-- 6. EMERGENCY DECISION SUPPORT
-- =============================================================================

-- Real-time decision support dashboard for catastrophe response
WITH emergency_metrics AS (
    SELECT 
        -- Portfolio totals
        (SELECT count() FROM policies WHERE line_of_business IN ('Motor', 'Property')) as total_cat_policies,
        (SELECT sum(sum_insured) FROM policies WHERE line_of_business IN ('Motor', 'Property')) as total_cat_exposure,
        (SELECT sum(premium) FROM policies WHERE line_of_business IN ('Motor', 'Property')) as total_cat_premium,
        
        -- High-risk zones (simplified)
        (SELECT count() FROM policies WHERE geography IN ('FL', 'TX', 'LA', 'CA') 
         AND line_of_business IN ('Motor', 'Property')) as high_risk_policies,
        (SELECT sum(sum_insured) FROM policies WHERE geography IN ('FL', 'TX', 'LA', 'CA')
         AND line_of_business IN ('Motor', 'Property')) as high_risk_exposure,
         
        -- Current reserves available for catastrophes
        (SELECT sum(outstanding_reserve) FROM claims 
         WHERE claim_status IN ('Open', 'Reserved')) as current_reserves,
         
        -- Recent catastrophe activity
        (SELECT count() FROM claims 
         WHERE accident_date >= today() - 30 
         AND JSONExtractString(claim_attributes, 'catastrophe_related') = 'true') as recent_cat_claims,
        (SELECT sum(incurred_amount) FROM claims 
         WHERE accident_date >= today() - 30 
         AND JSONExtractString(claim_attributes, 'catastrophe_related') = 'true') as recent_cat_losses
)
SELECT 
    'CATASTROPHE RESPONSE DASHBOARD' as dashboard_title,
    total_cat_policies as total_policies_at_risk,
    round(total_cat_exposure, 0) as total_exposure_at_risk,
    round(total_cat_premium, 0) as total_premium_cat_lines,
    high_risk_policies,
    round(high_risk_exposure, 0) as high_risk_exposure,
    round(high_risk_exposure / total_cat_exposure, 3) as high_risk_concentration,
    round(current_reserves, 0) as available_reserves,
    recent_cat_claims,
    round(recent_cat_losses, 0) as recent_cat_losses_30d,
    -- Capacity indicators
    round(current_reserves / (total_cat_exposure * 0.05), 1) as reserve_adequacy_ratio,
    multiIf(
        current_reserves / (total_cat_exposure * 0.05) > 2.0, 'Strong',
        current_reserves / (total_cat_exposure * 0.05) > 1.0, 'Adequate',
        'Monitor Closely'
    ) as financial_strength_status,
    now() as dashboard_timestamp
FROM emergency_metrics;

-- =============================================================================
-- 7. CATASTROPHE RESPONSE PERFORMANCE
-- =============================================================================

-- Demonstrate sub-second catastrophe analysis capabilities
SELECT 
    'Catastrophe Response Performance' as demo_type,
    (SELECT count() FROM policies WHERE line_of_business IN ('Motor', 'Property')) as policies_analyzed,
    (SELECT sum(sum_insured) FROM policies WHERE line_of_business IN ('Motor', 'Property')) as exposure_analyzed,
    (SELECT count() FROM claims WHERE accident_date >= today() - 365) as recent_claims_analyzed,
    uniq(geography) as geographic_regions_analyzed,
    now() as analysis_timestamp,
    'Real-time catastrophe exposure analysis - seconds vs hours in traditional systems' as performance_note
FROM policies
WHERE line_of_business IN ('Motor', 'Property')
LIMIT 1;

-- This catastrophe analysis runs in milliseconds, enabling real-time decision making
-- Traditional systems require hours or days for similar analysis during emergencies