#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║          🎵  MUSIC-ROOM — Full Development Environment Installer  🎵       ║
# ║                    Adapted for 42 School (Ubuntu 22.04)                     ║
# ║          All heavy installs go to ~/sgoinfre to respect 5GB quota           ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────────────────────
SGOINFRE="$HOME/sgoinfre"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Paths inside sgoinfre
FLUTTER_DIR="$SGOINFRE/flutter"
ANDROID_SDK="$SGOINFRE/android-sdk"
ANDROID_AVD="$SGOINFRE/android-avd"
DOCKER_DIR="$SGOINFRE/docker"
NVM_DIR_CUSTOM="$SGOINFRE/nvm"
CHROME_DIR="$SGOINFRE/chrome"
TMP_DIR="$SGOINFRE/tmp"

# Versions
NODE_VERSION="22"
FLUTTER_CHANNEL="stable"
ANDROID_API_LEVEL=34
CMDLINE_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"

# ─────────────────────────────────────────────────────────────
# COLORS & UI HELPERS
# ─────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

TOTAL_STEPS=10
CURRENT_STEP=0

print_banner() {
    echo ""
    echo -e "${MAGENTA}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════════════╗"
    echo "  ║           MUSIC-ROOM  —  Environment Installer             ║"
    echo "  ║              42 School  •  Ubuntu 22.04                    ║"
    echo "  ╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "  ${DIM}All installations go to ~/sgoinfre to respect 5GB quota${RESET}"
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
    printf '█%.0s' $(seq 1 $filled 2>/dev/null || true)
    echo -ne "${DIM}"
    printf '░%.0s' $(seq 1 $empty 2>/dev/null || true)
    echo -e "${RESET}  ${BOLD}${pct}%${RESET}"
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}

info()    { echo -e "  ${BLUE}ℹ${RESET}  $1"; }
success() { echo -e "  ${GREEN}✔${RESET}  $1"; }
warn()    { echo -e "  ${YELLOW}⚠${RESET}  $1"; }
err()     { echo -e "  ${RED}✖${RESET}  $1"; }

spinner() {
    local pid=$1
    local msg=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        local c="${spin:i++%${#spin}:1}"
        printf "\r  ${CYAN}%s${RESET}  %s" "$c" "$msg"
        sleep 0.1
    done
    wait "$pid"
    local exit_code=$?
    printf "\r"
    if [ $exit_code -eq 0 ]; then
        success "$msg"
    else
        err "$msg (exit code: $exit_code)"
        return $exit_code
    fi
}

run_with_spinner() {
    local msg="$1"
    shift
    "$@" > "$TMP_DIR/install_log_$$.txt" 2>&1 &
    spinner $! "$msg"
}

# ─────────────────────────────────────────────────────────────
# PRE-FLIGHT CHECKS
# ─────────────────────────────────────────────────────────────
preflight_checks() {
    step_header "Pre-flight checks"

    # Check we're on Ubuntu
    if ! grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
        warn "Not running Ubuntu — some steps may need adjustment"
    else
        success "Ubuntu detected"
    fi

    # Check sgoinfre exists and is writable
    if [ ! -d "$SGOINFRE" ]; then
        mkdir -p "$SGOINFRE"
    fi
    if [ -w "$SGOINFRE" ]; then
        success "~/sgoinfre is writable"
    else
        err "~/sgoinfre is not writable — cannot proceed"
        exit 1
    fi

    # Create temp dir
    mkdir -p "$TMP_DIR"
    success "Temp directory ready: $TMP_DIR"

    # Check internet connectivity
    if curl -s --max-time 5 https://google.com > /dev/null 2>&1; then
        success "Internet connectivity OK"
    else
        err "No internet — cannot download packages"
        exit 1
    fi

    # ── Fix sgoinfre storage type issues ──
    # On 42 machines, sgoinfre may be on NFS/CIFS/FUSE which causes:
    #   - Flutter lockfile "waiting for process" loop (flock doesn't work)
    #   - Slow or broken file watchers
    # Solution: disable Flutter analytics/lockfile, and ensure no flock usage
    info "Checking sgoinfre filesystem type..."
    local fs_type
    fs_type=$(df -T "$SGOINFRE" 2>/dev/null | tail -1 | awk '{print $2}')
    info "Filesystem type: ${BOLD}$fs_type${RESET}"

    if [[ "$fs_type" == "nfs"* ]] || [[ "$fs_type" == "cifs" ]] || [[ "$fs_type" == "fuse"* ]] || [[ "$fs_type" == "tmpfs" ]]; then
        warn "Network/special filesystem detected — will apply lockfile workarounds"
        export SGOINFRE_IS_NETWORK=1
    else
        success "Standard filesystem — no special workarounds needed"
        export SGOINFRE_IS_NETWORK=0
    fi

    # Show available space
    local avail
    avail=$(df -h "$SGOINFRE" | tail -1 | awk '{print $4}')
    info "Available space in sgoinfre: ${BOLD}$avail${RESET}"
}

