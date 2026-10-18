#!/bin/bash

# Legacy script kept for Xcode build phases. Google Maps is no longer used;
# emits a minimal GeneratedConfig.swift so the build phase stays harmless.

OUTPUT_FILE="${SRCROOT}/Runner/GeneratedConfig.swift"

cat > "$OUTPUT_FILE" << 'EOF'
// Auto-generated file. Do not edit manually.

import Foundation

struct GeneratedConfig {}
EOF

echo "Generated config file at $OUTPUT_FILE"
