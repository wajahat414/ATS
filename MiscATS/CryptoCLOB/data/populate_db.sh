#!/bin/sh

# Usage: ensure SQLITE_HOME points to sqlite install (or set to /usr)
# Example: export SQLITE_HOME="/opt/homebrew/opt/sqlite"
SQLITE_BIN="${SQLITE_HOME:-/usr}/bin/sqlite3"
DB_FILE="distributed_ats.db"

# Create empty DB file if missing
[ -f "$DB_FILE" ] || touch "$DB_FILE"

"$SQLITE_BIN" "$DB_FILE" <<'EOF'
PRAGMA foreign_keys = OFF;

BEGIN IMMEDIATE;

-- Truncate all data (FK-safe)
DELETE FROM instrument_market_map;
DELETE FROM user_group_market_map;
DELETE FROM hist_price;
DELETE FROM user_code;
DELETE FROM instrument;
DELETE FROM market;
DELETE FROM user_group;

COMMIT;

PRAGMA foreign_keys = ON;

BEGIN IMMEDIATE;

-- Seed data
-- User groups
REPLACE INTO user_group (user_group, properties) VALUES ('CRYPTO_TRADER_GROUP_A', '{}');
REPLACE INTO user_group (user_group, properties) VALUES ('CRYPTO_TRADER_GROUP_B', '{}');
REPLACE INTO user_group (user_group, properties) VALUES ('CRYPTO_TRADER_GROUP_C', '{}');
REPLACE INTO user_group (user_group, properties) VALUES ('MATCHING_MARKET_BTC', '{}');

-- Users
REPLACE INTO user_code (user_name, user_group, properties) VALUES ('CRYPTO_TRADER_1', 'CRYPTO_TRADER_GROUP_A', '{"name":"CRYPTO TRADER 1","type":"TRADER"}');
UPDATE user_code SET properties=json_set(properties, '$.password','TEST') WHERE user_name='CRYPTO_TRADER_1';

REPLACE INTO user_code (user_name, user_group, properties) VALUES ('CRYPTO_TRADER_2', 'CRYPTO_TRADER_GROUP_A', '{"name":"CRYPTO TRADER 2","type":"TRADER"}');
UPDATE user_code SET properties=json_set(properties, '$.password','TEST') WHERE user_name='CRYPTO_TRADER_2';

REPLACE INTO user_code (user_name, user_group, properties) VALUES ('CRYPTO_TRADER_3', 'CRYPTO_TRADER_GROUP_B', '{"name":"CRYPTO TRADER 3","type":"TRADER"}');
UPDATE user_code SET properties=json_set(properties, '$.password','TEST') WHERE user_name='CRYPTO_TRADER_3';

REPLACE INTO user_code (user_name, user_group, properties) VALUES ('CRYPTO_TRADER_4', 'CRYPTO_TRADER_GROUP_C', '{"name":"CRYPTO TRADER 4","type":"TRADER"}');
UPDATE user_code SET properties=json_set(properties, '$.password','TEST') WHERE user_name='CRYPTO_TRADER_4';

-- Matching engine identity for BTC market
REPLACE INTO user_code (user_name, user_group, properties) VALUES ('BTC_MARKET', 'MATCHING_MARKET_BTC', '{"name":"Matching Engine Market BTC","type":"MATCHING_ENGINE"}');

-- Markets
REPLACE INTO market (market_name, properties) VALUES ('BTC_MARKET', '{}');

-- Group-to-market permissions
REPLACE INTO user_group_market_map (user_group, market_name) VALUES ('CRYPTO_TRADER_GROUP_A','BTC_MARKET');
REPLACE INTO user_group_market_map (user_group, market_name) VALUES ('MATCHING_MARKET_BTC','BTC_MARKET');

-- Instruments
REPLACE INTO instrument (instrument_name, properties) VALUES ('BTC-USD', '{"type":"Crypto"}');

-- Instrument-to-market mapping
REPLACE INTO instrument_market_map (instrument_name, market_name) VALUES ('BTC-USD','BTC_MARKET');

-- Historical price (sample)
REPLACE INTO hist_price (instrument_name, business_date, properties) VALUES ('BTC-USD', 20210401, '{"open":10100,"low":10000,"high":20000,"last":15000,"volume":10000}');

COMMIT;

-- Optional compaction
VACUUM;
EOF
