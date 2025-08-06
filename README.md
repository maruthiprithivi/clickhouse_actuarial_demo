# ClickHouse Actuarial Demo

**Transform month-end marathons into coffee break conversations.**

## Quick Start

```bash
# 0. Clone the repository and install dependencies
git clone https://github.com/maruthiprithivi/clickhouse_actuarial_demo.git
cd clickhouse_actuarial_demo
pip install -r requirements.txt

# 1. Generate sample data
python data_generators/generate_all.py --scale sample

# 2. Start ClickHouse
docker-compose up -d

# 3. Load data
python scripts/load_data.py --table all

# 4. Run demos
python scripts/run_demo.py --scenario all
```

**Done!** Access ClickHouse at http://localhost:8123/play

## What This Demonstrates

### Speed That Changes Everything

- **Loss Triangles**: 5M claims → triangles in 0.3 seconds
- **Month-End Close**: Complete reserve analysis in 15 minutes
- **Catastrophe Response**: Real-time exposure analysis in 90 seconds
- **IFRS 17 Reporting**: Complex CSM calculations in 30 minutes

## Demo Scenarios

### 1. Loss Development Triangles

```sql
-- Build triangles using ClickHouse array functions
SELECT
    accident_year,
    groupArray(cumulative_paid) as paid_triangle,
    arrayDifference(groupArray(cumulative_paid)) as incremental_paid
FROM claims
GROUP BY accident_year;
```

**Showcases**: Array functions, real-time triangle construction, development factors

### 2. Mortality Analysis

```sql
-- Real-time mortality experience by demographics
SELECT
    age_band, customer_gender,
    count() as exposure,
    sum(simulated_deaths) / sum(expected_deaths) as actual_to_expected_ratio
FROM mortality_experience
GROUP BY age_band, customer_gender;
```

**Showcases**: Window functions, time series analysis, demographic pivoting

### 3. Reserve Calculations

```sql
-- Real-time reserve adequacy across all lines
SELECT
    line_of_business,
    sum(outstanding_reserve) as total_reserves,
    quantile(0.95)(outstanding_reserve) as p95_reserve
FROM claims
WHERE claim_status IN ('Open', 'Reserved')
GROUP BY line_of_business;
```

**Showcases**: Statistical functions, materialized views, real-time aggregation

### 4. IFRS 17 CSM Calculations

```sql
-- Complex CSM calculations with JSON metadata
SELECT
    line_of_business,
    sum(initial_csm) as total_csm,
    JSONExtractFloat(reserve_metadata, 'discount_rate') as discount_rate
FROM reserves
WHERE profitability_class = 'Profitable'
GROUP BY line_of_business;
```

**Showcases**: JSON functions, complex financial calculations, regulatory compliance

### 5. Catastrophe Response

```sql
-- Sub-second catastrophe exposure analysis
SELECT
    geography,
    sum(sum_insured) as total_exposure
FROM policies
WHERE geography IN ('FL', 'TX', 'LA')  -- Hurricane-prone states
  AND line_of_business IN ('Motor', 'Property')
GROUP BY geography;
```

**Showcases**: Real-time analytics, geographic analysis, emergency response speed

## Architecture

### Data Layer

- **ClickHouse v25.6**: Latest columnar database
- **Sample Data**: 1M policies, 5M claims, realistic patterns
- **Optimized Schema**: Partitioned by date, ordered for analytics

### Performance Features

- **Array Functions**: Native triangle calculations
- **Materialized Views**: Pre-aggregated month-end reports
- **Projections**: Query-specific optimizations
- **JSON Support**: Complex actuarial calculations
- **S3 Integration**: Direct cloud data access

### Query Patterns

- **Sub-second Aggregations**: Million-record summaries
- **Real-time Joins**: Policy-claim relationships
- **Statistical Functions**: Quantiles, standard deviations
- **Time Series**: Development patterns, trend analysis

## Setup Options

### Local Development

