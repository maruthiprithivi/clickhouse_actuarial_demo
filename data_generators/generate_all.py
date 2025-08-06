#!/usr/bin/env python3
"""
ClickHouse Actuarial Demo - Unified Data Generator
Generates realistic actuarial datasets for loss triangles, mortality analysis, and IFRS 17 demos
"""

import os
import argparse
from datetime import datetime
import pandas as pd
from pathlib import Path

from policies import generate_policies
from claims import generate_claims  
from reserves import generate_reserves


def main():
    parser = argparse.ArgumentParser(description='Generate actuarial demo data')
    parser.add_argument('--scale', choices=['sample', 'medium', 'full'], 
                       default='sample', help='Data scale to generate')
    parser.add_argument('--format', choices=['csv', 'parquet'], 
                       default='parquet', help='Output format')
    parser.add_argument('--output-dir', default='../data', 
                       help='Output directory for generated files')
    
    args = parser.parse_args()
    
    # Create output directory
    output_dir = Path(args.output_dir)
    output_dir.mkdir(exist_ok=True)
    
    # Scale configurations
    scales = {
        'sample': {'policies': 100_000, 'claims': 500_000},
        'medium': {'policies': 1_000_000, 'claims': 5_000_000},
        'full': {'policies': 15_000_000, 'claims': 100_000_000}
    }
    
    config = scales[args.scale]
    
    print(f"🏗️  Generating {args.scale} scale actuarial data...")
    print(f"📊 Policies: {config['policies']:,}")
    print(f"💰 Claims: {config['claims']:,}")
    print(f"💾 Format: {args.format}")
    print(f"📁 Output: {output_dir}")
    
    # Generate datasets
    start_time = datetime.now()
    
    print("\n1️⃣  Generating policies...")
    policies_df = generate_policies(count=config['policies'])
    save_data(policies_df, output_dir / f'policies.{args.format}', args.format)
    
    print("2️⃣  Generating claims...")
    claims_df = generate_claims(
        policy_count=config['policies'], 
        total_claims=config['claims']
    )
    save_data(claims_df, output_dir / f'claims.{args.format}', args.format)
    
    print("3️⃣  Generating reserves...")  
    reserves_df = generate_reserves(claims_df)
    save_data(reserves_df, output_dir / f'reserves.{args.format}', args.format)
    
    elapsed = datetime.now() - start_time
    print(f"\n✅ Data generation complete in {elapsed.total_seconds():.1f} seconds")
    print(f"📈 Total records: {len(policies_df) + len(claims_df) + len(reserves_df):,}")


def save_data(df, filepath, format_type):
    """Save DataFrame to specified format"""
    if format_type == 'parquet':
        df.to_parquet(filepath, index=False, compression='snappy')
    else:
        df.to_csv(filepath, index=False)
    
    size_mb = filepath.stat().st_size / (1024 * 1024)
    print(f"   💾 {filepath.name}: {len(df):,} records ({size_mb:.1f} MB)")


if __name__ == "__main__":
    main()