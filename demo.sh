#!/bin/bash

# spmsift Demo Script
# Demonstrates spmsift functionality with various Swift Package Manager commands

set -e

echo "🎯 spmsift Demo - Context-Efficient Swift Package Manager Analysis"
echo "=================================================================="
echo

# Check if spmsift is available
if ! command -v spmsift &> /dev/null; then
    echo "❌ spmsift not found. Building from source..."
    swift build -c release --product spmsift
    SPMSIFT_CMD=".build/release/spmsift"
else
    SPMSIFT_CMD="spmsift"
fi

echo "✅ Using spmsift: $(which $SPMSIFT_CMD)"
echo

echo "1️⃣  Analyzing package structure (dump-package)"
echo "--------------------------------------------"
echo "📊 Full JSON output:"
swift package dump-package | $SPMSIFT_CMD | head -20
echo "   ... (truncated)"
echo
echo "📈 Summary output:"
swift package dump-package | $SPMSIFT_CMD --format summary
echo

echo "2️⃣  Analyzing dependencies (show-dependencies)"
echo "---------------------------------------------"
echo "📊 Full JSON output:"
swift package show-dependencies | $SPMSIFT_CMD | head -15
echo "   ... (truncated)"
echo
echo "📈 Summary output:"
swift package show-dependencies | $SPMSIFT_CMD --format summary
echo

echo "3️⃣  Performance metrics"
echo "----------------------"
echo "⏱️  Parse time with metrics:"
time swift package dump-package | $SPMSIFT_CMD --metrics | jq '.metrics'
echo

echo "4️⃣  Error handling"
echo "----------------"
echo "Testing with malformed input:"
echo '{"invalid": json' | $SPMSIFT_CMD | jq '.issues'
echo

echo "5️⃣  Context efficiency comparison"
echo "--------------------------------"
echo "📏 Original dump-package output size:"
ORIGINAL_SIZE=$(swift package dump-package | wc -c | tr -d ' ')
echo "   $ORIGINAL_SIZE bytes"
echo
echo "📏 spmsift summary output size:"
SPMSIFT_SIZE=$(swift package dump-package | $SPMSIFT_CMD --format summary | wc -c | tr -d ' ')
echo "   $SPMSIFT_SIZE bytes"
echo
echo "💾 Space savings: $(( (ORIGINAL_SIZE - SPMSIFT_SIZE) * 100 / ORIGINAL_SIZE ))%"
echo

echo "🎉 Demo complete! spmsift is working perfectly."
echo "💡 Add this to your Smith skill SPM analysis tools:"
echo
echo "   #!/bin/bash"
echo "   swift package dump-package 2>&1 | spmsift"
echo "   swift package show-dependencies 2>&1 | spmsift"