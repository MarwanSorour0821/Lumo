#!/bin/bash

# Setup script to copy assets from React Native project to iOS project

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
FRONTEND_DIR="$SCRIPT_DIR/../frontend"
IOS_DIR="$SCRIPT_DIR/Lumo/Lumo/Resources"

echo "Setting up iOS assets..."

# Create directories if they don't exist
mkdir -p "$IOS_DIR/Fonts"
mkdir -p "$IOS_DIR/Images.xcassets"

# Copy fonts
echo "Copying fonts..."
cp "$FRONTEND_DIR/assets/fonts/ProductSans/"*.ttf "$IOS_DIR/Fonts/"

# Copy images
echo "Copying images..."
cp "$FRONTEND_DIR/assets/images/Group 6.png" "$IOS_DIR/Images.xcassets/Group6.png" 2>/dev/null || echo "Note: Group 6.png - you'll need to add this manually to Xcode Assets"
cp "$FRONTEND_DIR/assets/images/iMockup - iPhone 14.png" "$IOS_DIR/Images.xcassets/iPhone14.png" 2>/dev/null || echo "Note: iPhone 14 image - you'll need to add this manually to Xcode Assets"

echo "Assets setup complete!"
echo ""
echo "IMPORTANT: You still need to:"
echo "1. Open the project in Xcode"
echo "2. Add the images to Images.xcassets (drag and drop Group6.png and iPhone14.png)"
echo "3. Ensure fonts are added to the Xcode project target"
echo "4. Create the Xcode project file if it doesn't exist"
