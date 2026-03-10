#!/bin/bash
# ==============================================================================
# MUSIC-ROOM - Full Development Environment Installer
# Adapted for 42 School (Ubuntu 22.04)
# All installs in ~/sgoinfre - NO sudo - NO apt - user-space only
# ==============================================================================

set -uo pipefail

LOG_FILE=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

info()    { echo -e "  ${BLUE}ℹ${RESET}  $1"; }
success() { echo -e "  ${GREEN}✔${RESET}  $1"; }
warn()    { echo -e "  ${YELLOW}⚠${RESET}  $1"; }
err()     { echo -e "  ${RED}✖${RESET}  $1"; }

# Global error trap — catches any unexpected failure with diagnostics
on_error() {
    local exit_code=$?
    local line_no=$1
    local cmd=$2
    echo ""
    echo -e "  ${RED}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "  ${RED}${BOLD}║                  ❌  INSTALLATION FAILED                     ║${RESET}"
    echo -e "  ${RED}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    err "Script failed at ${BOLD}line $line_no${RESET}"
    err "Command: ${DIM}$cmd${RESET}"
    err "Exit code: ${BOLD}$exit_code${RESET}"
    echo ""
    if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
        err "Last 20 lines of log:"
        echo -e "  ${DIM}─────────────────────────────────────────${RESET}"
        tail -20 "$LOG_FILE" 2>/dev/null | while IFS= read -r line; do
            echo -e "  ${DIM}  $line${RESET}"
        done
        echo -e "  ${DIM}─────────────────────────────────────────${RESET}"
        err "Full log: $LOG_FILE"
    fi
    echo ""
    err "To retry: ${GREEN}bash install.sh${RESET} (idempotent — skips completed steps)"
    echo ""
    exit $exit_code
}

trap 'on_error ${LINENO} "${BASH_COMMAND}"' ERR

# ==============================================================================
# CONFIGURATION
# ==============================================================================
SGOINFRE="$HOME/sgoinfre"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

FLUTTER_DIR="$SGOINFRE/flutter"
ANDROID_SDK="$SGOINFRE/android-sdk"
ANDROID_AVD="$SGOINFRE/android-avd"
NVM_DIR_CUSTOM="$SGOINFRE/nvm"
PUB_CACHE_DIR="$SGOINFRE/pub_cache"
TMP_DIR="$SGOINFRE/tmp"

NODE_VERSION="22"
FLUTTER_CHANNEL="stable"
ANDROID_API_LEVEL=36
CMDLINE_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"

TOTAL_STEPS=10
CURRENT_STEP=0

# ==============================================================================
# UI HELPERS
# ==============================================================================
print_banner() {
    echo ""
    echo -e "${MAGENTA}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════════════╗"
    echo "  ║           MUSIC-ROOM  —  Environment Installer               ║"
    echo "  ║         42 School  •  Ubuntu 22.04  •  No sudo               ║"
    echo "  ╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "  ${DIM}All installations go to ~/sgoinfre (user-space only)${RESET}"
    echo ""
}

step_header() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local pct=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    local filled=$((pct / 2))
    local empty=$((50 - filled))
    echo ""
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${CYAN}${BOLD}  [$CURRENT_STEP/$TOTAL_STEPS]  $1${RESET}"
    echo -ne "  ${GREEN}"
    for ((j=0; j<filled; j++)); do printf '█'; done
    echo -ne "${DIM}"
    for ((j=0; j<empty; j++)); do printf '░'; done
    echo -e "${RESET}  ${BOLD}${pct}%${RESET}"
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}

# Run a command with spinner animation, log output. Fail loudly.
run_logged() {
    local msg="$1"
    shift
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    "$@" >> "$LOG_FILE" 2>&1 &
    local pid=$!

    while kill -0 "$pid" 2>/dev/null; do
        local c="${spin:i++%${#spin}:1}"
        printf "\r  ${CYAN}%s${RESET}  %s" "$c" "$msg"
        sleep 0.1
    done

    wait "$pid"
    local rc=$?
    printf "\r\033[K"

    if [ $rc -eq 0 ]; then
        success "$msg"
    else
        err "$msg"
        err "Command failed (exit $rc): $*"
        if [ -n "$LOG_FILE" ]; then
            err "Last 10 lines of log:"
            tail -10 "$LOG_FILE" 2>/dev/null | while IFS= read -r logline; do
                echo -e "    ${DIM}$logline${RESET}"
            done
        fi
        return $rc
    fi
}

