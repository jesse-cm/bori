#!/bin/zsh
# Assembles dist/Bori.app from the SwiftPM build.
# Run the app from the bundle — that way the Automation permission
# dialog (Apple Events for Chrome/Safari, raised on the first sweep)
# is attributed to Bori rather than your terminal.
set -euo pipefail
cd "$(dirname "$0")/.."

# theme.css and bori-screen.js at the repo root are canonical;
# sync them into the target's resources before building.
cp theme.css bori-screen.js Sources/BoriApp/Resources/

swift build -c release

APP=dist/Bori.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Library/LaunchDaemons"

cp .build/release/Bori "$APP/Contents/MacOS/Bori"
cp .build/release/BoriHelper "$APP/Contents/MacOS/BoriHelper"
cp -R .build/release/Bori_BoriApp.bundle "$APP/Contents/Resources/"

# The privileged helper: launchd starts Contents/MacOS/BoriHelper as
# root on demand, once the user has approved it in Login Items.
cat > "$APP/Contents/Library/LaunchDaemons/app.bori.helper.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>app.bori.helper</string>
	<key>BundleProgram</key>
	<string>Contents/MacOS/BoriHelper</string>
	<key>MachServices</key>
	<dict>
		<key>app.bori.helper</key>
		<true/>
	</dict>
	<key>AssociatedBundleIdentifiers</key>
	<array>
		<string>app.bori.mac</string>
	</array>
</dict>
</plist>
PLIST

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>Bori</string>
	<key>CFBundleIdentifier</key>
	<string>app.bori.mac</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Bori</string>
	<key>CFBundleDisplayName</key>
	<string>Bori</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>NSAppleEventsUsageDescription</key>
	<string>Bori asks Chrome and Safari for their open tabs so it can shelve them when a session begins.</string>
	<key>NSHumanReadableCopyright</key>
	<string>MIT</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP/Contents/MacOS/BoriHelper"
codesign --force --sign - "$APP"
echo "built $APP — launch with: open $APP"
