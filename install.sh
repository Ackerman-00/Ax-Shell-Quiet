#!/bin/bash

set -e  # Exit immediately if a command fails
set -u  # Treat unset variables as errors
set -o pipefail  # Prevent errors in a pipeline from being masked

REPO_URL="https://github.com/Ackerman-00/Ax-Shell-Quiet.git"
INSTALL_DIR="$HOME/.config/Ax-Shell"

# Package list for PikaOS - Debian package names
PACKAGES=(
    brightnessctl
    cava
    cliphist
    libgnome-bluetooth-3.0-13
    gobject-introspection
    gpu-screen-recorder
    hypridle
    hyprlock
    libnotify-bin
    matugen
    network-manager-applet
    nm-connection-editor
    fonts-noto
    fonts-noto-core
    fonts-noto-extra
    fonts-noto-ui-core
    fonts-noto-unhinted
    fonts-noto-color-emoji
    fonts-noto-mono
    nvtop
    playerctl
    power-profiles-daemon
    swappy
    swww
    tesseract-ocr
    tesseract-ocr-eng
    tesseract-ocr-spa
    tmux
    unzip
    upower
    libvte-2.91-0
    gir1.2-vte-2.91
    webp-pixbuf-loader
    wl-clipboard
    # Hyprshot dependencies
    jq
    grim
    slurp
    # Hypr tools
    libhyprlang-dev
    libhyprutils-dev
    hyprwayland-scanner
    # Image manipulation
    imagemagick
    # Gray dependencies
    libdbusmenu-gtk3-dev
    # Fabric dependencies (Debian versions)
    libgtk-layer-shell0
    libgtk-layer-shell-dev
    libwebkit2gtk-4.1-0
    gir1.2-webkit2-4.1
    # Python pip
    python3-pip
)

# Python packages for Ax-Shell (exactly as specified by dev)
PYTHON_PACKAGES=(
    python3-gobject
    python3-ijson
    python3-numpy
    python3-pil
    python3-psutil
    python3-pywayland
    python3-requests
    python3-setproctitle
    python3-toml
    python3-watchdog
)

# Build dependencies for tools that need compilation
BUILD_PACKAGES=(
    build-essential
    cmake
    git
    meson
    ninja-build
    pkg-config
    # Vala for Gray
    valac
    libjson-glib-dev
    libgtk-3-dev
    # Additional dependencies for hyprpicker
    libcairo2-dev
    libpango1.0-dev
    libjpeg-dev
    libwayland-dev
    wayland-protocols
    libxkbcommon-dev
    # Python build dependencies for Fabric
    python3-setuptools
    python3-wheel
    python3-build
    python3-installer
)

# Fabric Python dependencies
FABRIC_PYTHON_DEPS=(
    loguru
    click
)

# Prevent running as root
if [ "$(id -u)" -eq 0 ]; then
    echo "Please do not run this script as root."
    exit 1
fi

echo "Starting Ax-Shell installation for PikaOS..."
echo "=============================================="

# Update package lists
echo "Updating package lists..."
sudo apt update

# Install packages in batches
echo "Installing system packages..."
sudo apt install -y "${PACKAGES[@]}"

echo "Installing Python packages..."
sudo apt install -y "${PYTHON_PACKAGES[@]}"

echo "Installing build dependencies..."
sudo apt install -y "${BUILD_PACKAGES[@]}"

# Create necessary directories
echo "Creating necessary directories..."
mkdir -p "$HOME/.local/src"
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.fonts"
mkdir -p "$HOME/.local/lib/python3.12/site-packages"

# --- Install Fabric from Source (AUR-style) ---
echo "Building and installing Fabric from source (AUR-style)..."

FABRIC_DIR="$HOME/.local/src/fabric"
if [ -d "$FABRIC_DIR" ]; then
    echo "Updating Fabric repository..."
    git -C "$FABRIC_DIR" pull || echo "Git pull failed, continuing with existing code..."
