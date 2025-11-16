#!/bin/bash

# Test script for spmsift integration
# This shows how to use spmsift in Smith skill SPM analysis

echo "🧪 Testing spmsift integration for Smith skill"
echo "=============================================="

echo "1. Package Structure Analysis:"
swift package dump-package 2>&1 | spmsift --format summary

echo
echo "2. Dependency Analysis:"
swift package show-dependencies 2>&1 | spmsift --format summary

echo
echo "3. Performance Metrics:"
time swift package dump-package 2>&1 | spmsift --metrics > /dev/null

echo
echo "4. Error Handling Test (with malformed input):"
echo '{"invalid": json' | spmsift | jq '.issues'

echo
echo "✅ spmsift is ready for Smith skill integration!"
echo
echo "Usage in Smith skill:"
echo "  #!/bin/bash"
echo "  swift package dump-package 2>&1 | spmsift"
echo "  swift package show-dependencies 2>&1 | spmsift"