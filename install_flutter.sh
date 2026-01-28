#!/bin/bash
set -e

# ===============================
# CONFIG
# ===============================
SGOINFRE="$HOME/sgoinfre"

FLUTTER_DIR="$SGOINFRE/flutter"
ANDROID_SDK="$SGOINFRE/android-sdk"
ANDROID_AVD="$SGOINFRE/android-avd"
TMP="$SGOINFRE/tmp"

CMDLINE_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"

API_LEVEL=34
IMAGE="system-images;android-$API_LEVEL;google_apis;x86_64"
DEVICE="pixel"

# ===============================
# PREP DIRS
# ===============================
echo "📁 Création des dossiers..."
mkdir -p "$SGOINFRE" "$TMP" "$ANDROID_AVD"

# ===============================
# INSTALL FLUTTER (GIT - STABLE)
# ===============================
echo "🦋 Installation de Flutter (stable via git)..."
rm -rf "$FLUTTER_DIR"
cd "$SGOINFRE"
git clone https://github.com/flutter/flutter.git -b stable
chmod -R u+rwX "$FLUTTER_DIR"

# ===============================
# INSTALL ANDROID CMDLINE TOOLS
# ===============================
echo "🤖 Installation Android cmdline-tools..."
rm -rf "$ANDROID_SDK"
mkdir -p "$ANDROID_SDK/cmdline-tools"
cd "$TMP"

curl -L "$CMDLINE_URL" -o cmdline.zip
unzip -q cmdline.zip
mv cmdline-tools "$ANDROID_SDK/cmdline-tools/latest"

# ===============================
# ENV (local au script)
# ===============================
export FLUTTER_HOME="$FLUTTER_DIR"
export ANDROID_SDK_ROOT="$ANDROID_SDK"
export ANDROID_HOME="$ANDROID_SDK"
export ANDROID_AVD_HOME="$ANDROID_AVD"

export PATH="$FLUTTER_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

# ===============================
# FIX FLUTTER LOCK (AU CAS OÙ)
# ===============================
rm -f "$FLUTTER_HOME/bin/cache/lockfile"

# ===============================
# ANDROID LICENSES
# ===============================
echo "📜 Acceptation licences Android..."
yes | sdkmanager --licenses

# ===============================
# ANDROID SDK COMPONENTS
# ===============================
echo "📦 Installation SDK Android..."
sdkmanager \
  "platform-tools" \
  "platforms;android-$API_LEVEL" \
  "emulator" \
  "$IMAGE"

# ===============================
# CREATE AVD
# ===============================
echo "📱 Création de l'émulateur..."
echo "no" | avdmanager create avd \
  -n flutter_avd \
  -k "$IMAGE" \
  -d "$DEVICE" \
  --force

# ===============================
# FLUTTER SETUP
# ===============================
echo "⚙️ Flutter doctor & precache..."
flutter config --no-analytics
flutter doctor --android-licenses
flutter precache
flutter doctor

# ===============================
# CLEAN
# ===============================
rm -rf "$TMP"

# ===============================
# DONE
# ===============================
echo ""
echo "✅ Flutter + Android SDK + Émulateur installés"
echo ""
echo "👉 Ajoute ceci à ton ~/.bashrc ou ~/.zshrc :"
echo 'export PATH="$HOME/sgoinfre/flutter/bin:$HOME/sgoinfre/android-sdk/platform-tools:$HOME/sgoinfre/android-sdk/emulator:$HOME/sgoinfre/android-sdk/cmdline-tools/latest/bin:$PATH"'
echo ""
echo "👉 Commandes utiles :"
echo "flutter doctor"
echo "emulator -avd flutter_avd"
echo "emulator lent ? -> emulator -avd flutter_avd -gpu swiftshader_indirect"
echo "⚠️ Si lock un jour : pkill -f flutter
rm -f ~/sgoinfre/flutter/bin/cache/lockfile"
# adb devices # abd ->(android debug bridge)
# emulator -list-avds -> avoir la liste des emulateur
# emulator -avd NOM_DE_TON_AVD -gpu swiftshader_indirect -no-snapshot -verbose -> lqncer l'emulateur

## Recréer event.g.dart correctement
# flutter pub run build_runner build 
# ou:
# flutter pub run build_runner watch --delete-conflicting-outputs