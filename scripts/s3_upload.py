#!/usr/bin/env python3
"""
ClickHouse Actuarial Demo - S3 Upload Utility
Optional utility to upload generated data to S3 for cloud workflows
"""

import os
import sys
import argparse
from pathlib import Path
import boto3
from botocore.exceptions import ClientError, NoCredentialsError
from tqdm import tqdm
from dotenv import load_dotenv

# Load environment variables
load_dotenv()


def get_s3_client():
    """Create S3 client from environment variables"""
    try:
        return boto3.client(
            's3',
            aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID'),
            aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY'),
            region_name=os.getenv('AWS_REGION', 'us-east-1')
        )
    except NoCredentialsError:
        print("❌ AWS credentials not found. Please set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY")
        return None


def upload_file(s3_client, file_path, bucket, s3_key):
    """Upload a file to S3 with progress bar"""
    try:
        file_size = file_path.stat().st_size
        
        with tqdm(total=file_size, unit='B', unit_scale=True, desc=file_path.name) as pbar:
            def upload_callback(bytes_transferred):
                pbar.update(bytes_transferred)
            
            s3_client.upload_file(
                str(file_path), 
                bucket, 
                s3_key,
                Callback=upload_callback
            )
        
        return True
        
    except ClientError as e:
        print(f"❌ Failed to upload {file_path.name}: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(description='Upload actuarial demo data to S3')
    parser.add_argument('--bucket', required=True, help='S3 bucket name')
    parser.add_argument('--prefix', default='actuarial-demo/', help='S3 key prefix')
    parser.add_argument('--data-dir', default='data', help='Local data directory')
    parser.add_argument('--format', choices=['parquet', 'csv'], default='parquet',
                       help='File format to upload')
    
    args = parser.parse_args()
    
    print(f"🔄 Uploading actuarial demo data to S3...")
    print(f"   Bucket: {args.bucket}")
    print(f"   Prefix: {args.prefix}")
    print(f"   Format: {args.format}")
    
    # Initialize S3 client
    s3_client = get_s3_client()
    if not s3_client:
        sys.exit(1)
    
    # Check if bucket exists
    try:
        s3_client.head_bucket(Bucket=args.bucket)
        print(f"✅ Bucket {args.bucket} is accessible")
    except ClientError as e:
        print(f"❌ Cannot access bucket {args.bucket}: {e}")
        sys.exit(1)
    
    # Find data files to upload
    data_dir = Path(args.data_dir)
    if not data_dir.exists():
        print(f"❌ Data directory not found: {data_dir}")
        print("   Run data generation first: python data_generators/generate_all.py")
        sys.exit(1)
    
    # File patterns to upload
    file_patterns = [
        f'policies.{args.format}',
        f'claims.{args.format}', 
        f'reserves.{args.format}'
    ]
    
    files_to_upload = []
    for pattern in file_patterns:
        file_path = data_dir / pattern
        if file_path.exists():
            files_to_upload.append(file_path)
        else:
            print(f"⚠️  File not found: {file_path}")
    
    if not files_to_upload:
        print("❌ No data files found to upload")
        sys.exit(1)
    
    # Upload files
    print(f"\n📤 Uploading {len(files_to_upload)} files...")
    
    success_count = 0
    total_size = 0
    
    for file_path in files_to_upload:
        s3_key = f"{args.prefix}{file_path.name}"
        file_size = file_path.stat().st_size
        
        print(f"\n📄 Uploading {file_path.name} ({file_size / 1024 / 1024:.1f} MB)...")
        
        if upload_file(s3_client, file_path, args.bucket, s3_key):
            print(f"✅ Uploaded to s3://{args.bucket}/{s3_key}")
            success_count += 1
            total_size += file_size
        else:
            print(f"❌ Failed to upload {file_path.name}")
    
    # Summary
    print(f"\n📊 Upload Summary:")
    print(f"   ✅ {success_count}/{len(files_to_upload)} files uploaded successfully")
    print(f"   💾 Total size: {total_size / 1024 / 1024:.1f} MB")
    
    if success_count > 0:
        print(f"\n📋 S3 URLs:")
        for file_path in files_to_upload[:success_count]:
            s3_key = f"{args.prefix}{file_path.name}"
            print(f"   s3://{args.bucket}/{s3_key}")
        
        print(f"\n💡 To use S3 data in ClickHouse:")
        print(f"   1. Update sql/02_load_data/load_from_s3.sql with your bucket details")
        print(f"   2. Run: python scripts/load_data.py --source s3")
    
    print(f"\n🔗 Next steps:")
    print(f"   • Test S3 loading: python scripts/load_data.py --source s3")
    print(f"   • Run demos: python scripts/run_demo.py --scenario all")


if __name__ == "__main__":
    main()