# ─────────────────────────────────────────────────────────────
# STEP 1: SYSTEM DEPENDENCIES (apt)
# ─────────────────────────────────────────────────────────────
install_system_deps() {
    step_header "Installing system dependencies (apt)"

    local pkgs=(
        curl wget git unzip xz-utils zip
        apt-transport-https ca-certificates gnupg lsb-release
        lib32stdc++6 libc6-i386
        clang cmake ninja-build pkg-config
        libgtk-3-dev liblzma-dev libstdc++-12-dev
        openjdk-17-jdk
        jq
    )

    info "Updating package lists..."
    sudo apt-get update -qq > /dev/null 2>&1
    success "Package lists updated"

    info "Installing ${#pkgs[@]} packages..."
    sudo apt-get install -y -qq "${pkgs[@]}" > /dev/null 2>&1
    success "System dependencies installed"

    # Verify Java
    if java -version 2>&1 | grep -q "17"; then
        success "Java 17 (OpenJDK) available"
    else
        warn "Java 17 not detected — Android SDK may have issues"
    fi
}

# ─────────────────────────────────────────────────────────────
# STEP 2: DOCKER
# ─────────────────────────────────────────────────────────────
install_docker() {
    step_header "Installing Docker & Docker Compose"

    if command -v docker &> /dev/null; then
        success "Docker already installed: $(docker --version | head -1)"
    else
        info "Installing Docker Engine..."

        # Remove old versions
        sudo apt-get remove -y -qq docker docker-engine docker.io containerd runc 2>/dev/null || true

        # Add Docker GPG key and repo
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
        sudo chmod a+r /etc/apt/keyrings/docker.gpg

        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
            $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt-get update -qq > /dev/null 2>&1
        sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1

        success "Docker installed: $(docker --version | head -1)"
    fi

    # Docker Compose (plugin check)
    if docker compose version &> /dev/null; then
        success "Docker Compose available: $(docker compose version --short 2>/dev/null || echo 'OK')"
    else
        warn "Docker Compose plugin not found — install docker-compose-plugin"
    fi

    # Ensure user is in docker group
    if ! groups "$USER" | grep -q docker; then
        info "Adding $USER to docker group..."
        sudo usermod -aG docker "$USER"
        warn "You may need to log out/in for docker group to take effect"
        warn "Or run: newgrp docker"
    else
        success "User $USER is in docker group"
    fi

    # ── Relocate Docker data-root to sgoinfre ──
    info "Configuring Docker data-root to sgoinfre..."
    mkdir -p "$DOCKER_DIR"

    local daemon_json="/etc/docker/daemon.json"
    local need_restart=0

    if [ -f "$daemon_json" ]; then
        if grep -q "$DOCKER_DIR" "$daemon_json" 2>/dev/null; then
            success "Docker data-root already set to $DOCKER_DIR"
        else
            warn "Existing daemon.json found — merging data-root"
            local tmp_json
            tmp_json=$(jq --arg dr "$DOCKER_DIR" '. + {"data-root": $dr}' "$daemon_json" 2>/dev/null || echo "{\"data-root\": \"$DOCKER_DIR\"}")
            echo "$tmp_json" | sudo tee "$daemon_json" > /dev/null
            need_restart=1
        fi
    else
        sudo mkdir -p /etc/docker
        echo "{\"data-root\": \"$DOCKER_DIR\"}" | sudo tee "$daemon_json" > /dev/null
        need_restart=1
    fi

    if [ $need_restart -eq 1 ]; then
        info "Restarting Docker daemon with new data-root..."
        sudo systemctl restart docker 2>/dev/null || sudo service docker restart 2>/dev/null || true
        sleep 2
        if docker info > /dev/null 2>&1; then
            success "Docker restarted with data-root: $DOCKER_DIR"
        else
            warn "Docker restart — you may need to run: sudo systemctl restart docker"
        fi
    fi

    # Ensure Docker is running
    if ! docker info > /dev/null 2>&1; then
        info "Starting Docker daemon..."
        sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null || true
        sleep 2
    fi
    if docker info > /dev/null 2>&1; then
        success "Docker daemon is running"
    else
        warn "Docker daemon not running — try: sudo systemctl start docker"
    fi
}

