#!/usr/bin/env python3
"""
ClickHouse Actuarial Demo - Data Loader
Simple script to load data using SQL files
"""

import os
import sys
import argparse
import time
from pathlib import Path
import clickhouse_connect
from dotenv import load_dotenv

# Load environment variables
load_dotenv()


def get_client():
    """Create ClickHouse client from environment variables"""
    return clickhouse_connect.get_client(
        host=os.getenv('CLICKHOUSE_HOST', 'localhost'),
        port=int(os.getenv('CLICKHOUSE_PORT', 8123)),
        username=os.getenv('CLICKHOUSE_USER', 'demo'),
        password=os.getenv('CLICKHOUSE_PASSWORD', 'demo123'),
        database=os.getenv('CLICKHOUSE_DATABASE', 'actuarial')
    )


def execute_sql_file(client, sql_file, verbose=False):
    """Execute a SQL file"""
    try:
        with open(sql_file, 'r') as f:
            sql_content = f.read()
        
        # Split by semicolon and execute each statement
        statements = [stmt.strip() for stmt in sql_content.split(';') if stmt.strip()]
        
        for i, statement in enumerate(statements):
            if statement.strip():
                if verbose:
                    print(f"   Executing statement {i+1}/{len(statements)}...")
                client.command(statement)
        
        return True
        
    except Exception as e:
        print(f"❌ Error executing {sql_file}: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(description='Load data into ClickHouse')
    parser.add_argument('--source', choices=['local', 's3'], default='local',
                       help='Data source: local files or S3')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Verbose output')
    parser.add_argument('--table', choices=['policies', 'claims', 'reserves', 'all'],
                       default='all', help='Which table(s) to load')
    
    args = parser.parse_args()
    
    print(f"🔄 Loading data from {args.source} source...")
    
    # Test connection
    try:
        client = get_client()
        client.ping()
        print("✅ Connected to ClickHouse")
    except Exception as e:
        print(f"❌ Cannot connect to ClickHouse: {e}")
        sys.exit(1)
    
    # Determine which SQL files to run
    sql_dir = Path('sql/02_load_data')
    
    if args.source == 's3':
        sql_files = [sql_dir / 'load_from_s3.sql']
    else:
        if args.table == 'all':
            sql_files = [
                sql_dir / 'load_policies.sql',
                sql_dir / 'load_claims.sql', 
                sql_dir / 'load_reserves.sql'
            ]
        else:
            sql_files = [sql_dir / f'load_{args.table}.sql']
    
    # Execute SQL files
    total_start = time.time()
    success_count = 0
    
    for sql_file in sql_files:
        if not sql_file.exists():
            print(f"⚠️  SQL file not found: {sql_file}")
            continue
            
        print(f"\n📄 Executing {sql_file.name}...")
        start_time = time.time()
        
        if execute_sql_file(client, sql_file, args.verbose):
            elapsed = time.time() - start_time
            print(f"✅ {sql_file.name} completed in {elapsed:.1f} seconds")
            success_count += 1
        else:
            print(f"❌ {sql_file.name} failed")
    
    total_elapsed = time.time() - total_start
    
    print(f"\n📊 Load Summary:")
    print(f"   ✅ {success_count}/{len(sql_files)} files executed successfully")
    print(f"   ⏱️  Total time: {total_elapsed:.1f} seconds")
    
    # Verify data loaded
    try:
        print(f"\n📈 Data Verification:")
        
        # Check each table
        tables = ['policies', 'claims', 'reserves']
        for table in tables:
            try:
                result = client.query(f"SELECT count() FROM {table}")
                count = result.result_rows[0][0] if result.result_rows else 0
                print(f"   📋 {table}: {count:,} records")
            except:
                print(f"   📋 {table}: Not loaded or accessible")
                
    except Exception as e:
        print(f"⚠️  Could not verify data: {e}")


if __name__ == "__main__":
    main()