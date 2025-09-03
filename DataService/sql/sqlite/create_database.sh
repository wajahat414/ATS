#!/bin/sh
# Usage: ./create_database.sh [db_path]
DB="${1:-distributed_ats.db}"

sqlite3 "$DB" <<'EOF'
PRAGMA foreign_keys = OFF;

BEGIN IMMEDIATE;

-- Drop dependent tables first (FK-safe order)
DROP TABLE IF EXISTS instrument_market_map;
DROP TABLE IF EXISTS user_group_market_map;
DROP TABLE IF EXISTS hist_price;
DROP TABLE IF EXISTS user_code;
DROP TABLE IF EXISTS instrument;
DROP TABLE IF EXISTS market;
DROP TABLE IF EXISTS user_group;

COMMIT;

PRAGMA foreign_keys = ON;

BEGIN IMMEDIATE;

-- Fresh schema
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS user_group (
  user_group text PRIMARY KEY,
  properties json,
  last_update_time timestamp default CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS user_code (
  user_name text PRIMARY KEY,
  user_group text,
  properties json,
  last_update_time timestamp default CURRENT_TIMESTAMP,
  FOREIGN KEY(user_group) REFERENCES user_group(user_group)
);

CREATE TABLE IF NOT EXISTS instrument (
  instrument_name text PRIMARY KEY,
  properties json,
  last_update_time timestamp default CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS hist_price (
  instrument_name text,
  business_date integer,
  properties json,
  last_update_time timestamp default CURRENT_TIMESTAMP,
  UNIQUE(instrument_name, business_date)
);

CREATE TABLE IF NOT EXISTS market (
  market_name text PRIMARY KEY,
  properties json,
  last_update_time timestamp default CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS instrument_market_map (
  instrument_name text,
  market_name text,
  last_update_time timestamp default CURRENT_TIMESTAMP,
  FOREIGN KEY(instrument_name) REFERENCES instrument(instrument_name),
  FOREIGN KEY(market_name) REFERENCES market(market_name),
  UNIQUE(instrument_name, market_name)
);

CREATE TABLE IF NOT EXISTS user_group_market_map (
  user_group text,
  market_name text,
  last_update_time timestamp default CURRENT_TIMESTAMP,
  FOREIGN KEY(user_group) REFERENCES user_group(user_group),
  FOREIGN KEY(market_name) REFERENCES market(market_name),
  UNIQUE(user_group, market_name)
);

COMMIT;

-- Optional: reclaim space after drops
VACUUM;
EOF
