#!/bin/bash

# Track It - Project Setup Script
# This script helps configure the Xcode project settings for Phase 1

set -e

echo "🚀 Track It - Project Setup"
echo "================================"
echo ""

# Check if we're in the correct directory
if [ ! -d "Track it.xcodeproj" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    exit 1
fi

echo "✅ Working directory: $(pwd)"
echo ""

# Step 1: Verify project structure
echo "📁 Verifying project structure..."
if [ -d "Track it" ]; then
    echo "   ✅ Track it directory exists"
else
    echo "   ❌ Track it directory not found"
    exit 1
fi

echo ""
echo "📋 Project Setup Checklist:"
echo "================================"
echo ""

# Step 2: Check for Xcode
echo "🔧 Checking for Xcode..."
if xcode-select -p &>/dev/null; then
    XCODE_PATH=$(xcode-select -p)
    echo "   ✅ Xcode found at: $XCODE_PATH"
else
    echo "   ⚠️  Xcode not configured. Please install Xcode and run:"
    echo "       xcode-select --install"
fi

echo ""
echo "📝 Manual Configuration Required:"
echo "================================"
echo ""
echo "The following must be configured in Xcode:"
echo ""
echo "1. PROJECT SETTINGS:"
echo "   - Bundle Identifier: com.arvoldek.TrackIt"
echo "   - Display Name: Track It"
echo "   - Version: 1.0.0"
echo "   - Build: 1"
echo "   - Minimum Deployment: iOS 17.0"
echo "   - Devices: Universal (iPhone and iPad)"
echo ""
echo "2. CAPABILITIES (Signing & Capabilities tab):"
echo "   ✓ iCloud"
echo "     - Services: CloudKit"
echo "     - Containers: iCloud.com.arvoldek.TrackIt"
echo "   ✓ Background Modes"
echo "     - Remote notifications"
echo "   ✓ User Notifications"
echo "   ✓ Keychain Sharing"
echo ""
echo "3. BUILD SETTINGS:"
echo "   - Swift Language Version: Latest stable"
echo "   - Optimization Level:"
echo "     * Debug: None [-Onone]"
echo "     * Release: Fast, Single-File Optimization [-O]"
echo "   - Debug Information Format: DWARF with dSYM File"
echo "   - Enable Testability: YES"
echo "   - Code Coverage: Enable for Debug"
echo "   - Dead Code Stripping: NO (for better debugging)"
echo ""
echo "4. INFO.PLIST:"
echo "   The Info.plist file has been created with all required keys."
echo "   Xcode should automatically use it."
echo ""
echo "5. CONFIGURATION FILES:"
echo "   Created: App.xcconfig, Debug.xcconfig, Release.xcconfig"
echo "   To use these in Xcode:"
echo "   - Go to Project > Info"
echo "   - Under Configurations, set Debug and Release to use the xcconfig files"
echo ""
echo "6. FILE REFERENCES:"
echo "   The following files have been created and should be added to Xcode:"
echo ""

# List all created files
created_files=(
    "Track it/Application/TrackItApp.swift"
    "Track it/Data/CoreData/Persistence.swift"
    "Track it/Presentation/Views/ContentView.swift"
    "Track it/Presentation/Views/LaunchScreen.swift"
    "Track it/Utilities/Constants/BuildConfig.swift"
    "Track it/Info.plist"
    "Track it/App.xcconfig"
    "Track it/Debug.xcconfig"
    "Track it/Release.xcconfig"
)

for file in "${created_files[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✅ $file"
    else
        echo "   ❌ $file (missing)"
    fi
done

echo ""
echo "7. ASSET CATALOG:"
echo "   Color sets created:"
echo "   - LaunchBackground"
echo "   - LaunchText"
echo "   - LaunchIcon"
echo "   - AccentColor (existing)"
echo "   - AppIcon (updated with all sizes)"
echo ""
echo "8. DIRECTORY STRUCTURE:"
echo "   All required directories have been created:"
echo "   - Application/"
echo "   - Presentation/{Views,ViewModels,Coordinators,Components}"
echo "   - Domain/{Entities,UseCases,Repositories}"
echo "   - Data/{CoreData/{Models,Migrations},CloudKit,Local,Repositories}"
echo "   - Services/"
echo "   - Utilities/{Extensions,Helpers,Constants}"
echo "   - Resources/"
echo ""

echo "🎯 Next Steps:"
echo "================================"
echo ""
echo "1. Open Track it.xcodeproj in Xcode"
echo "2. Configure project settings as listed above"
echo "3. Enable the required capabilities"
echo "4. Add the Info.plist file to the project"
echo "5. Add all new Swift files to the project"
echo "6. Configure the xcconfig files in Project > Info"
echo "7. Build and run (⌘B) to verify everything works"
echo ""
echo "✅ Setup script complete!"
echo ""
echo "Note: Some settings can only be configured through Xcode's GUI."
echo "This script has prepared all the files you need."
