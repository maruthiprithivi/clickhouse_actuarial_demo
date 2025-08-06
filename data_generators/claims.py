"""
Claims Data Generator - Creates realistic loss development patterns
Designed specifically for loss triangle and development factor analysis
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from faker import Faker
import json

fake = Faker()
Faker.seed(42)
np.random.seed(42)


def generate_claims(policy_count=100_000, total_claims=500_000):
    """Generate claims with realistic development patterns for triangles"""
    
    print(f"   🔄 Generating {total_claims:,} claims for {policy_count:,} policies...")
    
    # Policy IDs to link to
    policy_ids = np.random.randint(1, policy_count + 1, total_claims)
    
    # Claim IDs
    claim_ids = range(1, total_claims + 1)
    claim_numbers = [f"CLM{id:08d}" for id in claim_ids]
    
    # Accident dates (weighted toward recent years for realistic patterns)
    start_date = datetime(2020, 1, 1)
    end_date = datetime(2024, 12, 31)
    
    # Create accident year distribution (more recent claims)
    accident_years = np.random.choice(
        [2020, 2021, 2022, 2023, 2024],
        total_claims,
        p=[0.15, 0.18, 0.20, 0.25, 0.22]  # More recent years have more claims
    )
    
    accident_dates = []
    for year in accident_years:
        month = np.random.randint(1, 13)
        day = np.random.randint(1, 29)  # Avoid month-end issues
        accident_dates.append(datetime(year, month, day))
    
    # Report dates (some delay from accident)
    report_delays = np.random.exponential(30, total_claims)  # Average 30-day delay
    report_delays = np.clip(report_delays, 0, 365)  # Max 1 year delay
    
    report_dates = [
        acc_date + timedelta(days=int(delay))
        for acc_date, delay in zip(accident_dates, report_delays)
    ]
    
    # Development months (key for loss triangles)
    development_months = []
    for acc_date, rep_date in zip(accident_dates, report_dates):
        # Calculate months since accident
        months = (rep_date.year - acc_date.year) * 12 + (rep_date.month - acc_date.month)
        development_months.append(max(1, months + 1))  # Start from month 1
    
    # Claim amounts with realistic loss development
    # Initial reserves (often overestimated)
    initial_reserves = np.random.lognormal(8.5, 1.5, total_claims)  # $5K-$50K typical
    initial_reserves = np.round(initial_reserves, 2)
    
    # Development factors for different development months
    def get_development_factor(dev_month):
        """Realistic development factors based on industry patterns"""
        if dev_month <= 12:
            return np.random.normal(0.95, 0.1)  # Claims develop downward initially
        elif dev_month <= 24:
            return np.random.normal(1.02, 0.05)  # Some development
        elif dev_month <= 36:
            return np.random.normal(1.01, 0.03)  # Minimal development
        else:
            return np.random.normal(1.00, 0.02)  # Stable
    
    # Calculate developed amounts
    developed_amounts = []
    for i, (initial, dev_month) in enumerate(zip(initial_reserves, development_months)):
        factor = get_development_factor(dev_month)
        developed = initial * max(0.1, factor)  # Prevent negative claims
        developed_amounts.append(round(developed, 2))
    
    # Payment patterns (claims pay out over time)
    payment_patterns = np.random.beta(2, 5, total_claims)  # Most claims pay quickly
    paid_amounts = [
        round(developed * pattern, 2) 
        for developed, pattern in zip(developed_amounts, payment_patterns)
    ]
    
    # Outstanding reserves
    outstanding_reserves = [
        max(0, developed - paid) 
        for developed, paid in zip(developed_amounts, paid_amounts)
    ]
    
    # Claim status
    claim_status = []
    for outstanding in outstanding_reserves:
        if outstanding <= 10:  # Small reserves considered closed
            claim_status.append('Closed')
        elif outstanding <= 1000:
            claim_status.append('Open')
        else:
            claim_status.append('Reserved')
    
    # Line of business (should match policy, but simplified here)
    lob_choices = ['Motor', 'Property', 'Life', 'Health', 'Pension']
    lob_weights = [0.40, 0.30, 0.15, 0.10, 0.05]  # Motor claims most frequent
    lines_of_business = np.random.choice(lob_choices, total_claims, p=lob_weights)
    
    # Claim causes (for categorical analysis)
    cause_by_lob = {
        'Motor': ['Collision', 'Theft', 'Vandalism', 'Weather', 'Other'],
        'Property': ['Fire', 'Theft', 'Weather', 'Water', 'Other'],
        'Life': ['Natural', 'Accident', 'Illness', 'Other', 'Unknown'],
        'Health': ['Surgery', 'Emergency', 'Routine', 'Specialist', 'Other'],
        'Pension': ['Retirement', 'Disability', 'Death', 'Withdrawal', 'Other']
    }
    
    claim_causes = []
    for lob in lines_of_business:
        causes = cause_by_lob[lob]
        weights = [0.3, 0.2, 0.2, 0.2, 0.1]  # First cause most common
        claim_causes.append(np.random.choice(causes, p=weights))
    
    # Geography (simplified)
    geographies = np.random.choice(
        ['CA', 'TX', 'FL', 'NY', 'IL', 'PA', 'OH', 'GA', 'NC', 'MI', 'Other'],
        total_claims,
        p=[0.12, 0.10, 0.08, 0.08, 0.06, 0.05, 0.05, 0.04, 0.04, 0.04, 0.34]
    )
    
    # Additional claim attributes (as JSON)
    claim_attributes = []
    for i in range(total_claims):
        attrs = {
            'complexity': np.random.choice(['Simple', 'Medium', 'Complex'], p=[0.6, 0.3, 0.1]),
            'legal_involvement': np.random.choice([True, False], p=[0.1, 0.9]),
            'catastrophe_related': np.random.choice([True, False], p=[0.05, 0.95]),
            'salvage_potential': np.random.choice([True, False], p=[0.15, 0.85])
        }
        claim_attributes.append(json.dumps(attrs))
    
    # Create DataFrame
    df = pd.DataFrame({
        'claim_id': claim_ids,
        'claim_number': claim_numbers, 
        'policy_id': policy_ids,
        'accident_date': accident_dates,
        'report_date': report_dates,
        'accident_year': [date.year for date in accident_dates],
        'development_month': development_months,
        'line_of_business': lines_of_business,
        'geography': geographies,
        'claim_cause': claim_causes,
        'claim_status': claim_status,
        'initial_reserve': initial_reserves,
        'paid_amount': paid_amounts,
        'outstanding_reserve': outstanding_reserves,
        'incurred_amount': developed_amounts,
        'claim_attributes': claim_attributes
    })
    
    return df


if __name__ == "__main__":
    # Test generation
    df = generate_claims(1000, 5000)
    print(df.head())
    print(f"\nDataFrame shape: {df.shape}")
    print(f"Memory usage: {df.memory_usage(deep=True).sum() / 1024 / 1024:.1f} MB")
    
    # Show development pattern summary
    print("\n📊 Development Month Distribution:")
    print(df['development_month'].value_counts().head(10))