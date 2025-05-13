#!/bin/bash

SUMMARY_FILE="summary.txt"

# Checking dependencies
check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: $1 is not installed. Please install $1 first."
        exit 1
    fi
}

check_dependency jq
check_dependency sqlmap

# Load environment variables from .env
load_env() {
    if [ -f .env ]; then
        while IFS= read -r line; do
            if [[ $line =~ ^[^#]*= ]]; then
                key=$(cut -d= -f1 <<< "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                value=$(cut -d= -f2- <<< "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                if [[ "$value" =~ ^\"(.*)\"$ ]]; then
                    value="${BASH_REMATCH[1]}"
                elif [[ "$value" =~ ^\'(.*)\'$ ]]; then
                    value="${BASH_REMATCH[1]}"
                fi
                export "$key"="$value"
            fi
        done < .env
    else
        echo "Missing .env file bro :v"
        exit 1
    fi
}

load_env

# JSON file path
JSON_FILE="testing_apis.json"

if [ ! -f "$JSON_FILE" ]; then
    echo "Error: $JSON_FILE not found."
    exit 1
fi

# Remove old summary file if it exists
if [ -f "$SUMMARY_FILE" ]; then
    rm -f "$SUMMARY_FILE"
fi

# Create logs directory
if [ -d "logs" ]; then
    rm -rf logs
fi

mkdir -p logs
echo "SQL Injection Summary Report" > "$SUMMARY_FILE"
echo "============================" >> "$SUMMARY_FILE"

replace_env_vars() {
    local input="$1"
    while [[ $input =~ (\$\{([a-zA-Z_][a-zA-Z_0-9]*)\}) ]]; do
        local var_name="${BASH_REMATCH[2]}"
        local var_value="${!var_name}"
        input="${input//${BASH_REMATCH[1]}/$var_value}"
    done
    echo "$input"
}

apis=$(jq -c '.apis[]' "$JSON_FILE")
index=0

while IFS= read -r api; do
    endpoint=$(echo "$api" | jq -r '.endpoint')
    method=$(echo "$api" | jq -r '.method')

    headers=()
    while IFS= read -r line; do
        headers+=("$line")
    done < <(echo "$api" | jq -r '.headers[]? // empty')

    cmd="sqlmap -u \"$endpoint\" --method=\"$method\""

    for header in "${headers[@]}"; do
        processed_header=$(replace_env_vars "$header")
        cmd+=" --header=\"$processed_header\""
    done

    # UPDATED body block
    raw_body=$(echo "$api" | jq '.body?')
    if [ "$raw_body" != "null" ] && [ -n "$raw_body" ]; then
        compact_body=$(jq -c . <<< "$raw_body")
        processed_body=$(replace_env_vars "$compact_body")
        processed_body_escaped=$(sed "s/'/'\\\\''/g" <<< "$processed_body")
        cmd+=" --data='$processed_body_escaped'"
    fi

    cmd+=" --batch --dbms=\"$SQLMAP_DBMS\" --level=$SQLMAP_LEVEL --risk=$SQLMAP_RISK"

    log_file="logs/endpoint_${index}.log"
    echo "Running command for endpoint: $endpoint (index $index)"
    echo "Command: $cmd" > "$log_file"
    eval "$cmd" >> "$log_file" 2>&1

    # Analyze the log file for SQL vulnerability
    if grep -qi "is vulnerable" "$log_file"; then
        echo "- [$endpoint] (index $index): Vulnerable to SQLi" >> "$SUMMARY_FILE"
        echo "  ↳ Log: $log_file" >> "$SUMMARY_FILE"
    else
        echo "- [$endpoint] (index $index): No SQLi found" >> "$SUMMARY_FILE"
        echo "  ↳ Log: $log_file" >> "$SUMMARY_FILE"
    fi

    index=$((index + 1))
done <<< "$apis"

echo "Finished testing. See summary in $SUMMARY_FILE"
