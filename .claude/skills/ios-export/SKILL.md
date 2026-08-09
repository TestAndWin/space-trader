---
name: ios-export
description: SpaceTrader für iPad exportieren (Godot iOS-Export + Xcode-Build + Install auf Gerät), inkl. der bekannten Stolperfallen. Use when exporting/building/installing the game on an iPad.
disable-model-invocation: true
---

# iOS / iPad Export

## Voraussetzungen (einmalig)
- Xcode mit iOS SDK installiert, Apple-ID in Xcode → Settings → Accounts
- iPad: Developer Mode an (Settings → Privacy & Security → Developer Mode)
- iPad per USB verbunden und vertraut
- Freier Apple-Developer-Account reicht (7-Tage-Limit, max 3 Apps)
- `export_presets.cfg`: `app_store_team_id` = echte 10-Zeichen Team-ID
  (`security find-identity -v -p codesigning`), `export_project_only=true`,
  `bundle_identifier=net.testandwin.space-trader`

## Ablauf

1. **Godot iOS-Export** in Unterverzeichnis (nicht in Projekt-Root):
   ```bash
   /Applications/Godot.app/Contents/MacOS/Godot --headless \
     --path /Users/michaelschlottmann/git/space-trader \
     --export-debug iOS ios-export/space-trader.xcodeproj
   ```

2. **Xcode-Build** auf das verbundene iPad (Geräte-ID via `xcrun devicectl list devices`):
   ```bash
   xcodebuild -project ios-export/space-trader.xcodeproj \
     -target space-trader -configuration Debug \
     -sdk iphoneos -arch arm64 -allowProvisioningUpdates \
     -destination 'id=<DEVICE_ID>' build
   ```
   Alternativ Xcode öffnen (`open ios-export/space-trader.xcodeproj`),
   "Automatically manage signing" + Personal Team setzen, iPad als Ziel, ⌘R.

## Bekannte Stolperfallen
- **`Undefined symbol: _main`**: Simulator statt echtem Gerät gewählt, oder
  `-ObjC -all_load` fehlt in OTHER_LDFLAGS.
- **`No profiles found`**: Provisioning-Profil muss das Zielgerät enthalten —
  "Automatically manage signing" / `-allowProvisioningUpdates` erzeugt es.
- Leere `libgodot.visionos.*.xcframework`-Ordner von Godot 4.7 → ignorieren.

## Generierte Dateien (nicht in git)
`*.xcodeproj`, `*.xcframework/`, `*.pck`, `PrivacyInfo.xcprivacy`,
`MoltenVK.xcframework/`, `build/`, App-Source-Ordner → in `.gitignore` oder nach Build löschen.