# Re-apply the /tmp symlink for Flutter's startup lockfile.
# Called before every flutter invocation inside this script so that even if
# Flutter itself recreated the real NFS file we immediately fix it again.
flutter_fix_lock() {
    local lf="$FLUTTER_DIR/bin/cache/lockfile"
    local tl="/tmp/.flutter_startup_lock_$(id -u)"
    mkdir -p "$FLUTTER_DIR/bin/cache" 2>/dev/null || true
    # Replace with symlink only if not already a correct symlink
    if [ ! -L "$lf" ] || [ "$(readlink "$lf")" != "$tl" ]; then
        rm -rf "$lf" 2>/dev/null
        ln -sf "$tl" "$lf"
    fi
}

# ==============================================================================
# STEP 1: PRE-FLIGHT CHECKS
# ==============================================================================
preflight_checks() {
    step_header "Pre-flight checks"

    # OS
    if grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
        success "Ubuntu detected"
    else
        warn "Not Ubuntu — some steps may differ"
    fi

    # sgoinfre
    [ ! -d "$SGOINFRE" ] && mkdir -p "$SGOINFRE"
    if [ -w "$SGOINFRE" ]; then
        success "~/sgoinfre is writable"
    else
        err "~/sgoinfre is not writable — cannot proceed"
        return 1
    fi

    # Temp + log
    mkdir -p "$TMP_DIR"
    LOG_FILE="$TMP_DIR/install_$(date +%Y%m%d_%H%M%S).log"
    touch "$LOG_FILE"
    success "Log file: $LOG_FILE"

    # Internet
    if curl -s --max-time 5 https://google.com > /dev/null 2>&1; then
        success "Internet connectivity OK"
    else
        err "No internet — cannot download packages"
        return 1
    fi

    # Filesystem type (NFS = lockfile issues)
    local fs_type
    fs_type=$(df -T "$SGOINFRE" 2>/dev/null | tail -1 | awk '{print $2}')
    info "Filesystem: ${BOLD}$fs_type${RESET}"
    if [[ "$fs_type" == "nfs"* ]] || [[ "$fs_type" == "cifs" ]] || [[ "$fs_type" == "fuse"* ]]; then
        warn "Network FS — Flutter lockfile workarounds will be applied"
    fi

    # Space
    local avail
    avail=$(df -h "$SGOINFRE" | tail -1 | awk '{print $4}')
    info "Space available: ${BOLD}$avail${RESET}"

    # Required tools (pre-installed at 42)
    info "Checking system tools (pre-installed at 42)..."
    local all_present=1
    for tool in git curl wget unzip; do
        if command -v "$tool" &>/dev/null; then
            success "$tool found"
        else
            err "$tool NOT found — should be pre-installed at 42"
            all_present=0
        fi
    done
    [ $all_present -eq 0 ] && return 1

    # Docker (system-installed at 42)
    if command -v docker &>/dev/null; then
        success "Docker: $(docker --version 2>&1 | head -c 50)"
        if docker compose version &>/dev/null; then
            success "Docker Compose: $(docker compose version --short 2>/dev/null)"
        else
            warn "Docker Compose not available"
        fi
        if docker ps &>/dev/null; then
            success "Docker daemon accessible"
        else
            warn "Cannot reach Docker daemon — try: ${GREEN}newgrp docker${RESET}"
        fi
    else
        warn "Docker not found — docker compose up will not work"
    fi

    # Chrome (system-installed at 42)
    if command -v google-chrome &>/dev/null || command -v google-chrome-stable &>/dev/null; then
        local chrome_ver
        chrome_ver=$(google-chrome --version 2>/dev/null || google-chrome-stable --version 2>/dev/null || echo "?")
        success "Chrome: $chrome_ver"
    else
        warn "Chrome not found — Flutter web needs Chrome"
    fi

    # Java (system-installed at 42)
    if command -v java &>/dev/null; then
        success "Java: $(java -version 2>&1 | head -1)"
    else
        warn "Java not found — Android SDK needs Java"
    fi
}

