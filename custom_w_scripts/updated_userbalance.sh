#!/usr/bin/env bash

set -e

DB_PATH="../DistributedATS/MiscATS/CryptoCLOB/data/distributed_ats.db" 
OUTPUT_FILE="tables_info.txt"

list_all_tables() {
    echo "=== All Tables in Database: $DB_PATH ==="
    echo
    
    # Get list of tables
    TABLES=$(sqlite3 "$DB_PATH" ".tables")
    
    if [ -z "$TABLES" ]; then
        echo "No tables found in the database."
        return
    fi
    
    echo "Tables found:"
    echo "$TABLES" | tr ' ' '\n' | sort
    echo
}

show_sample_data() {
    echo "=== Sample Data (First 3 rows) ==="
    echo
    
    sqlite3 "$DB_PATH" ".tables" | tr ' ' '\n' | while read -r table; do
        if [ -n "$table" ]; then
            echo "--- Sample data from: $table ---"
            sqlite3 "$DB_PATH" -header -column "SELECT * FROM $table LIMIT 3;"
            echo
        fi
    done
}


main() {
    echo "SQLite3 Database Explorer"
    echo "========================="
    echo
    

    # Save output to file and display
    {
        list_all_tables
        show_sample_data
    } | tee "$OUTPUT_FILE"
    
    echo "Results saved to: $OUTPUT_FILE"
    echo
    
    # Ask if user wants interactive mode
    read -p "Do you want to start interactive SQLite3 session? (y/n): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        interactive_mode
    fi
}

main