```bash
# Basic setup
docker-compose up -d
python scripts/load_data.py

# Custom data scale
python data_generators/generate_all.py --scale medium  # 10M records
python data_generators/generate_all.py --scale full    # 100M+ records
```

### Cloud Integration (S3)

```bash
# Upload data to S3
python scripts/s3_upload.py --bucket your-actuarial-bucket

# Load from S3
python scripts/load_data.py --source s3
```

### Environment Configuration

```bash
# Copy and customize
cp .env.example .env
# Edit connection settings, data scales, etc.
```

## Demo Execution

### Individual Scenarios

```bash
python scripts/run_demo.py --scenario loss_triangles      # Array functions
python scripts/run_demo.py --scenario mortality_analysis  # Demographics
python scripts/run_demo.py --scenario reserve_calculations # Aggregations
python scripts/run_demo.py --scenario ifrs17_csm         # JSON handling
python scripts/run_demo.py --scenario catastrophe_response # Real-time
```

### Performance Testing

```bash
python scripts/run_demo.py --scenario all --verbose  # Show all query times
```

### Manual SQL Execution

```sql
-- Copy any query from sql/03_demo_queries/
-- Paste into http://localhost:8123/play (for local development) OR Use ClickHouse Cloud - SQL Console (during hands-on workshop)
-- Execute instantly
```

## File Organization

```
clickhouse-actuarial-demo/
├── data_generators/          # Realistic data generation
│   ├── generate_all.py      # One-command generation
│   ├── policies.py          # Insurance policies
│   ├── claims.py            # Loss development patterns
│   └── reserves.py          # IFRS 17 reserves
│
├── sql/                     # Clean SQL organization
│   ├── 01_create_schema/    # Database structure
│   ├── 02_load_data/        # Local and S3 loading
│   └── 03_demo_queries/     # Performance showcases
│
├── scripts/                 # Simple orchestration
│   ├── load_data.py         # Data loading
│   ├── run_demo.py          # Query execution
│   └── s3_upload.py         # Cloud utilities
│
└── config/                  # ClickHouse optimization (for local development only, when using ClickHouse Cloud for hands-on workshop ignore this folder)
```

## ClickHouse Advantages

### Speed

- **Columnar Storage**: Analytical queries 10-100x faster
- **Vectorized Execution**: Process millions of rows simultaneously
- **Compression**: 10:1 storage efficiency vs traditional databases

### Functionality

- **Array Functions**: Native actuarial calculations
- **JSON Support**: Complex policy structures
- **Window Functions**: Development factor analysis
- **Statistical Functions**: Built-in quantiles, aggregations

### Scalability

- **Linear Scaling**: Performance grows with hardware
- **Real-time Inserts**: Streaming claim updates
- **Distributed Queries**: Multi-server deployments

### Usability

- **Standard SQL**: Familiar syntax with powerful extensions
- **Web Interface**: Built-in query editor and visualization
- **Client Libraries**: Python, Java, Go, and more

## Business Impact

### For Executives

- **Decision Speed**: Real-time insights vs days of waiting
- **Competitive Advantage**: React to market changes instantly
- **Cost Reduction**: Automate manual processes
- **Risk Management**: Early warning systems

### For Actuaries

- **Productivity**: Focus on analysis, not data processing
- **Accuracy**: Eliminate manual calculation errors
- **Flexibility**: Ad-hoc analysis without IT support
- **Innovation**: Enable new analytical approaches

### For IT Teams

- **Simplicity**: Single database for all analytical needs
- **Reliability**: Built-in redundancy and failover
- **Maintainability**: No complex ETL pipelines
- **Cost Efficiency**: Commodity hardware scaling

## Quick Help

```bash
# Connection issues
python scripts/load_data.py --verbose

# Performance testing
python scripts/run_demo.py --scenario all --verbose

# Data regeneration
python data_generators/generate_all.py --scale sample
```

### Resources

- **SQL Files**: Copy-paste ready for any ClickHouse client
- **Configuration**: Simple .env file customization
- **Troubleshooting**: All scripts include error handling