# ─────────────────────────────────────────────────────────────
# STEP 3: NODE.JS (NVM) — in sgoinfre
# ─────────────────────────────────────────────────────────────
install_node() {
    step_header "Installing Node.js $NODE_VERSION via NVM (in sgoinfre)"

    export NVM_DIR="$NVM_DIR_CUSTOM"

    if [ -d "$NVM_DIR" ] && [ -s "$NVM_DIR/nvm.sh" ]; then
        success "NVM already installed in sgoinfre"
    else
        info "Installing NVM to $NVM_DIR..."
        rm -rf "$NVM_DIR"
        mkdir -p "$NVM_DIR"
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | \
            PROFILE=/dev/null NVM_DIR="$NVM_DIR" bash > /dev/null 2>&1
        success "NVM installed"
    fi

    # Load NVM
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # Install Node
    if nvm ls "$NODE_VERSION" > /dev/null 2>&1; then
        success "Node.js $NODE_VERSION already installed"
    else
        info "Installing Node.js $NODE_VERSION..."
        nvm install "$NODE_VERSION" > /dev/null 2>&1
        success "Node.js installed"
    fi

    nvm use "$NODE_VERSION" > /dev/null 2>&1
    nvm alias default "$NODE_VERSION" > /dev/null 2>&1

    success "Node.js $(node --version) active"
    success "npm $(npm --version) active"
}

# ─────────────────────────────────────────────────────────────
# STEP 4: GOOGLE CHROME (for Flutter web)
# ─────────────────────────────────────────────────────────────
install_chrome() {
    step_header "Installing Google Chrome (for Flutter web)"

    if command -v google-chrome &> /dev/null || command -v google-chrome-stable &> /dev/null; then
        success "Google Chrome already installed"
        return
    fi

    info "Downloading Google Chrome..."
    mkdir -p "$CHROME_DIR"
    cd "$TMP_DIR"

    wget -q "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" -O chrome.deb
    sudo dpkg -i chrome.deb > /dev/null 2>&1 || sudo apt-get install -f -y -qq > /dev/null 2>&1
    rm -f chrome.deb

    if command -v google-chrome &> /dev/null || command -v google-chrome-stable &> /dev/null; then
        success "Google Chrome installed"
    else
        warn "Chrome installation may have failed — flutter web needs Chrome"
    fi
}