# ==============================================================================
# STEP 2: NVM + NODE.JS (user-space in sgoinfre)
# ==============================================================================
install_node() {
    step_header "Node.js $NODE_VERSION via NVM (in sgoinfre)"

    export NVM_DIR="$NVM_DIR_CUSTOM"

    if [ -d "$NVM_DIR" ] && [ -s "$NVM_DIR/nvm.sh" ]; then
        success "NVM already installed"
    else
        info "Installing NVM to $NVM_DIR..."
        rm -rf "$NVM_DIR"
        mkdir -p "$NVM_DIR"
        run_logged "Downloading & installing NVM" bash -c \
            "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | PROFILE=/dev/null NVM_DIR='$NVM_DIR' bash"
    fi

    # Load NVM
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    if ! command -v nvm &>/dev/null; then
        err "NVM failed to load"
        return 1
    fi

    # Install Node
    if nvm ls "$NODE_VERSION" &>/dev/null 2>&1; then
        success "Node.js $NODE_VERSION already installed"
    else
        info "Installing Node.js $NODE_VERSION..."
        run_logged "Installing Node.js $NODE_VERSION" nvm install "$NODE_VERSION"
    fi

    nvm use "$NODE_VERSION" >> "$LOG_FILE" 2>&1 || true
    nvm alias default "$NODE_VERSION" >> "$LOG_FILE" 2>&1 || true

    if command -v node &>/dev/null; then
        success "Node.js $(node --version) active"
        success "npm $(npm --version) active"
    else
        err "Node.js not available after install"
        return 1
    fi
}

