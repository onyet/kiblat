#!/bin/bash

# Script to load environment variables from .env file
# and generate configuration files for iOS build

ENV_FILE="${SRCROOT}/../../.env"
OUTPUT_FILE="${SRCROOT}/Runner/GeneratedConfig.swift"

# Default empty values
GOOGLE_API_KEY=""

# Read .env file if exists
if [ -f "$ENV_FILE" ]; then
    while IFS='=' read -r key value; do
        # Skip empty lines and comments
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        # Remove leading/trailing whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        
        case "$key" in
            GOOGLE_API_KEY)
                GOOGLE_API_KEY="$value"
                ;;
        esac
    done < "$ENV_FILE"
fi

# Generate Swift config file
cat > "$OUTPUT_FILE" << EOF
// Auto-generated file. Do not edit manually.
// Generated from .env file during build.

import Foundation

struct GeneratedConfig {
    static let googleApiKey = "$GOOGLE_API_KEY"
}
EOF

echo "Generated config file at $OUTPUT_FILE"
