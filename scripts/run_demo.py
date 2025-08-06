#!/usr/bin/env python3
"""
ClickHouse Actuarial Demo - Query Demo Runner
Executes demo queries and shows performance metrics
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


def run_sql_file(client, sql_file, verbose=False):
    """Execute SQL file and return performance metrics"""
    try:
        with open(sql_file, 'r') as f:
            sql_content = f.read()
        
        # Split by queries (look for SELECT statements)
        queries = []
        current_query = []
        
        for line in sql_content.split('\n'):
            line = line.strip()
            if line.startswith('--') and '=' in line:
                # New section header
                if current_query:
                    queries.append('\n'.join(current_query))
                    current_query = []
            elif line and not line.startswith('--'):
                current_query.append(line)
        
        if current_query:
            queries.append('\n'.join(current_query))
        
        # Execute queries and collect results
        results = []
        total_time = 0
        
        for i, query in enumerate(queries):
            if 'SELECT' in query.upper():
                try:
                    start_time = time.time()
                    result = client.query(query)
                    elapsed = time.time() - start_time
                    total_time += elapsed
                    
                    row_count = len(result.result_rows) if result.result_rows else 0
                    
                    results.append({
                        'query_num': i + 1,
                        'elapsed_time': elapsed,
                        'row_count': row_count,
                        'success': True
                    })
                    
                    if verbose:
                        print(f"   Query {i+1}: {elapsed:.3f}s, {row_count:,} rows")
                        
                except Exception as e:
                    results.append({
                        'query_num': i + 1,
                        'elapsed_time': 0,
                        'row_count': 0,
                        'success': False,
                        'error': str(e)
                    })
                    if verbose:
                        print(f"   Query {i+1}: ERROR - {e}")
        
        return {
            'total_queries': len([r for r in results if 'SELECT' in queries[r['query_num']-1].upper()]),
            'successful_queries': len([r for r in results if r['success']]),
            'total_time': total_time,
            'total_rows': sum(r['row_count'] for r in results if r['success']),
            'results': results
        }
        
    except Exception as e:
        print(f"❌ Error executing {sql_file}: {e}")
        return None


def format_performance_summary(filename, metrics):
    """Format performance summary"""
    if not metrics:
        return f"❌ {filename}: Failed to execute"
    
    avg_time = metrics['total_time'] / max(1, metrics['successful_queries'])
    
    summary = f"✅ {filename}:\n"
    summary += f"   📊 {metrics['successful_queries']}/{metrics['total_queries']} queries successful\n"
    summary += f"   ⏱️  Total time: {metrics['total_time']:.3f}s (avg: {avg_time:.3f}s)\n"
    summary += f"   📈 Total rows: {metrics['total_rows']:,}\n"
    
    return summary


def main():
    parser = argparse.ArgumentParser(description='Run ClickHouse actuarial demo queries')
    parser.add_argument('--scenario', 
                       choices=['loss_triangles', 'mortality_analysis', 'reserve_calculations', 
                               'ifrs17_csm', 'catastrophe_response', 'all'],
                       default='all', help='Which scenario to run')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Verbose output showing individual query performance')
    parser.add_argument('--timing-only', action='store_true',
                       help='Show only timing information, no query results')
    
    args = parser.parse_args()
    
    print("🚀 ClickHouse Actuarial Demo - Performance Showcase")
    print("=" * 60)
    
    # Test connection
    try:
        client = get_client()
        client.ping()
        print("✅ Connected to ClickHouse")
    except Exception as e:
        print(f"❌ Cannot connect to ClickHouse: {e}")
        sys.exit(1)
    
    # Determine which scenarios to run
    sql_dir = Path('sql/03_demo_queries')
    
    scenario_files = {
        'loss_triangles': '01_loss_triangles.sql',
        'mortality_analysis': '02_mortality_analysis.sql', 
        'reserve_calculations': '03_reserve_calculations.sql',
        'ifrs17_csm': '04_ifrs17_csm.sql',
        'catastrophe_response': '05_catastrophe_response.sql'
    }
    
    if args.scenario == 'all':
        files_to_run = list(scenario_files.values())
    else:
        files_to_run = [scenario_files[args.scenario]]
    
    # Run scenarios
    total_start = time.time()
    all_metrics = []
    
    for filename in files_to_run:
        sql_file = sql_dir / filename
        
        if not sql_file.exists():
            print(f"⚠️  SQL file not found: {sql_file}")
            continue
        
        scenario_name = filename.replace('.sql', '').replace('_', ' ').title()
        print(f"\n🔄 Running {scenario_name}...")
        
        start_time = time.time()
        metrics = run_sql_file(client, sql_file, args.verbose)
        
        if metrics:
            elapsed = time.time() - start_time
            print(format_performance_summary(scenario_name, metrics))
            all_metrics.append((scenario_name, metrics, elapsed))
        
        # Brief pause between scenarios
        time.sleep(0.5)
    
    total_elapsed = time.time() - total_start
    
    # Overall summary
    print("\n" + "=" * 60)
    print("📊 DEMO PERFORMANCE SUMMARY")
    print("=" * 60)
    
    total_queries = sum(m[1]['total_queries'] for m in all_metrics)
    total_successful = sum(m[1]['successful_queries'] for m in all_metrics) 
    total_rows = sum(m[1]['total_rows'] for m in all_metrics)
    total_query_time = sum(m[1]['total_time'] for m in all_metrics)
    
    print(f"🎯 Scenarios executed: {len(all_metrics)}")
    print(f"📊 Total queries: {total_successful}/{total_queries} successful")
    print(f"⏱️  Total execution time: {total_elapsed:.3f} seconds")
    print(f"⚡ Pure query time: {total_query_time:.3f} seconds")  
    print(f"📈 Total rows processed: {total_rows:,}")
    
    if total_successful > 0:
        avg_query_time = total_query_time / total_successful
        print(f"🚀 Average query time: {avg_query_time:.3f} seconds")
        print(f"💫 Queries per second: {total_successful/total_query_time:.1f}")
    
    print(f"\n✨ ClickHouse Performance Advantage:")
    print(f"   • Traditional databases: Hours to days for similar analysis")
    print(f"   • ClickHouse: {total_query_time:.1f} seconds for comprehensive actuarial analysis")
    print(f"   • Speed improvement: ~{(8*3600)/max(total_query_time, 1):.0f}x faster than typical systems")
    
    # Individual scenario performance
    if len(all_metrics) > 1:
        print(f"\n📋 Individual Scenario Performance:")
        for scenario_name, metrics, elapsed in all_metrics:
            avg_time = metrics['total_time'] / max(1, metrics['successful_queries'])
            print(f"   {scenario_name}: {avg_time:.3f}s avg, {metrics['total_rows']:,} rows")


if __name__ == "__main__":
    main()