-- ClickHouse Actuarial Demo - Database Creation
-- Creates the main database and sets up basic configuration

CREATE DATABASE IF NOT EXISTS actuarial
COMMENT 'ClickHouse Actuarial Analytics Database';

-- Use the database for subsequent operations
USE actuarial;

-- Create user for demo (if not using docker environment variables)
-- This will be handled by docker-compose environment variables instead

SHOW DATABASES;