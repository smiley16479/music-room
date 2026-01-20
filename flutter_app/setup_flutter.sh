#!/bin/bash
# Flutter Setup Script for Music Room
# This script initializes the Flutter pub dependencies

cd /home/ncoursol/Documents/music-room/flutter_app

echo "=== Music Room Flutter Setup ==="
echo ""
echo "Flutter SDK Location: /sgoinfre/goinfre/Perso/ncoursol/flutter_sdk"
echo "Working Directory: $(pwd)"
echo ""

# Source the updated environment
source /home/ncoursol/.zshrc

echo "Checking Flutter installation..."
which flutter

echo ""
echo "Getting dependencies..."
flutter pub get

echo ""
echo "Setup complete! You can now run:"
echo "  flutter run                  # For default platform"
echo "  flutter run -d chrome        # For web"
echo "  flutter run -d iphone        # For iOS"
