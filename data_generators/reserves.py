"""
Reserves Data Generator - Creates IFRS 17 and reserve adequacy data
Includes CSM calculations, risk adjustments, and present value factors
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import json

np.random.seed(42)


def generate_reserves(claims_df):
    """Generate reserve data based on claims for IFRS 17 and reserve adequacy"""
    
    print(f"   🔄 Generating reserves for {len(claims_df):,} claims...")
    
    # Group claims by policy/contract groups
    contract_groups = claims_df.groupby(['line_of_business', 'geography', 'accident_year']).agg({
        'policy_id': 'nunique',
        'claim_id': 'count', 
        'incurred_amount': 'sum',
        'paid_amount': 'sum',
        'outstanding_reserve': 'sum'
    }).reset_index()
    
    contract_groups.columns = [
        'line_of_business', 'geography', 'cohort_year', 
        'policy_count', 'claim_count', 'total_incurred', 
        'total_paid', 'total_outstanding'
    ]
    
    # Generate contract group IDs
    contract_groups['contract_group_id'] = [
        f"{lob}_{geo}_{year}"
        for lob, geo, year in zip(
            contract_groups['line_of_business'],
            contract_groups['geography'],
            contract_groups['cohort_year']
        )
    ]
    
    # Valuation dates (quarterly reporting)
    valuation_dates = []
    base_date = datetime(2024, 12, 31)  # Latest valuation
    for i in range(len(contract_groups)):
        # Random recent quarter-end date
        quarters_back = np.random.randint(0, 8)  # Up to 2 years back
        val_date = base_date - timedelta(days=quarters_back * 90)
        # Snap to quarter end
        if val_date.month <= 3:
            val_date = val_date.replace(month=3, day=31) 
        elif val_date.month <= 6:
            val_date = val_date.replace(month=6, day=30)
        elif val_date.month <= 9:
            val_date = val_date.replace(month=9, day=30)
        else:
            val_date = val_date.replace(month=12, day=31)
        valuation_dates.append(val_date)
    
    contract_groups['valuation_date'] = valuation_dates
    
    # IFRS 17 Present Value calculations
    # Discount rates by line of business (annual rates)
    discount_rates = {
        'Motor': 0.045,
        'Property': 0.042,
        'Life': 0.038,
        'Health': 0.040,
        'Pension': 0.035
    }
    
    # Calculate present values
    pv_factors = []
    present_value_claims = []
    present_value_premiums = []
    
    for _, row in contract_groups.iterrows():
        lob = row['line_of_business']
        rate = discount_rates.get(lob, 0.04)
        
        # Duration varies by line of business
        if lob == 'Life':
            duration = np.random.normal(15, 5)  # Long-term
        elif lob == 'Pension':
            duration = np.random.normal(20, 8)  # Very long-term
        else:
            duration = np.random.normal(3, 1)   # Short-term
        
        duration = max(0.5, duration)
        
        # Present value factor
        pv_factor = 1 / (1 + rate) ** duration
        pv_factors.append(round(pv_factor, 6))
        
        # Apply to claims and estimate premiums
        pv_claims = row['total_incurred'] * pv_factor
        present_value_claims.append(round(pv_claims, 2))
        
        # Estimate premiums (typically 110-120% of claims for profitability)
        premium_ratio = np.random.uniform(1.10, 1.20)
        pv_premiums = pv_claims * premium_ratio
        present_value_premiums.append(round(pv_premiums, 2))
    
    contract_groups['pv_factor'] = pv_factors
    contract_groups['pv_claims'] = present_value_claims
    contract_groups['pv_premiums'] = present_value_premiums
    
    # Risk Adjustments (regulatory requirement)
    # Typically 5-15% of present value of claims
    risk_adjustment_rates = np.random.uniform(0.05, 0.15, len(contract_groups))
    contract_groups['risk_adjustment'] = [
        round(pv_claims * rate, 2)
        for pv_claims, rate in zip(present_value_claims, risk_adjustment_rates)
    ]
    
    # Acquisition Costs (simplified)
    # Typically 10-25% of premiums for new business
    acquisition_cost_rates = np.random.uniform(0.10, 0.25, len(contract_groups))
    contract_groups['acquisition_costs'] = [
        round(pv_premiums * rate, 2)
        for pv_premiums, rate in zip(present_value_premiums, acquisition_cost_rates)
    ]
    
    # IFRS 17 CSM Calculation
    # CSM = PV Premiums - PV Claims - Acquisition Costs - Risk Adjustment (if profitable)
    csm_values = []
    loss_components = []
    profitability_classes = []
    
    for _, row in contract_groups.iterrows():
        pv_premiums = row['pv_premiums']
        pv_claims = row['pv_claims']
        acq_costs = row['acquisition_costs']
        risk_adj = row['risk_adjustment']
        
        # Calculate net margin
        net_margin = pv_premiums - pv_claims - acq_costs - risk_adj
        
        if net_margin > 0:
            # Profitable contract - CSM recognized
            csm_values.append(round(net_margin, 2))
            loss_components.append(0.0)
            profitability_classes.append('Profitable')
        else:
            # Onerous contract - loss component recognized
            csm_values.append(0.0)
            loss_components.append(round(abs(net_margin), 2))
            profitability_classes.append('Onerous')
    
    contract_groups['initial_csm'] = csm_values
    contract_groups['loss_component'] = loss_components
    contract_groups['profitability_class'] = profitability_classes
    
    # CSM Coverage Units (for amortization)
    # Simplified: based on policy count and duration
    coverage_units_total = []
    coverage_units_current = []
    
    for _, row in contract_groups.iterrows():
        # Total coverage units = policies × expected coverage period (months)
        if row['line_of_business'] == 'Life':
            months = np.random.randint(120, 480)  # 10-40 years
        elif row['line_of_business'] == 'Pension':
            months = np.random.randint(240, 600)  # 20-50 years
        else:
            months = np.random.randint(12, 60)    # 1-5 years
            
        total_units = row['policy_count'] * months
        coverage_units_total.append(total_units)
        
        # Current period units (remaining)
        remaining_ratio = np.random.uniform(0.5, 1.0)  # 50-100% remaining
        current_units = int(total_units * remaining_ratio)
        coverage_units_current.append(current_units)
    
    contract_groups['coverage_units_total'] = coverage_units_total
    contract_groups['coverage_units_current'] = coverage_units_current
    
    # CSM Amortization for current period
    csm_amortization = []
    for _, row in contract_groups.iterrows():
        if row['coverage_units_total'] > 0:
            amort_rate = row['coverage_units_current'] / row['coverage_units_total']
            amortization = row['initial_csm'] * amort_rate * 0.25  # Quarterly rate
            csm_amortization.append(round(amortization, 2))
        else:
            csm_amortization.append(0.0)
    
    contract_groups['csm_amortization'] = csm_amortization
    
    # Best Estimate Liability (BEL)
    contract_groups['best_estimate_liability'] = [
        round(pv_claims + risk_adj, 2)
        for pv_claims, risk_adj in zip(
            contract_groups['pv_claims'], 
            contract_groups['risk_adjustment']
        )
    ]
    
    # Total Liability for Remaining Coverage (LRC)
    contract_groups['liability_remaining_coverage'] = [
        round(bel + csm - loss, 2)
        for bel, csm, loss in zip(
            contract_groups['best_estimate_liability'],
            contract_groups['initial_csm'],
            contract_groups['loss_component']
        )
    ]
    
    # Reserve adequacy ratios (for traditional analysis)
    contract_groups['reserve_adequacy_ratio'] = [
        round(total_outstanding / max(1, pv_claims), 4)
        for total_outstanding, pv_claims in zip(
            contract_groups['total_outstanding'],
            contract_groups['pv_claims']
        )
    ]
    
    # Additional metadata as JSON
    reserve_metadata = []
    for _, row in contract_groups.iterrows():
        metadata = {
            'actuarial_assumptions': {
                'discount_rate': discount_rates.get(row['line_of_business'], 0.04),
                'risk_margin': round(row['risk_adjustment'] / max(1, row['pv_claims']), 4)
            },
            'valuation_method': 'IFRS_17',
            'confidence_level': np.random.choice([0.75, 0.85, 0.95], p=[0.2, 0.6, 0.2]),
            'last_updated': row['valuation_date'].isoformat()
        }
        reserve_metadata.append(json.dumps(metadata))
    
    contract_groups['reserve_metadata'] = reserve_metadata
    
    return contract_groups


if __name__ == "__main__":
    # Test generation with sample claims data
    from claims import generate_claims
    
    claims_df = generate_claims(1000, 5000)
    reserves_df = generate_reserves(claims_df)
    
    print(reserves_df.head())
    print(f"\nDataFrame shape: {reserves_df.shape}")
    print(f"Memory usage: {reserves_df.memory_usage(deep=True).sum() / 1024 / 1024:.1f} MB")
    
    # Show profitability distribution
    print("\n📊 Profitability Distribution:") 
    print(reserves_df['profitability_class'].value_counts())