# ==============================================================================
# STEP 3: Flutter SDK — pre-built release archive (includes Dart SDK + snapshots)
# ==============================================================================
install_flutter() {
    step_header "Flutter SDK (in sgoinfre)"

    export PUB_CACHE="$PUB_CACHE_DIR"
    mkdir -p "$PUB_CACHE" "$TMP_DIR"

    # ── Resolve latest stable archive URL from Flutter's release manifest ──────
    info "Resolving latest Flutter stable release URL..."
    local releases_json
    releases_json=$(curl -fsSL \
        "https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json" \
        2>>"$LOG_FILE" || true)
    if [ -z "$releases_json" ]; then
        err "Failed to fetch Flutter releases manifest (check internet connection)"
        return 1
    fi
    # Extract archive path for current stable hash using python3 (always available on Ubuntu)
    local archive_path
    archive_path=$(echo "$releases_json" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ch = d['current_release']['stable']
for r in d['releases']:
    if r['hash'] == ch and r['channel'] == 'stable':
        print(r['archive']); break
" 2>>"$LOG_FILE" || true)
    if [ -z "$archive_path" ]; then
        err "Could not parse Flutter stable release from manifest"
        return 1
    fi
    local flutter_url="https://storage.googleapis.com/flutter_infra_release/releases/$archive_path"
    # Extract version string from path, e.g. flutter_linux_3.29.0-stable.tar.xz
    local flutter_version
    flutter_version=$(basename "$archive_path" | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "")
    success "Latest stable: Flutter $flutter_version"
    # ──────────────────────────────────────────────────────────────────────────

    # ── Skip download if already installed at same version ────────────────────
    local version_stamp="$FLUTTER_DIR/.installed_version"
    if [ -d "$FLUTTER_DIR" ] && [ -x "$FLUTTER_DIR/bin/flutter" ] && \
       [ -f "$version_stamp" ] && [ "$(cat "$version_stamp" 2>/dev/null)" = "$flutter_version" ]; then
        success "Flutter SDK already installed at v$flutter_version — skipping download"
    else
        # ── Download tarball to /tmp (local FS — fast even on NFS machines) ───
        local tarball="/tmp/flutter_linux_${flutter_version}-stable.tar.xz"
        if [ -f "$tarball" ]; then
            info "Tarball already in /tmp — reusing"
        else
            run_logged "Downloading Flutter $flutter_version tarball" \
                curl -fL --progress-bar "$flutter_url" -o "$tarball"
        fi

        # ── Extract to /tmp first (avoids NFS write amplification) ────────────
        info "Extracting Flutter SDK (to /tmp, then moving to sgoinfre)..."
        local extract_dir="/tmp/flutter_extract_$$"
        rm -rf "$extract_dir"
        mkdir -p "$extract_dir"
        run_logged "Extracting Flutter tarball" \
            tar -xf "$tarball" -C "$extract_dir"

        # ── Move extracted dir to sgoinfre ────────────────────────────────────
        info "Moving Flutter SDK to sgoinfre..."
        rm -rf "$FLUTTER_DIR"
        mv "$extract_dir/flutter" "$FLUTTER_DIR"
        rm -rf "$extract_dir" "$tarball"
        echo "$flutter_version" > "$version_stamp"
        success "Flutter SDK installed to sgoinfre"
    fi
    # ──────────────────────────────────────────────────────────────────────────

    # Fix permissions (critical for NFS sgoinfre)
    chmod -R u+rwX "$FLUTTER_DIR" 2>/dev/null || true
    success "Permissions fixed"

    # Export for this session
    export FLUTTER_HOME="$FLUTTER_DIR"
    export PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$PATH"

    # ── NFS lockfile fix ──────────────────────────────────────────────────────
    # Flutter uses flock() on bin/cache/lockfile at startup. On NFS flock()
    # blocks forever. Symlink that path to /tmp (local tmpfs) so flock()
    # resolves instantly.
    local local_lock="/tmp/.flutter_startup_lock_$(id -u)"
    mkdir -p "$FLUTTER_DIR/bin/cache" 2>/dev/null || true
    rm -rf "$FLUTTER_DIR/bin/cache/lockfile" 2>/dev/null
    ln -sf "$local_lock" "$FLUTTER_DIR/bin/cache/lockfile"
    success "Lockfile symlinked to /tmp (NFS flock fix)"
    # ──────────────────────────────────────────────────────────────────────────

    # Disable analytics via env vars — no flutter binary call needed
    export FLUTTER_SUPPRESS_ANALYTICS=1
    export FLUTTER_CLI_ANIMATIONS=false
    export PUB_ENVIRONMENT="bot.flutter_install"
    mkdir -p "$HOME/.config/flutter" 2>/dev/null || true
    printf '{"firstRunAt":1,"enabled":false}\n' > "$HOME/.config/flutter/settings" 2>/dev/null || true
    success "Analytics disabled (via env vars + config file)"

    # Precache skipped — web artifacts download automatically on first 'flutter run'
    success "Precache skipped — web artifacts will auto-download on first run"
}

# ==============================================================================
# STEP 4: DART SDK (bundled with Flutter)
# ==============================================================================
verify_dart() {
    step_header "Dart SDK (bundled with Flutter)"

    export PATH="$FLUTTER_DIR/bin:$FLUTTER_DIR/bin/cache/dart-sdk/bin:$PATH"

    # The pre-built Flutter tarball already bundles the Dart SDK — no bootstrap needed.
    local dart_bin="$FLUTTER_DIR/bin/cache/dart-sdk/bin/dart"
    if [ -x "$dart_bin" ]; then
        success "Dart SDK present: $("$dart_bin" --version 2>&1 | head -1)"
    else
        warn "Dart SDK binary not found — it will be available after 'flutter pub get' in step 6"
    fi
}

# ==============================================================================
# STEP 5: ANDROID SDK (download + unzip in sgoinfre)
# ==============================================================================
install_android_sdk() {
    step_header "Android SDK (in sgoinfre)"

    export ANDROID_SDK_ROOT="$ANDROID_SDK"
    export ANDROID_HOME="$ANDROID_SDK"
    export ANDROID_AVD_HOME="$ANDROID_AVD"
    export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

    mkdir -p "$ANDROID_SDK/cmdline-tools" "$ANDROID_AVD"

    # Command-line tools
    if [ -x "$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" ]; then
        success "Android cmdline-tools already installed"
    else
        info "Downloading Android cmdline-tools..."
        mkdir -p "$TMP_DIR"
        run_logged "Downloading cmdline-tools" curl -L "$CMDLINE_URL" -o "$TMP_DIR/cmdline.zip"

        info "Extracting..."
        rm -rf "$ANDROID_SDK/cmdline-tools/latest" "$TMP_DIR/cmdline-extract"
        unzip -q "$TMP_DIR/cmdline.zip" -d "$TMP_DIR/cmdline-extract" >> "$LOG_FILE" 2>&1
        mv "$TMP_DIR/cmdline-extract/cmdline-tools" "$ANDROID_SDK/cmdline-tools/latest"
        rm -rf "$TMP_DIR/cmdline-extract" "$TMP_DIR/cmdline.zip"
        success "cmdline-tools extracted"
    fi

    # Verify sdkmanager
    if ! "$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" --version >> "$LOG_FILE" 2>&1; then
        err "sdkmanager not working (Java issue?)"
        return 1
    fi
    success "sdkmanager OK"

    # Licenses
    info "Accepting licenses..."
    yes 2>/dev/null | "$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" --licenses >> "$LOG_FILE" 2>&1 || true
    success "Licenses accepted"

    # SDK components — only what the project needs (plugins are pinned to API 34
    # via the subprojects override in android/build.gradle.kts)
    info "Installing SDK components (API $ANDROID_API_LEVEL)..."
    run_logged "Installing platforms + build-tools + NDK" \
        "$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" --install \
            "platform-tools" \
            "platforms;android-$ANDROID_API_LEVEL" \
            "build-tools;${ANDROID_API_LEVEL}.0.0" \
            "ndk;28.2.13676358"

    # Tell Flutter about Android SDK
    flutter_fix_lock
    FLUTTER_SUPPRESS_ANALYTICS=1 FLUTTER_CLI_ANIMATIONS=false \
        timeout 30 "$FLUTTER_DIR/bin/flutter" config --android-sdk "$ANDROID_SDK" >> "$LOG_FILE" 2>&1 || true
    flutter_fix_lock
    yes 2>/dev/null | FLUTTER_SUPPRESS_ANALYTICS=1 FLUTTER_CLI_ANIMATIONS=false \
        timeout 120 "$FLUTTER_DIR/bin/flutter" doctor --android-licenses >> "$LOG_FILE" 2>&1 || true
    success "Android SDK configured with Flutter"
}

# ==============================================================================
# STEP 6: ANDROID EMULATOR (system image + Pixel 6 AVD)
# ==============================================================================
setup_android_emulator() {
    step_header "Android Emulator (Pixel 6 AVD)"

    export ANDROID_SDK_ROOT="$ANDROID_SDK"
    export ANDROID_HOME="$ANDROID_SDK"
    export ANDROID_AVD_HOME="$ANDROID_AVD"
    export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

    local SDKMAN="$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager"
    local AVDMAN="$ANDROID_SDK/cmdline-tools/latest/bin/avdmanager"
    local AVD_NAME="Pixel_6"
    local SYSIMG="system-images;android-${ANDROID_API_LEVEL};google_apis_playstore;x86_64"

    # --- emulator binary ---
    if [ -x "$ANDROID_SDK/emulator/emulator" ]; then
        success "Android emulator binary already installed"
    else
        info "Installing Android emulator..."
        run_logged "Installing emulator" \
            "$SDKMAN" --install "emulator" --sdk_root="$ANDROID_SDK"
        success "Emulator installed"
    fi

    # --- system image ---
    local sysimg_dir="$ANDROID_SDK/system-images/android-${ANDROID_API_LEVEL}/google_apis_playstore/x86_64"
    if [ -d "$sysimg_dir" ]; then
        success "System image (API $ANDROID_API_LEVEL x86_64) already installed"
    else
        info "Downloading system image API $ANDROID_API_LEVEL (~1.5 GB) — please wait..."
        run_logged "Installing system image" \
            "$SDKMAN" --install "$SYSIMG" --sdk_root="$ANDROID_SDK"
        success "System image installed"
    fi

    # --- accept any new licenses ---
    yes 2>/dev/null | "$SDKMAN" --licenses --sdk_root="$ANDROID_SDK" >> "$LOG_FILE" 2>&1 || true

    # --- AVD creation ---
    mkdir -p "$ANDROID_AVD"
    if "$AVDMAN" list avd 2>/dev/null | grep -q "Name: $AVD_NAME"; then
        success "AVD '$AVD_NAME' already exists"
    else
        info "Creating AVD '$AVD_NAME' (Pixel 6)..."
        echo "no" | "$AVDMAN" create avd \
            --name "$AVD_NAME" \
            --device "pixel_6" \
            --package "$SYSIMG" \
            --path "$ANDROID_AVD/${AVD_NAME}.avd" \
            --force >> "$LOG_FILE" 2>&1
        if "$AVDMAN" list avd 2>/dev/null | grep -q "Name: $AVD_NAME"; then
            success "AVD '$AVD_NAME' created"
        else
            err "Failed to create AVD '$AVD_NAME' — check log: $LOG_FILE"
            return 1
        fi
    fi

    # --- tune AVD config for performance (applies on every run, idempotent) ---
    local avd_ini="$ANDROID_AVD/${AVD_NAME}.avd/config.ini"
    if [ -f "$avd_ini" ]; then
        sed -i 's/hw\.gpu\.enabled = .*/hw.gpu.enabled = yes/' "$avd_ini"
        sed -i 's/hw\.gpu\.mode = .*/hw.gpu.mode = swiftshader_indirect/' "$avd_ini"
        # Enable physical keyboard passthrough
        if ! grep -q "hw.keyboard" "$avd_ini"; then
            echo "hw.keyboard = yes" >> "$avd_ini"
        else
            sed -i 's/hw\.keyboard = .*/hw.keyboard = yes/' "$avd_ini"
        fi
        # set ramSize only if the existing value is below 3072
        local cur_ram
        cur_ram=$(grep -oP '(?<=hw\.ramSize = )\d+' "$avd_ini" 2>/dev/null || echo 0)
        if [ "$cur_ram" -lt 3072 ] 2>/dev/null; then
            sed -i 's/hw\.ramSize = .*/hw.ramSize = 3072/' "$avd_ini"
        fi
        success "AVD hardware config tuned (GPU host, 3072 MB RAM)"
    fi

    # --- KVM acceleration check ---
    if [ -r /dev/kvm ]; then
        success "KVM available — emulator will use hardware acceleration"
    else
        warn "/dev/kvm not accessible — emulator will use software rendering (slow)"
        warn "Ask sysadmin or try: sudo chmod 666 /dev/kvm"
    fi
}

# ==============================================================================
# STEP 7: PROJECT DEPENDENCIES
# ==============================================================================
install_project_deps() {
    step_header "Project dependencies"

    export PUB_CACHE="$PUB_CACHE_DIR"

    cd "$PROJECT_DIR/flutter_app_"
    info "Running flutter pub get..."
    flutter_fix_lock
    run_logged "flutter pub get" \
        env FLUTTER_SUPPRESS_ANALYTICS=1 FLUTTER_CLI_ANIMATIONS=false \
        timeout 900 "$FLUTTER_DIR/bin/flutter" pub get

    info "Running build_runner..."
    flutter_fix_lock
    FLUTTER_SUPPRESS_ANALYTICS=1 FLUTTER_CLI_ANIMATIONS=false \
        timeout 600 "$FLUTTER_DIR/bin/flutter" pub run build_runner build --delete-conflicting-outputs >> "$LOG_FILE" 2>&1 || true
    success "Code generation complete"

    cd "$PROJECT_DIR"
}

# ==============================================================================
# STEP 8: .ENV FILE
# ==============================================================================
setup_env_file() {
    step_header "back/.env configuration"

    local env_file="$PROJECT_DIR/back/.env"

    if [ -f "$env_file" ]; then
        success ".env already exists"
    else
        info "Creating template .env..."
        cat > "$env_file" << 'ENVEOF'
# DATABASE
DB_HOST=db
DB_PORT=3306
DB_USERNAME=root
DB_PASSWORD=root
DB_DATABASE=db

# JWT
JWT_SECRET=music-room-secret-key-change-me
JWT_EXPIRATION=7d

# APP
APP_PORT=3000
APP_URL=http://localhost:3000

# MAIL (MailHog)
MAIL_HOST=mailhog
MAIL_PORT=1025
MAIL_USER=
MAIL_PASS=
MAIL_FROM=noreply@music-room.local

# OAUTH
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GOOGLE_CALLBACK_URL=http://localhost:3000/auth/google/callback
FACEBOOK_CLIENT_ID=
FACEBOOK_CLIENT_SECRET=
FACEBOOK_CALLBACK_URL=http://localhost:3000/auth/facebook/callback

# FRONTEND
FRONTEND_URL=http://localhost:8080
ENVEOF
        success ".env template created"
        warn "Fill in your OAuth credentials in back/.env"
    fi
}

# ==============================================================================
# STEP 9: SHELL CONFIG
# ==============================================================================
setup_shell_config() {
    step_header "Shell configuration"

    local shell_rc="$HOME/.zshrc"
    [ "$(basename "${SHELL:-bash}")" != "zsh" ] && shell_rc="$HOME/.bashrc"

    local marker_start="# >>>>> MUSIC-ROOM 42 ENV START >>>>>"
    local marker_end="# <<<<< MUSIC-ROOM 42 ENV END <<<<<"

    # Remove old block if present
    if [ -f "$shell_rc" ] && grep -qF "$marker_start" "$shell_rc" 2>/dev/null; then
        info "Removing old config block..."
        sed -i "\|$marker_start|,\|$marker_end|d" "$shell_rc"
    fi

    # Append new block
    cat >> "$shell_rc" << 'RCEOF'

# >>>>> MUSIC-ROOM 42 ENV START >>>>>

# NVM (Node Version Manager) in sgoinfre
export NVM_DIR="$HOME/sgoinfre/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Flutter SDK in sgoinfre
export FLUTTER_HOME="$HOME/sgoinfre/flutter"
export PUB_CACHE="$HOME/sgoinfre/pub_cache"
export PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$PATH"

# Android SDK in sgoinfre
export ANDROID_SDK_ROOT="$HOME/sgoinfre/android-sdk"
export ANDROID_HOME="$HOME/sgoinfre/android-sdk"
export ANDROID_AVD_HOME="$HOME/sgoinfre/android-avd"
export GRADLE_USER_HOME="$HOME/sgoinfre/gradle"
# Symlink ~/.gradle -> sgoinfre so Gradle always writes there even without the env var
mkdir -p "$HOME/sgoinfre/gradle" && [ ! -L "$HOME/.gradle" ] && rm -rf "$HOME/.gradle" && ln -sf "$HOME/sgoinfre/gradle" "$HOME/.gradle" 2>/dev/null || true
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

# Chrome for Flutter web
export CHROME_EXECUTABLE="$(command -v google-chrome-stable 2>/dev/null || command -v google-chrome 2>/dev/null || echo '/usr/bin/google-chrome-stable')"

# Flutter: suppress analytics & animations (avoids lockfile hangs on NFS)
export FLUTTER_SUPPRESS_ANALYTICS=1
export FLUTTER_CLI_ANIMATIONS=false
export PUB_ENVIRONMENT="bot.flutter_install"

# Flutter NFS lockfile fix:
# flock() on NFS hangs forever. Symlink the lockfile to /tmp (local tmpfs) so
# flock() resolves instantly. Re-applied on every flutter call in case Flutter
# or 'flutter upgrade' recreated the real file.
flutter() {
    local _lf="$FLUTTER_HOME/bin/cache/lockfile"
    local _tl="/tmp/.flutter_startup_lock_$(id -u)"
    if [ ! -L "$_lf" ] || [ "$(readlink "$_lf")" != "$_tl" ]; then
        rm -rf "$_lf" 2>/dev/null
        mkdir -p "$(dirname "$_lf")" 2>/dev/null
        ln -sf "$_tl" "$_lf"
    fi
    FLUTTER_SUPPRESS_ANALYTICS=1 FLUTTER_CLI_ANIMATIONS=false command flutter "$@"
}

# <<<<< MUSIC-ROOM 42 ENV END <<<<<
RCEOF

    success "Config written to $shell_rc"

    # Source for current session
    export NVM_DIR="$NVM_DIR_CUSTOM"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    export FLUTTER_HOME="$FLUTTER_DIR"
    export PUB_CACHE="$PUB_CACHE_DIR"
    export ANDROID_SDK_ROOT="$ANDROID_SDK"
    export ANDROID_HOME="$ANDROID_SDK"
    export ANDROID_AVD_HOME="$ANDROID_AVD"
    export GRADLE_USER_HOME="$SGOINFRE/gradle"
    mkdir -p "$SGOINFRE/gradle"
    # Symlink ~/.gradle -> sgoinfre (belt + suspenders alongside GRADLE_USER_HOME)
    if [ ! -L "$HOME/.gradle" ]; then
        rm -rf "$HOME/.gradle"
        ln -sf "$SGOINFRE/gradle" "$HOME/.gradle"
    fi
    export CHROME_EXECUTABLE="$(command -v google-chrome-stable 2>/dev/null || command -v google-chrome 2>/dev/null || echo '/usr/bin/google-chrome-stable')"
    export PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
    success "Environment exported for current session"
}

# ==============================================================================
# STEP 10: FINAL VERIFICATION
# ==============================================================================
final_verification() {
    step_header "Final verification"

    local all_ok=1
    local pass=0
    local total=0

    chk() {
        local name="$1"
        local cmd="$2"
        local vcmd="$3"
        total=$((total + 1))
        if eval "$cmd" &>/dev/null; then
            local v
            v=$(eval "$vcmd" 2>&1 | head -1 | head -c 60)
            success "$(printf '%-18s' "$name") $v"
            pass=$((pass + 1))
        else
            err "$(printf '%-18s' "$name") NOT AVAILABLE"
            all_ok=0
        fi
    }

    echo ""
    chk "docker"         "command -v docker"            "docker --version"
    chk "docker compose" "docker compose version"       "docker compose version"
    chk "node"           "command -v node"              "node --version"
    chk "npm"            "command -v npm"               "npm --version"
    chk "flutter"        "test -x '$FLUTTER_DIR/bin/flutter'" \
                         "FLUTTER_SUPPRESS_ANALYTICS=1 FLUTTER_CLI_ANIMATIONS=false timeout 30 '$FLUTTER_DIR/bin/flutter' --version 2>&1 | head -1"
    chk "dart"           "test -x '$FLUTTER_DIR/bin/cache/dart-sdk/bin/dart'" \
                         "'$FLUTTER_DIR/bin/cache/dart-sdk/bin/dart' --version 2>&1 | head -1"
    chk "java"           "command -v java"              "java -version 2>&1 | head -1"
    chk "chrome"         "command -v google-chrome || command -v google-chrome-stable" \
                         "google-chrome --version 2>/dev/null || google-chrome-stable --version"
    chk "android-sdk"    "test -x '$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager'" \
                         "echo 'API $ANDROID_API_LEVEL'"
    echo ""
    info "${BOLD}$pass/$total${RESET} checks passed"
    echo ""

    # Flutter Doctor
    info "Flutter doctor:"
    echo ""
    flutter_fix_lock
    FLUTTER_SUPPRESS_ANALYTICS=1 FLUTTER_CLI_ANIMATIONS=false \
        timeout 60 "$FLUTTER_DIR/bin/flutter" doctor 2>&1 | grep -E '^\[|Doctor summary' | head -20 || true
    echo ""

    info "Log: $LOG_FILE"

    [ $all_ok -eq 1 ] && return 0 || return 1
}

# ==============================================================================
# FINAL SUMMARY
# ==============================================================================
print_summary() {
    local status=$1
    local shell_rc="$HOME/.zshrc"
    [ "$(basename "${SHELL:-bash}")" != "zsh" ] && shell_rc="$HOME/.bashrc"

    echo ""
    echo -e "${MAGENTA}${BOLD}"
    if [ "$status" -eq 0 ]; then
        echo "  ╔══════════════════════════════════════════════════════════════╗"
        echo "  ║         ✅  INSTALLATION COMPLETE — ALL TOOLS READY          ║"
        echo "  ╚══════════════════════════════════════════════════════════════╝"
    else
        echo "  ╔══════════════════════════════════════════════════════════════╗"
        echo "  ║       ⚠️   INSTALLATION COMPLETE — SOME ISSUES FOUND         ║"
        echo "  ╚══════════════════════════════════════════════════════════════╝"
    fi
    echo -e "${RESET}"
    echo ""
    echo -e "  ${BOLD}Quick Start:${RESET}"
    echo ""
    echo -e "  ${CYAN}1.${RESET} Reload your shell:"
    echo -e "     ${GREEN}source $shell_rc${RESET}"
    echo ""
    echo -e "  ${CYAN}2.${RESET} Start the backend:"
    echo -e "     ${GREEN}cd $PROJECT_DIR && docker compose up --build${RESET}"
    echo ""
    echo -e "  ${CYAN}3.${RESET} Start Flutter web (another terminal):"
    echo -e "     ${GREEN}cd $PROJECT_DIR/flutter_app_ && flutter run -d chrome --web-port 8080${RESET}"
    echo ""
    echo -e "  ${CYAN}4.${RESET} Start Android emulator (another terminal):"
    echo -e "     ${GREEN}$ANDROID_SDK/emulator/emulator -avd Pixel_6${RESET}"
    echo -e "     ${DIM}Then once the emulator has finished booting:${RESET}"
    echo -e "     ${GREEN}cd $PROJECT_DIR/flutter_app_ && flutter run -d android${RESET}"
    echo ""
    echo -e "  ${BOLD}Services:${RESET}"
    echo -e "  ${DIM}├${RESET} Backend API       ${CYAN}http://localhost:3000${RESET}"
    echo -e "  ${DIM}├${RESET} Flutter Web       ${CYAN}http://localhost:8080${RESET}"
    echo -e "  ${DIM}├${RESET} phpMyAdmin        ${CYAN}http://localhost:4000${RESET}"
    echo -e "  ${DIM}├${RESET} MailHog           ${CYAN}http://localhost:8025${RESET}"
    echo -e "  ${DIM}└${RESET} MySQL             ${CYAN}localhost:3306${RESET}"
    echo ""
    echo -e "  ${BOLD}Troubleshooting:${RESET}"
    echo -e "  ${DIM}•${RESET} Flutter lockfile hang  → ${GREEN}ln -sf /tmp/.flutter_startup_lock_\$(id -u) ~/sgoinfre/flutter/bin/cache/lockfile${RESET}"
    echo -e "  ${DIM}•${RESET} Docker permission      → ${GREEN}newgrp docker${RESET}"
    echo -e "  ${DIM}•${RESET} Re-run installer       → ${GREEN}bash install.sh${RESET} ${DIM}(idempotent)${RESET}"
    echo -e "  ${DIM}•${RESET} Install log            → ${GREEN}$LOG_FILE${RESET}"
    echo ""
}

# ==============================================================================
# MAIN
# ==============================================================================
main() {
    print_banner

    preflight_checks          # 1 — System check (no install)
    install_node              # 2 — NVM + Node.js
    install_flutter           # 3 — Flutter SDK
    verify_dart               # 4 — Dart SDK
    install_android_sdk       # 5 — Android SDK
    setup_android_emulator    # 6 — Pixel 6 AVD
    install_project_deps      # 7 — flutter pub get
    setup_env_file            # 8 — .env template
    setup_shell_config        # 9 — Shell rc config

    local verify_status=0
    final_verification || verify_status=$?  # 10 — Verification

    print_summary $verify_status
}

main "$@"
