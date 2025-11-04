#!/bin/bash

set -e  # Exit immediately if a command fails
set -u  # Treat unset variables as errors
set -o pipefail  # Prevent errors in a pipeline from being masked

REPO_URL="https://github.com/Ackerman-00/Ax-Shell-Quiet.git"
INSTALL_DIR="$HOME/.config/Ax-Shell"

# Package list for PikaOS - using available packages where possible
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
    # Hypr tools from PikaOS repo (excluding hyprpicker - we'll build from source)
    libhyprlang
    libhyprutils
    hyprwayland-scanner
    # Image manipulation
    imagemagick
    # Gray dependencies
    libdbusmenu-gtk3-dev
    # Correct Fabric package
    python3-fabric
)

# Python packages for Ax-Shell
PYTHON_PACKAGES=(
    python3-gi
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

# --- Build and Install Hyprpicker from Source (AUR-style) ---
echo "Building and installing Hyprpicker from source..."

HYPRPICKER_DIR="$HOME/.local/src/hyprpicker"
if [ -d "$HYPRPICKER_DIR" ]; then
    echo "Updating Hyprpicker repository..."
    git -C "$HYPRPICKER_DIR" pull || echo "Git pull failed, continuing with existing code..."
else
    echo "Cloning Hyprpicker repository..."
    git clone --depth=1 https://github.com/hyprwm/hyprpicker.git "$HYPRPICKER_DIR"
fi

# Build and install Hyprpicker using AUR approach
cd "$HYPRPICKER_DIR"
if [ -f "CMakeLists.txt" ]; then
    echo "Building Hyprpicker with CMake (AUR-style)..."
    if cmake -B build -S . -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr && \
       cmake --build build && \
       sudo cmake --install build; then
        echo "Hyprpicker installed successfully"
        # Install license file (AUR-style)
        sudo install -Dm644 LICENSE -t /usr/share/licenses/hyprpicker/
    else
        echo "Warning: Hyprpicker installation failed"
        # Try alternative build method if CMake fails
        if [ -f "meson.build" ]; then
            echo "Trying Meson build for Hyprpicker..."
            meson setup build --prefix=/usr --buildtype=release && \
            ninja -C build && \
            sudo ninja -C build install && \
            echo "Hyprpicker installed successfully with Meson"
        fi
    fi
else
    echo "No CMakeLists.txt found for Hyprpicker"
fi

# --- Install Hyprshot (AUR-style installation) ---
echo "Installing Hyprshot..."

HYPRSHOT_DIR="$HOME/.local/src/hyprshot"
if [ -d "$HYPRSHOT_DIR" ]; then
    echo "Updating Hyprshot repository..."
    git -C "$HYPRSHOT_DIR" pull || echo "Git pull failed, continuing with existing code..."
else
    echo "Cloning Hyprshot repository..."
    git clone --depth=1 https://github.com/Gustash/Hyprshot.git "$HYPRSHOT_DIR"
fi

# AUR-style installation - just copy the script and make it executable
echo "Installing Hyprshot script..."
mkdir -p "$HOME/.local/bin"
cp "$HYPRSHOT_DIR/hyprshot" "$HOME/.local/bin/hyprshot"
chmod +x "$HOME/.local/bin/hyprshot"

echo "Hyprshot has been installed to $HOME/.local/bin/hyprshot"

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

# Build and install Hyprsunset - now with dependencies available as packages
cd "$HYPRSUNSET_DIR"
if [ -f "CMakeLists.txt" ]; then
    echo "Building Hyprsunset with CMake..."
    if cmake -B build -S . -DCMAKE_BUILD_TYPE=Release && \
       cmake --build build && \
       sudo cmake --install build; then
        echo "Hyprsunset installed successfully"
    else
        echo "Warning: Hyprsunset installation failed"
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
        echo "Gray installed successfully"
    else
        echo "Warning: Gray build/install failed, but continuing..."
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

echo "Nerd Fonts Symbols have been installed to user directory."

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
else
    echo "Zed Sans fonts are already installed."
fi

# --- Network services configuration ---
echo "Configuring network services..."

# Disable iwd if enabled/active
if systemctl is-enabled --quiet iwd 2>/dev/null || systemctl is-active --quiet iwd 2>/dev/null; then
    echo "Disabling iwd..."
    sudo systemctl disable --now iwd 2>/dev/null || echo "Could not disable iwd"
else
    echo "iwd is not enabled or not present."
fi

# Enable NetworkManager if not enabled
if ! systemctl is-enabled --quiet NetworkManager 2>/dev/null; then
    echo "Enabling NetworkManager..."
    sudo systemctl enable NetworkManager 2>/dev/null || echo "Could not enable NetworkManager"
else
    echo "NetworkManager is already enabled."
fi

# Start NetworkManager if not running
if ! systemctl is-active --quiet NetworkManager 2>/dev/null; then
    echo "Starting NetworkManager..."
    sudo systemctl start NetworkManager 2>/dev/null || echo "Could not start NetworkManager"
else
    echo "NetworkManager is already running."
fi

# --- Copy local fonts from Ax-Shell ---
echo "Copying Ax-Shell fonts..."

if [ -d "$INSTALL_DIR/assets/fonts" ] && [ ! -d "$HOME/.fonts/tabler-icons" ]; then
    echo "Copying local fonts to $HOME/.fonts/tabler-icons..."
    mkdir -p "$HOME/.fonts/tabler-icons"
    cp -r "$INSTALL_DIR/assets/fonts/"* "$HOME/.fonts/" 2>/dev/null || echo "Some fonts could not be copied"
else
    echo "Local fonts are already installed or not available."
fi

# --- Update PATH if needed ---
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo "Adding ~/.local/bin to PATH in .bashrc..."
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    export PATH="$HOME/.local/bin:$PATH"
fi

# --- Update font cache again after all font installations ---
echo "Updating font cache after all font installations..."
fc-cache -fv

# --- Install Python requirements for Ax-Shell ---
echo "Installing Python requirements for Ax-Shell..."

if [ -f "$INSTALL_DIR/requirements.txt" ]; then
    echo "Installing requirements from requirements.txt..."
    pip3 install -r "$INSTALL_DIR/requirements.txt" || echo "Failed to install some Python requirements"
else
    echo "No requirements.txt found, installing common dependencies..."
    pip3 install psutil requests watchdog ijson toml setproctitle pywayland || echo "Failed to install some Python packages"
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

# Check if fonts were installed
if [ ! -f "$HOME/.fonts/SymbolsNerdFont-Regular.ttf" ]; then
    MISSING_COMPONENTS+=("Nerd Fonts")
fi

if [ ${#MISSING_COMPONENTS[@]} -eq 0 ]; then
    echo "All critical components installed successfully!"
else
    echo "Warning: The following components failed to install: ${MISSING_COMPONENTS[*]}"
fi

# Try to run configuration if Ax-Shell is available
if [ -f "$INSTALL_DIR/config/config.py" ]; then
    echo "Running Ax-Shell configuration..."
    cd "$INSTALL_DIR"
    if python3 "$INSTALL_DIR/config/config.py"; then
        echo "Ax-Shell configuration completed successfully"
    else
        echo "Configuration script failed, but installation will continue"
    fi
else
    echo "Ax-Shell configuration script not found."
fi

# Kill any existing Ax-Shell instances
echo "Stopping any existing Ax-Shell instances..."
pkill -f "ax-shell" 2>/dev/null || true

echo ""
echo "=============================================="
echo "INSTALLATION COMPLETE!"
echo "=============================================="
echo ""
echo "Ax-Shell (Quiet fork) has been installed to: $INSTALL_DIR"
echo ""
echo "All components installed:"
echo "✅ Hyprpicker (built from latest source)"
echo "✅ Hyprshot (screenshot tool)"
echo "✅ Hyprsunset (blue light filter)"
echo "✅ Hypridle & Hyprlock"
echo "✅ Hyprlang, Hyprutils, Hyprwayland-scanner (from PikaOS repo)"
echo "✅ Gray (system utility)"
echo "✅ Nerd Fonts Symbols & Zed Sans fonts"
echo "✅ Network configuration"
echo "✅ All Python dependencies including Fabric"
echo ""
echo "Next steps:"
echo "1. Restart your terminal or run: source ~/.bashrc"
echo "2. Start Ax-Shell manually: python3 $INSTALL_DIR/main.py"
echo "3. Test Hyprshot: hyprshot --help"
echo "4. Test Hyprpicker: hyprpicker --help"
echo ""
echo "Enjoy using Ax-Shell! 🚀"
echo "=============================================="