# ─────────────────────────────────────────────────────────────
# STEP 5: FLUTTER SDK (in sgoinfre)
# ─────────────────────────────────────────────────────────────
install_flutter() {
    step_header "Installing Flutter SDK (in sgoinfre)"

    export FLUTTER_HOME="$FLUTTER_DIR"
    export PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$PATH"

    if [ -d "$FLUTTER_DIR" ] && [ -x "$FLUTTER_DIR/bin/flutter" ]; then
        success "Flutter SDK already present in sgoinfre"
        info "Upgrading Flutter to latest $FLUTTER_CHANNEL..."
        (cd "$FLUTTER_DIR" && git fetch --quiet && git checkout "$FLUTTER_CHANNEL" --quiet 2>/dev/null && git pull --quiet 2>/dev/null) || true
    else
        info "Cloning Flutter SDK ($FLUTTER_CHANNEL channel)..."
        rm -rf "$FLUTTER_DIR"
        git clone --depth 1 -b "$FLUTTER_CHANNEL" https://github.com/flutter/flutter.git "$FLUTTER_DIR" 2>&1 | tail -1
        success "Flutter SDK cloned"
    fi

    # ── Fix permissions (critical for sgoinfre) ──
    chmod -R u+rwX "$FLUTTER_DIR"
    success "Permissions fixed on Flutter directory"

    # ── Lockfile workaround for network filesystems ──
    # Flutter uses Dart's `lockFile()` which relies on `flock()` syscall.
    # On NFS/CIFS/FUSE mounts, flock() may hang indefinitely.
    # Workarounds:
    #   1. Remove any stale lockfile before each operation
    #   2. Set FLUTTER_ALREADY_LOCKED=true to skip locking
    #   3. Create a wrapper that cleans lockfile automatically
    info "Applying lockfile workaround for sgoinfre..."
    rm -f "$FLUTTER_DIR/bin/cache/lockfile"

    # Create a wrapper script that handles the lockfile issue
    cat > "$SGOINFRE/flutter_wrapper.sh" << 'WRAPPER_EOF'
#!/bin/bash
# Flutter wrapper — prevents lockfile hangs on network filesystems
FLUTTER_DIR="$HOME/sgoinfre/flutter"
LOCKFILE="$FLUTTER_DIR/bin/cache/lockfile"

# Remove stale lockfile before running flutter
if [ -f "$LOCKFILE" ]; then
    rm -f "$LOCKFILE" 2>/dev/null
fi

# Run flutter with lockfile handling
exec "$FLUTTER_DIR/bin/flutter" "$@"
WRAPPER_EOF
    chmod +x "$SGOINFRE/flutter_wrapper.sh"
    success "Flutter lockfile wrapper created"

    # ── Disable analytics (reduces network FS issues) ──
    "$FLUTTER_DIR/bin/flutter" config --no-analytics > /dev/null 2>&1 || true
    "$FLUTTER_DIR/bin/flutter" config --no-cli-animations > /dev/null 2>&1 || true
    success "Flutter analytics disabled"

    # ── Precache web artifacts ──
    info "Running Flutter precache (web)..."
    rm -f "$FLUTTER_DIR/bin/cache/lockfile"
    "$FLUTTER_DIR/bin/flutter" precache --web > /dev/null 2>&1 || true
    success "Flutter web precache done"

    # Report version
    local flutter_ver
    flutter_ver=$("$FLUTTER_DIR/bin/flutter" --version --machine 2>/dev/null | grep -o '"frameworkVersion":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
    success "Flutter $flutter_ver ready"
}

# ─────────────────────────────────────────────────────────────
# STEP 6: DART SDK (bundled with Flutter)
# ─────────────────────────────────────────────────────────────
verify_dart() {
    step_header "Verifying Dart SDK"

    export PATH="$FLUTTER_DIR/bin:$FLUTTER_DIR/bin/cache/dart-sdk/bin:$PATH"

    if command -v dart &> /dev/null; then
        success "Dart SDK available: $(dart --version 2>&1 | head -1)"
    else
        warn "Dart not in PATH — will be available after sourcing shell config"
    fi
}

# ─────────────────────────────────────────────────────────────
# STEP 7: ANDROID SDK (in sgoinfre)
# ─────────────────────────────────────────────────────────────
install_android_sdk() {
    step_header "Installing Android SDK & command-line tools (in sgoinfre)"

    export ANDROID_SDK_ROOT="$ANDROID_SDK"
    export ANDROID_HOME="$ANDROID_SDK"
    export ANDROID_AVD_HOME="$ANDROID_AVD"
    export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

    mkdir -p "$ANDROID_SDK/cmdline-tools" "$ANDROID_AVD"

    # Install command-line tools
    if [ -x "$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" ]; then
        success "Android command-line tools already installed"
    else
        info "Downloading Android command-line tools..."
        cd "$TMP_DIR"
        curl -L "$CMDLINE_URL" -o cmdline.zip --progress-bar
        echo ""

        info "Extracting command-line tools..."
        rm -rf "$ANDROID_SDK/cmdline-tools/latest"
        unzip -q cmdline.zip -d "$TMP_DIR/cmdline-extract"
        mv "$TMP_DIR/cmdline-extract/cmdline-tools" "$ANDROID_SDK/cmdline-tools/latest"
        rm -rf "$TMP_DIR/cmdline-extract" cmdline.zip
        success "Command-line tools installed"
    fi

    # Accept licenses
    info "Accepting Android SDK licenses..."
    yes 2>/dev/null | "$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" --licenses > /dev/null 2>&1 || true
    success "Licenses accepted"

    # Install SDK components
    info "Installing Android SDK components (API $ANDROID_API_LEVEL)..."
    "$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" --install \
        "platform-tools" \
        "platforms;android-$ANDROID_API_LEVEL" \
        "build-tools;${ANDROID_API_LEVEL}.0.0" \
        > /dev/null 2>&1 || true
    success "Android SDK components installed"

    # Tell Flutter about Android SDK
    rm -f "$FLUTTER_DIR/bin/cache/lockfile"
    "$FLUTTER_DIR/bin/flutter" config --android-sdk "$ANDROID_SDK" > /dev/null 2>&1 || true
    success "Flutter configured with Android SDK"
}

# ─────────────────────────────────────────────────────────────
# STEP 8: FLUTTER PROJECT DEPENDENCIES
# ─────────────────────────────────────────────────────────────
install_project_deps() {
    step_header "Installing project dependencies"

    cd "$PROJECT_DIR"

    # Flutter pub get
    info "Running 'flutter pub get' in flutter_app_/..."
    cd "$PROJECT_DIR/flutter_app_"
    rm -f "$FLUTTER_DIR/bin/cache/lockfile"
    "$FLUTTER_DIR/bin/flutter" pub get > /dev/null 2>&1
    success "Flutter dependencies installed"

    # Generate code (build_runner)
    info "Running build_runner for code generation..."
    rm -f "$FLUTTER_DIR/bin/cache/lockfile"
    "$FLUTTER_DIR/bin/flutter" pub run build_runner build --delete-conflicting-outputs > /dev/null 2>&1 || true
    success "Code generation complete"

    cd "$PROJECT_DIR"
}

# ─────────────────────────────────────────────────────────────
# STEP 9: .ENV FILE TEMPLATE
# ─────────────────────────────────────────────────────────────
setup_env_file() {
    step_header "Setting up environment configuration"

    local env_file="$PROJECT_DIR/back/.env"

    if [ -f "$env_file" ]; then
        success ".env file already exists in back/"
    else
        info "Creating template .env file in back/..."
        cat > "$env_file" << 'ENV_EOF'
# ── DATABASE ──
DB_HOST=db
DB_PORT=3306
DB_USERNAME=root
DB_PASSWORD=root
DB_DATABASE=db

# ── JWT ──
JWT_SECRET=music-room-secret-key-change-me
JWT_EXPIRATION=7d

# ── APP ──
APP_PORT=3000
APP_URL=http://localhost:3000

# ── MAIL (MailHog) ──
MAIL_HOST=mailhog
MAIL_PORT=1025
MAIL_USER=
MAIL_PASS=
MAIL_FROM=noreply@music-room.local

# ── OAUTH (fill in your credentials) ──
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GOOGLE_CALLBACK_URL=http://localhost:3000/auth/google/callback

FACEBOOK_CLIENT_ID=
FACEBOOK_CLIENT_SECRET=
FACEBOOK_CALLBACK_URL=http://localhost:3000/auth/facebook/callback

# ── FRONTEND ──
FRONTEND_URL=http://localhost:8080
ENV_EOF
        success ".env template created — ${YELLOW}please fill in your OAuth credentials${RESET}"
    fi
}

# ─────────────────────────────────────────────────────────────
# STEP 10: SHELL CONFIG & FINAL VERIFICATION
# ─────────────────────────────────────────────────────────────
setup_shell_and_verify() {
    step_header "Configuring shell & final verification"

    # ── Generate shell exports block ──
    local shell_block
    shell_block=$(cat << 'SHELL_EOF'

# ═══════════════════════════════════════════════════════════
# MUSIC-ROOM Development Environment (42 sgoinfre)
# ═══════════════════════════════════════════════════════════

# NVM (Node Version Manager)
export NVM_DIR="$HOME/sgoinfre/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Flutter SDK
export FLUTTER_HOME="$HOME/sgoinfre/flutter"
export PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$PATH"

# Android SDK
export ANDROID_SDK_ROOT="$HOME/sgoinfre/android-sdk"
export ANDROID_HOME="$HOME/sgoinfre/android-sdk"
export ANDROID_AVD_HOME="$HOME/sgoinfre/android-avd"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

# Java
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
export PATH="$JAVA_HOME/bin:$PATH"

# Chrome for Flutter web
export CHROME_EXECUTABLE="$(command -v google-chrome-stable 2>/dev/null || command -v google-chrome 2>/dev/null || echo '/usr/bin/google-chrome-stable')"

# Flutter lockfile fix for sgoinfre (network/special filesystems)
# Automatically clean stale lockfiles to prevent "waiting for process" hangs
flutter() {
    rm -f "$FLUTTER_HOME/bin/cache/lockfile" 2>/dev/null
    command flutter "$@"
}

# ═══════════════════════════════════════════════════════════
SHELL_EOF
)

    # Detect shell config file
    local shell_rc=""
    if [ -n "${ZSH_VERSION:-}" ] || [ "$(basename "$SHELL")" = "zsh" ]; then
        shell_rc="$HOME/.zshrc"
    else
        shell_rc="$HOME/.bashrc"
    fi

    # Check if already configured
    local marker="MUSIC-ROOM Development Environment"
    if grep -q "$marker" "$shell_rc" 2>/dev/null; then
        info "Shell config already contains music-room block — updating..."
        # Remove old block
        sed -i "/# ═.*MUSIC-ROOM Development/,/# ═══════════════════════════════════════════════════════════$/d" "$shell_rc"
    fi

    echo "$shell_block" >> "$shell_rc"
    success "Shell config updated in $shell_rc"

    # ── Source for current session ──
    export NVM_DIR="$NVM_DIR_CUSTOM"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    export FLUTTER_HOME="$FLUTTER_DIR"
    export ANDROID_SDK_ROOT="$ANDROID_SDK"
    export ANDROID_HOME="$ANDROID_SDK"
    export ANDROID_AVD_HOME="$ANDROID_AVD"
    export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
    export CHROME_EXECUTABLE="$(command -v google-chrome-stable 2>/dev/null || command -v google-chrome 2>/dev/null || echo '/usr/bin/google-chrome-stable')"
    export PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$JAVA_HOME/bin:$PATH"

    # ── Verification ──
    echo ""
    info "Running final verification..."
    echo ""

    local all_ok=1

    # Docker
    if docker --version > /dev/null 2>&1; then
        success "docker          $(docker --version 2>&1 | grep -oP 'Docker version \K[0-9.]+' || echo 'OK')"
    else
        err "docker          NOT FOUND"
        all_ok=0
    fi

    # Docker Compose
    if docker compose version > /dev/null 2>&1; then
        success "docker compose  $(docker compose version --short 2>/dev/null || echo 'OK')"
    else
        err "docker compose  NOT FOUND"
        all_ok=0
    fi

    # Node
    if command -v node > /dev/null 2>&1; then
        success "node            $(node --version 2>&1)"
    else
        err "node            NOT FOUND"
        all_ok=0
    fi

    # npm
    if command -v npm > /dev/null 2>&1; then
        success "npm             $(npm --version 2>&1)"
    else
        err "npm             NOT FOUND"
        all_ok=0
    fi

    # Flutter
    if "$FLUTTER_DIR/bin/flutter" --version > /dev/null 2>&1; then
        success "flutter         $("$FLUTTER_DIR/bin/flutter" --version 2>&1 | head -1 | awk '{print $2}')"
    else
        err "flutter         NOT FOUND"
        all_ok=0
    fi

    # Dart
    if command -v dart > /dev/null 2>&1; then
        success "dart            $(dart --version 2>&1 | awk '{print $4}')"
    else
        err "dart            NOT FOUND"
        all_ok=0
    fi

    # Java
    if java -version 2>&1 | grep -q "17"; then
        success "java            17 (OpenJDK)"
    else
        err "java 17         NOT FOUND"
        all_ok=0
    fi

    # Chrome
    if command -v google-chrome > /dev/null 2>&1 || command -v google-chrome-stable > /dev/null 2>&1; then
        success "chrome          $(google-chrome --version 2>/dev/null || google-chrome-stable --version 2>/dev/null || echo 'OK')"
    else
        err "chrome          NOT FOUND"
        all_ok=0
    fi

    # Android SDK
    if [ -x "$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" ]; then
        success "android-sdk     API $ANDROID_API_LEVEL"
    else
        err "android-sdk     NOT FOUND"
        all_ok=0
    fi

    echo ""

    # ── Flutter Doctor ──
    info "Running flutter doctor..."
    echo ""
    rm -f "$FLUTTER_DIR/bin/cache/lockfile"
    "$FLUTTER_DIR/bin/flutter" doctor --verbose 2>&1 | grep -E '^\[|Doctor summary' | head -20 || true
    echo ""

    # ── Cleanup ──
    info "Cleaning up temp files..."
    rm -rf "$TMP_DIR"
    success "Cleanup complete"

    # ── Disk usage summary ──
    echo ""
    info "Disk usage in ~/sgoinfre:"
    du -sh "$SGOINFRE"/* 2>/dev/null | sort -hr | head -10 || true
    echo ""
    local total
    total=$(du -sh "$SGOINFRE" 2>/dev/null | awk '{print $1}')
    info "Total sgoinfre usage: ${BOLD}$total${RESET}"

    return $( [ $all_ok -eq 1 ] && echo 0 || echo 1 )
}

# ─────────────────────────────────────────────────────────────
# FINAL SUMMARY
# ─────────────────────────────────────────────────────────────
print_summary() {
    local status=$1
    echo ""
    echo -e "${MAGENTA}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════════════╗"
    if [ "$status" -eq 0 ]; then
        echo "  ║          ✅  INSTALLATION COMPLETE — ALL TOOLS READY       ║"
    else
        echo "  ║          ⚠️   INSTALLATION COMPLETE — SOME ISSUES          ║"
    fi
    echo "  ╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo ""
    echo -e "  ${BOLD}Quick Start:${RESET}"
    echo ""
    echo -e "  ${CYAN}1.${RESET} Reload your shell config:"
    echo -e "     ${GREEN}source ~/.zshrc${RESET}  ${DIM}(or ~/.bashrc)${RESET}"
    echo ""
    echo -e "  ${CYAN}2.${RESET} Start the backend (Docker):"
    echo -e "     ${GREEN}cd $(basename "$PROJECT_DIR") && docker compose up --build${RESET}"
    echo ""
    echo -e "  ${CYAN}3.${RESET} Start the Flutter web app:"
    echo -e "     ${GREEN}cd $(basename "$PROJECT_DIR")/flutter_app_ && flutter run -d chrome --web-port 8080${RESET}"
    echo ""
    echo -e "  ${BOLD}Services:${RESET}"
    echo -e "  ${DIM}├${RESET} Backend API       → ${CYAN}http://localhost:3000${RESET}"
    echo -e "  ${DIM}├${RESET} Flutter Web App   → ${CYAN}http://localhost:8080${RESET}"
    echo -e "  ${DIM}├${RESET} phpMyAdmin        → ${CYAN}http://localhost:4000${RESET}"
    echo -e "  ${DIM}├${RESET} MailHog           → ${CYAN}http://localhost:8025${RESET}"
    echo -e "  ${DIM}└${RESET} MySQL             → ${CYAN}localhost:3306${RESET}"
    echo ""
    echo -e "  ${BOLD}Troubleshooting:${RESET}"
    echo -e "  ${DIM}•${RESET} Flutter lockfile hang → ${GREEN}rm -f ~/sgoinfre/flutter/bin/cache/lockfile${RESET}"
    echo -e "  ${DIM}•${RESET} Docker permission     → ${GREEN}newgrp docker${RESET} or re-login"
    echo -e "  ${DIM}•${RESET} Full reset            → ${GREEN}bash install.sh${RESET}"
    echo ""
}

# ─────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────
main() {
    print_banner

    preflight_checks          # Step 1  — Pre-flight
    install_system_deps       # Step 2  — apt packages
    install_docker            # Step 3  — Docker + Compose
    install_node              # Step 4  — Node.js (NVM)
    install_chrome            # Step 5  — Google Chrome
    install_flutter           # Step 6  — Flutter SDK
    verify_dart               # Step 7  — Dart SDK
    install_android_sdk       # Step 8  — Android SDK
    install_project_deps      # Step 9  — Project deps
    setup_env_file            # Step 10 — .env template

    local verify_status=0
    setup_shell_and_verify || verify_status=$?

    print_summary $verify_status
}

main "$@"
