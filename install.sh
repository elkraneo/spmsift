#!/bin/bash

# spmsift Installation Script
# Installs spmsift to /usr/local/bin or specified directory

set -e

INSTALL_DIR="${1:-/usr/local/bin}"
REPO_URL="https://github.com/your-username/spmsift.git"
TEMP_DIR=$(mktemp -d)

echo "🚀 Installing spmsift..."

# Check if Swift is available
if ! command -v swift &> /dev/null; then
    echo "❌ Error: Swift is not installed. Please install Xcode or Swift toolchain."
    exit 1
fi

# Create install directory if it doesn't exist
if [ ! -d "$INSTALL_DIR" ]; then
    echo "📁 Creating install directory: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
fi

# Check if we have write permissions
if [ ! -w "$INSTALL_DIR" ]; then
    echo "❌ Error: No write permissions to $INSTALL_DIR"
    echo "💡 Try running with sudo or specify a different directory:"
    echo "   sudo ./install.sh"
    echo "   ./install.sh ~/.local/bin"
    exit 1
fi

# Clone and build
echo "📥 Cloning repository..."
git clone "$REPO_URL" "$TEMP_DIR/spmsift"

cd "$TEMP_DIR/spmsift"

echo "🔨 Building spmsift..."
swift build -c release --product spmsift

echo "📦 Installing to $INSTALL_DIR..."
cp ".build/release/spmsift" "$INSTALL_DIR/spmsift"

# Cleanup
echo "🧹 Cleaning up..."
rm -rf "$TEMP_DIR"

# Verify installation
if command -v spmsift &> /dev/null; then
    echo "✅ spmsift installed successfully!"
    echo ""
    echo "🎉 Usage:"
    echo "   swift package dump-package | spmsift"
    echo "   swift package show-dependencies | spmsift --format summary"
    echo ""
    echo "📖 For more information: spmsift --help"
else
    echo "❌ Installation verification failed"
    echo "💡 Make sure $INSTALL_DIR is in your PATH"
    exit 1
fi