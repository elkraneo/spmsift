#!/bin/bash

TEST_STRING="├── swift-argument-parser<https://github.com/apple/swift-argument-parser@1.6.2>"

echo "Original: $TEST_STRING"
echo "Cleaned: $(echo "$TEST_STRING" | sed 's/^[├│└─ ]*//')"

# Test the regex
CLEANED="$(echo "$TEST_STRING" | sed 's/^[├│└─ ]*//')"
if [[ "$CLEANED" =~ (.*)\<(.+)\> ]]; then
    echo "Name: ${BASH_REMATCH[1]}"
    echo "URL+Version: ${BASH_REMATCH[2]}"
else
    echo "No match found"
fi