else
    echo "Cloning Fabric repository..."
    git clone --depth=1 https://github.com/Fabric-Development/fabric.git "$FABRIC_DIR"
fi

# Install Fabric Python dependencies first
echo "Installing Fabric Python dependencies..."
pip3 install --user "${FABRIC_PYTHON_DEPS[@]}"

# Build and install Fabric using AUR-style approach
cd "$FABRIC_DIR"
echo "Building Fabric with Python build system..."

# Get version info (AUR-style)
FABRIC_VERSION="r$(git rev-list --count HEAD).$(git rev-parse --short=7 HEAD)"
echo "Building Fabric version: $FABRIC_VERSION"

# Build the wheel
if python3 -m build --wheel --no-isolation; then
    # Install the wheel
    WHEEL_FILE=$(ls dist/*.whl | head -n1)
    if [ -n "$WHEEL_FILE" ]; then
        pip3 install --user "$WHEEL_FILE"
        echo "✅ Fabric $FABRIC_VERSION installed successfully"
    else
        echo "❌ No wheel file found for Fabric"
        # Fallback: install directly
        pip3 install --user .
    fi
else
    echo "❌ Fabric build failed, trying direct installation..."
    pip3 install --user .
fi

# --- Install fabric-cli ---
echo "Installing fabric-cli..."

FABRIC_CLI_DIR="$HOME/.local/src/fabric-cli"
if [ -d "$FABRIC_CLI_DIR" ]; then
    echo "Updating fabric-cli repository..."
    git -C "$FABRIC_CLI_DIR" pull || echo "Git pull failed, continuing with existing code..."
else
    echo "Cloning fabric-cli repository..."
    git clone --depth=1 https://github.com/Fabric-Development/fabric-cli.git "$FABRIC_CLI_DIR"
fi

# Install fabric-cli
cd "$FABRIC_CLI_DIR"
pip3 install --user .

echo "✅ fabric-cli installed successfully"

# --- Build and Install Hyprpicker from Source ---
echo "Building and installing Hyprpicker from source..."

HYPRPICKER_DIR="$HOME/.local/src/hyprpicker"
if [ -d "$HYPRPICKER_DIR" ]; then
    echo "Updating Hyprpicker repository..."
    git -C "$HYPRPICKER_DIR" pull || echo "Git pull failed, continuing with existing code..."
else
    echo "Cloning Hyprpicker repository..."
    git clone --depth=1 https://github.com/hyprwm/hyprpicker.git "$HYPRPICKER_DIR"
fi

# Build and install Hyprpicker
cd "$HYPRPICKER_DIR"
if [ -f "CMakeLists.txt" ]; then
    echo "Building Hyprpicker with CMake..."
    if cmake -B build -S . -DCMAKE_BUILD_TYPE=Release && \
       cmake --build build && \
       sudo cmake --install build; then
        echo "✅ Hyprpicker installed successfully"
    else
        echo "❌ Hyprpicker installation failed"
    fi
else
    echo "No CMakeLists.txt found for Hyprpicker"
fi

# --- Install Hyprshot ---
echo "Installing Hyprshot..."

HYPRSHOT_DIR="$HOME/.local/src/hyprshot"
if [ -d "$HYPRSHOT_DIR" ]; then
    echo "Updating Hyprshot repository..."
    git -C "$HYPRSHOT_DIR" pull || echo "Git pull failed, continuing with existing code..."
else
    echo "Cloning Hyprshot repository..."
    git clone --depth=1 https://github.com/Gustash/Hyprshot.git "$HYPRSHOT_DIR"
fi

# Install Hyprshot script
echo "Installing Hyprshot script..."
mkdir -p "$HOME/.local/bin"
cp "$HYPRSHOT_DIR/hyprshot" "$HOME/.local/bin/hyprshot"
chmod +x "$HOME/.local/bin/hyprshot"

echo "✅ Hyprshot has been installed to $HOME/.local/bin/hyprshot"

# --- Install Hyprsunset from Source ---
echo "Installing Hyprsunset from source..."

HYPRSUNSET_DIR="$HOME/.local/src/hyprsunset"
if [ -d "$HYPRSUNSET_DIR" ]; then
    echo "Updating Hyprsunset repository..."
    git -C "$HYPRSUNSET_DIR" pull || echo "Git pull failed, continuing with existing code..."
else
    echo "Cloning Hyprsunset repository..."
    git clone --depth=1 https://github.com/hyprwm/hyprsunset.git "$HYPRSUNSET_DIR"
fi

# Build and install Hyprsunset
cd "$HYPRSUNSET_DIR"
if [ -f "CMakeLists.txt" ]; then
    echo "Building Hyprsunset with CMake..."
    if cmake -B build -S . -DCMAKE_BUILD_TYPE=Release && \
       cmake --build build && \
       sudo cmake --install build; then
        echo "✅ Hyprsunset installed successfully"
    else
        echo "❌ Hyprsunset installation failed"
    fi
else
    echo "No CMakeLists.txt found for Hyprsunset"
fi

# --- Install Gray from Source ---
echo "Installing Gray from source..."

GRAY_DIR="$HOME/.local/src/gray"
if [ -d "$GRAY_DIR" ]; then
    echo "Updating Gray repository..."
    git -C "$GRAY_DIR" pull || echo "Git pull failed, continuing with existing code..."
else
    echo "Cloning Gray repository..."
    git clone --depth=1 https://github.com/Fabric-Development/gray.git "$GRAY_DIR"
fi

# Build and install Gray
cd "$GRAY_DIR"
if [ -f "meson.build" ]; then
    echo "Building Gray with meson..."
    if meson setup build --prefix=/usr --buildtype=release && \
       ninja -C build && \
       sudo ninja -C build install; then
        echo "✅ Gray installed successfully"
    else
        echo "❌ Gray build/install failed, but continuing..."
    fi
else
    echo "No meson.build found for Gray"
fi

# --- Install Nerd Fonts Symbols ---
echo "Installing Nerd Fonts Symbols..."

NERD_FONTS_VERSION="3.4.0"
NERD_FONTS_DIR="$HOME/.local/src/nerd-fonts-symbols"
mkdir -p "$NERD_FONTS_DIR"

# Download font files
echo "Downloading Nerd Fonts Symbols..."
curl -L -o "$NERD_FONTS_DIR/SymbolsNerdFont-Regular.ttf" \
    "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/v$NERD_FONTS_VERSION/patched-fonts/NerdFontsSymbolsOnly/SymbolsNerdFont-Regular.ttf"

curl -L -o "$NERD_FONTS_DIR/SymbolsNerdFontMono-Regular.ttf" \
    "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/v$NERD_FONTS_VERSION/patched-fonts/NerdFontsSymbolsOnly/SymbolsNerdFontMono-Regular.ttf"

# Install fonts to user directory
echo "Installing Nerd Fonts to user directory..."
cp "$NERD_FONTS_DIR/SymbolsNerdFont-Regular.ttf" "$HOME/.fonts/"
cp "$NERD_FONTS_DIR/SymbolsNerdFontMono-Regular.ttf" "$HOME/.fonts/"

# Update font cache
echo "Updating font cache..."
fc-cache -fv

echo "✅ Nerd Fonts Symbols have been installed to user directory."

# --- Clone or update Ax-Shell ---
echo "Setting up Ax-Shell..."

if [ -d "$INSTALL_DIR" ]; then
    echo "Updating Ax-Shell (Quiet fork)..."
    git -C "$INSTALL_DIR" pull || echo "Git pull failed, continuing with existing code..."
else
    echo "Cloning Ax-Shell (Quiet fork)..."
    git clone --depth=1 "$REPO_URL" "$INSTALL_DIR"
fi

# --- Install Zed Sans fonts ---
echo "Installing Zed Sans fonts..."

FONT_URL="https://github.com/zed-industries/zed-fonts/releases/download/1.2.0/zed-sans-1.2.0.zip"
FONT_DIR="$HOME/.fonts/zed-sans"
TEMP_ZIP="/tmp/zed-sans-1.2.0.zip"

if [ ! -d "$FONT_DIR" ]; then
    echo "Downloading Zed Sans fonts..."
    curl -L -o "$TEMP_ZIP" "$FONT_URL"

    echo "Extracting fonts..."
    mkdir -p "$FONT_DIR"
    unzip -o "$TEMP_ZIP" -d "$FONT_DIR"

    echo "Cleaning up..."
    rm "$TEMP_ZIP"
    echo "✅ Zed Sans fonts installed successfully"
else
    echo "✅ Zed Sans fonts are already installed."
fi

# --- Network services configuration ---
echo "Configuring network services..."

# Disable iwd if enabled/active
if systemctl is-enabled --quiet iwd 2>/dev/null || systemctl is-active --quiet iwd 2>/dev/null; then
    echo "Disabling iwd..."
    sudo systemctl disable --now iwd 2>/dev/null || echo "Could not disable iwd"
else
    echo "✅ iwd is not enabled or not present."
fi

# Enable NetworkManager if not enabled
if ! systemctl is-enabled --quiet NetworkManager 2>/dev/null; then
    echo "Enabling NetworkManager..."
    sudo systemctl enable NetworkManager 2>/dev/null || echo "Could not enable NetworkManager"
else
    echo "✅ NetworkManager is already enabled."
fi

# Start NetworkManager if not running
if ! systemctl is-active --quiet NetworkManager 2>/dev/null; then
    echo "Starting NetworkManager..."
    sudo systemctl start NetworkManager 2>/dev/null || echo "Could not start NetworkManager"
else
    echo "✅ NetworkManager is already running."
fi

# --- Copy local fonts from Ax-Shell ---
echo "Copying Ax-Shell fonts..."

if [ -d "$INSTALL_DIR/assets/fonts" ] && [ ! -d "$HOME/.fonts/tabler-icons" ]; then
    echo "Copying local fonts to $HOME/.fonts/tabler-icons..."
    mkdir -p "$HOME/.fonts/tabler-icons"
    cp -r "$INSTALL_DIR/assets/fonts/"* "$HOME/.fonts/" 2>/dev/null || echo "Some fonts could not be copied"
    echo "✅ Ax-Shell fonts copied successfully"
else
    echo "✅ Local fonts are already installed or not available."
fi

# --- Update PATH if needed ---
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo "Adding ~/.local/bin to PATH in .bashrc..."
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    export PATH="$HOME/.local/bin:$PATH"
fi

# Add Python user site to PATH if needed
PYTHON_USER_BIN=$(python3 -m site --user-base)/bin
if [ -d "$PYTHON_USER_BIN" ] && [[ ":$PATH:" != *":$PYTHON_USER_BIN:"* ]]; then
    echo "Adding Python user bin to PATH in .bashrc..."
    echo "export PATH=\"$PYTHON_USER_BIN:\$PATH\"" >> "$HOME/.bashrc"
    export PATH="$PYTHON_USER_BIN:$PATH"
fi

# --- Update font cache again after all font installations ---
echo "Updating font cache after all font installations..."
fc-cache -fv

# --- Install Python requirements for Ax-Shell ---
echo "Installing Python requirements for Ax-Shell..."

if [ -f "$INSTALL_DIR/requirements.txt" ]; then
    echo "Installing requirements from requirements.txt..."
    pip3 install --user -r "$INSTALL_DIR/requirements.txt" || echo "Failed to install some Python requirements"
else
    echo "No requirements.txt found, installing common dependencies..."
    pip3 install --user psutil requests watchdog ijson toml setproctitle pywayland || echo "Failed to install some Python packages"
fi

# --- Final steps ---
echo "Finalizing installation..."

# Verify critical components
echo "Verifying installation..."
MISSING_COMPONENTS=()

# Check if Hyprshot was installed
if [ ! -f "$HOME/.local/bin/hyprshot" ]; then
    MISSING_COMPONENTS+=("Hyprshot")
fi

# Check if Hyprpicker is available
if ! command -v hyprpicker >/dev/null 2>&1; then
    MISSING_COMPONENTS+=("Hyprpicker")
fi

# Check if Ax-Shell was cloned
if [ ! -d "$INSTALL_DIR" ]; then
    MISSING_COMPONENTS+=("Ax-Shell")
fi

# Check if Fabric is available
if ! python3 -c "import fabric" 2>/dev/null; then
    MISSING_COMPONENTS+=("Fabric")
fi

# Check if fabric-cli is available
if ! python3 -c "import fabric_cli" 2>/dev/null 2>&1; then
    MISSING_COMPONENTS+=("fabric-cli")
fi

# Check if Gray is available
if ! command -v gray >/dev/null 2>&1; then
    MISSING_COMPONENTS+=("Gray")
fi

if [ ${#MISSING_COMPONENTS[@]} -eq 0 ]; then
    echo "✅ All critical components installed successfully!"
else
    echo "⚠️  The following components failed to install: ${MISSING_COMPONENTS[*]}"
fi

# Run Ax-Shell configuration
if [ -f "$INSTALL_DIR/config/config.py" ]; then
    echo "Running Ax-Shell configuration..."
    cd "$INSTALL_DIR"
    if python3 "$INSTALL_DIR/config/config.py"; then
        echo "✅ Ax-Shell configuration completed successfully"
    else
        echo "❌ Configuration script failed"
        echo "You may need to install missing dependencies manually"
    fi
else
    echo "❌ Ax-Shell configuration script not found."
fi

# Kill any existing Ax-Shell instances
echo "Stopping any existing Ax-Shell instances..."
pkill -f "ax-shell" 2>/dev/null || true

# Start Ax-Shell using uwsm as per dev's instructions
echo "Starting Ax-Shell..."
if command -v uwsm >/dev/null 2>&1; then
    uwsm app -- python "$INSTALL_DIR/main.py" > /dev/null 2>&1 & disown
    echo "✅ Ax-Shell started with uwsm"
else
    # Fallback: start directly
    python3 "$INSTALL_DIR/main.py" > /dev/null 2>&1 &
    echo "✅ Ax-Shell started directly (uwsm not found)"
fi

echo ""
echo "=============================================="
echo "INSTALLATION COMPLETE!"
echo "=============================================="
echo ""
echo "Ax-Shell (Quiet fork) has been installed to: $INSTALL_DIR"
echo ""
echo "Components status:"
if command -v hyprpicker >/dev/null 2>&1; then echo "✅ Hyprpicker"; else echo "❌ Hyprpicker"; fi
if [ -f "$HOME/.local/bin/hyprshot" ]; then echo "✅ Hyprshot"; else echo "❌ Hyprshot"; fi
if command -v hyprsunset >/dev/null 2>&1; then echo "✅ Hyprsunset"; else echo "❌ Hyprsunset"; fi
if python3 -c "import fabric" 2>/dev/null; then echo "✅ Fabric"; else echo "❌ Fabric"; fi
if python3 -c "import fabric_cli" 2>/dev/null 2>&1; then echo "✅ fabric-cli"; else echo "❌ fabric-cli"; fi
if command -v gray >/dev/null 2>&1; then echo "✅ Gray"; else echo "❌ Gray"; fi
echo "✅ Hypridle & Hyprlock"
echo "✅ Nerd Fonts Symbols & Zed Sans fonts"
echo "✅ Network configuration"
echo ""
echo "Next steps:"
echo "1. Restart your terminal or run: source ~/.bashrc"
echo "2. Ax-Shell should be running automatically"
echo "3. Test components manually if needed:"
echo "   - hyprshot --help"
echo "   - hyprpicker --help"
echo "   - python3 -c 'import fabric; print(\"Fabric OK\")'"
echo "   - python3 -c 'import fabric_cli; print(\"fabric-cli OK\")'"
echo ""
echo "If any components failed, check the output above for errors."
echo "Enjoy using Ax-Shell! 🚀"
echo "=============================================="
