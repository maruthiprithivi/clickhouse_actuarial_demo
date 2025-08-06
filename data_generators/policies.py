"""
Policy Data Generator - Creates realistic insurance policies
Supports Life, P&C, Health, and Pension lines of business
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from faker import Faker
import json

fake = Faker()
Faker.seed(42)
np.random.seed(42)


def generate_policies(count=100_000):
    """Generate realistic insurance policies with key actuarial attributes"""
    
    print(f"   🔄 Generating {count:,} policies...")
    
    # Policy basics
    policy_ids = range(1, count + 1)
    policy_numbers = [f"POL{id:08d}" for id in policy_ids]
    
    # Date ranges
    start_date = datetime(2020, 1, 1)
    end_date = datetime(2024, 12, 31)
    
    effective_dates = [
        fake.date_between(start_date=start_date, end_date=end_date)
        for _ in range(count)
    ]
    
    expiry_dates = [
        eff_date + timedelta(days=365) if np.random.random() > 0.1 
        else eff_date + timedelta(days=np.random.randint(30, 365))
        for eff_date in effective_dates
    ]
    
    # Lines of business with realistic distribution
    lob_choices = ['Motor', 'Property', 'Life', 'Health', 'Pension']
    lob_weights = [0.35, 0.25, 0.20, 0.15, 0.05]  # Motor is most common
    lines_of_business = np.random.choice(lob_choices, count, p=lob_weights)
    
    # Sum insured based on line of business
    sum_insured = []
    for lob in lines_of_business:
        if lob == 'Motor':
            si = np.random.lognormal(10.5, 0.7)  # $25K-$100K range
        elif lob == 'Property':
            si = np.random.lognormal(12.5, 0.8)  # $200K-$800K range
        elif lob == 'Life':
            si = np.random.lognormal(11.5, 1.0)  # $50K-$500K range
        elif lob == 'Health':
            si = np.random.lognormal(9.0, 0.5)   # $5K-$20K range
        else:  # Pension
            si = np.random.lognormal(13.0, 0.6)  # $300K-$1M range
        sum_insured.append(round(si, 2))
    
    # Premium calculation (roughly 2-8% of sum insured)
    premium_rates = np.random.uniform(0.02, 0.08, count)
    premiums = [round(si * rate, 2) for si, rate in zip(sum_insured, premium_rates)]
    
    # Geography with realistic distribution
    geographies = np.random.choice(
        ['CA', 'TX', 'FL', 'NY', 'IL', 'PA', 'OH', 'GA', 'NC', 'MI', 'Other'],
        count,
        p=[0.12, 0.10, 0.08, 0.08, 0.06, 0.05, 0.05, 0.04, 0.04, 0.04, 0.34]
    )
    
    # Customer demographics
    customer_ages = np.random.gamma(2, 20).astype(int)  # Skewed toward younger
    customer_ages = np.clip(customer_ages, 18, 85)
    
    customer_genders = np.random.choice(['M', 'F'], count, p=[0.48, 0.52])
    
    # Risk factors (as JSON for flexibility)
    risk_factors = []
    for i in range(count):
        factors = {}
        if lines_of_business[i] == 'Motor':
            factors['vehicle_age'] = np.random.randint(0, 20)
            factors['driver_experience'] = max(0, customer_ages[i] - 16)
            factors['safety_rating'] = np.random.choice(['Poor', 'Good', 'Excellent'], p=[0.2, 0.6, 0.2])
        elif lines_of_business[i] == 'Property':
            factors['construction_year'] = np.random.randint(1950, 2024)
            factors['construction_type'] = np.random.choice(['Wood', 'Brick', 'Concrete'], p=[0.6, 0.3, 0.1])
            factors['flood_zone'] = np.random.choice(['Low', 'Medium', 'High'], p=[0.7, 0.2, 0.1])
        elif lines_of_business[i] == 'Life':
            factors['smoker'] = np.random.choice([True, False], p=[0.15, 0.85])
            factors['health_rating'] = np.random.choice(['Standard', 'Preferred', 'Super Preferred'], p=[0.6, 0.3, 0.1])
            factors['occupation_class'] = np.random.choice(['Professional', 'Standard', 'Hazardous'], p=[0.4, 0.5, 0.1])
        
        risk_factors.append(json.dumps(factors))
    
    # Create DataFrame
    df = pd.DataFrame({
        'policy_id': policy_ids,
        'policy_number': policy_numbers,
        'effective_date': effective_dates,
        'expiry_date': expiry_dates,
        'line_of_business': lines_of_business,
        'sum_insured': sum_insured,
        'premium': premiums,
        'geography': geographies,
        'customer_age': customer_ages,
        'customer_gender': customer_genders,
        'risk_factors': risk_factors
    })
    
    return df


if __name__ == "__main__":
    # Test generation
    df = generate_policies(1000)
    print(df.head())
    print(f"\nDataFrame shape: {df.shape}")
    print(f"Memory usage: {df.memory_usage(deep=True).sum() / 1024 / 1024:.1f} MB")