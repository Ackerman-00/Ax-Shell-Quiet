#!/bin/bash

set -e  # Exit immediately if a command fails
set -o pipefail  # Prevent errors in a pipeline from being masked

REPO_URL="https://github.com/Ackerman-00/Ax-Shell-Quiet.git"
INSTALL_DIR="$HOME/.config/Ax-Shell"
VENV_DIR="$HOME/.ax-shell-venv"

echo "Starting Ax-Shell installation for PikaOS..."
echo "=============================================="

# Update package lists
echo "Updating package lists..."
sudo apt update

# First, remove conflicting system packages
echo "Removing conflicting system packages..."
sudo apt remove -y python3-fabric fabric || true

# Install essential packages in one go
echo "Installing all required packages..."
sudo apt install -y \
    brightnessctl cava cliphist \
    gobject-introspection gpu-screen-recorder hypridle hyprlock \
    libnotify-bin matugen network-manager-applet nm-connection-editor \
    fonts-noto fonts-noto-color-emoji fonts-noto-mono \
    nvtop playerctl power-profiles-daemon swappy swww \
    tesseract-ocr tesseract-ocr-eng tesseract-ocr-spa \
    tmux unzip upower \
    webp-pixbuf-loader wl-clipboard jq grim slurp \
    libhyprlang-dev libhyprutils-dev \
    imagemagick libdbusmenu-gtk3-dev libgtk-layer-shell0 \
    libgtk-layer-shell-dev libwebkit2gtk-4.1-0 gir1.2-webkit2-4.1 \
    python3-gi python3-gi-cairo python3-full python3-pip python3-venv \
    python3-ijson python3-numpy python3-pil python3-psutil \
    python3-pywayland python3-requests python3-setproctitle \
    python3-toml python3-watchdog build-essential cmake git \
    meson ninja-build pkg-config valac libjson-glib-dev \
    libgtk-3-dev libcairo2-dev libpango1.0-dev libjpeg-dev \
    libwayland-dev wayland-protocols libxkbcommon-dev \
    python3-setuptools python3-wheel python3-build python3-installer \
    libgirepository1.0-dev python3-dev libffi-dev gir1.2-glib-2.0 \
    gir1.2-girepository-2.0 golang-go libpugixml-dev

# Create necessary directories
echo "Creating necessary directories..."
mkdir -p "$HOME/.local/src" "$HOME/.local/bin" "$HOME/.local/share/fonts"

# --- Install hyprwayland-scanner from Source (AUR-style) ---
echo "Installing hyprwayland-scanner from source..."

HYPRWAYLAND_SCANNER_DIR="$HOME/.local/src/hyprwayland-scanner"
if [ -d "$HYPRWAYLAND_SCANNER_DIR" ]; then
    echo "Updating hyprwayland-scanner repository..."
    cd "$HYPRWAYLAND_SCANNER_DIR" && git pull || true
else
    echo "Cloning hyprwayland-scanner repository..."
    git clone --depth=1 https://github.com/hyprwm/hyprwayland-scanner.git "$HYPRWAYLAND_SCANNER_DIR"
fi

# Build and install hyprwayland-scanner (AUR-style)
cd "$HYPRWAYLAND_SCANNER_DIR"

# Get version info similar to AUR pkgver()
HYPRWAYLAND_VERSION=$(git describe --long --tags --abbrev=7 2>/dev/null | sed 's/^v//;s/\([^-]*-g\)/r\1/;s/-/./g' || echo "0.4.0")
echo "Building hyprwayland-scanner version: $HYPRWAYLAND_VERSION"

# AUR-style build process
echo "Building hyprwayland-scanner with CMake..."
rm -rf build
if cmake -B build -S . -G Ninja -W no-dev -D CMAKE_BUILD_TYPE=Release -D CMAKE_INSTALL_PREFIX=/usr && \
   cmake --build build && \
   sudo cmake --install build; then
    echo "✅ hyprwayland-scanner installed successfully"
    
    # Install license (AUR-style)
    if [ -f "LICENSE" ]; then
        sudo install -Dm644 LICENSE -t /usr/share/licenses/hyprwayland-scanner/
    fi
else
    echo "❌ hyprwayland-scanner installation failed"
fi

# --- Create Python Virtual Environment ---
echo "Setting up Python virtual environment..."
if [ -d "$VENV_DIR" ]; then
    echo "Virtual environment already exists, recreating..."
    rm -rf "$VENV_DIR"
fi

# Create venv WITHOUT system packages to avoid conflicts
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

echo "✅ Virtual environment created at $VENV_DIR"

# --- Install Python packages in virtual environment ---
echo "Installing Python packages in virtual environment..."

# Upgrade pip first
"$VENV_DIR/bin/pip" install --upgrade pip

# Install all Python dependencies at once (fresh install in venv)
"$VENV_DIR/bin/pip" install \
    psutil \
    requests \
    watchdog \
    ijson \
    toml \
    setproctitle \
    pywayland \
    loguru \
    click \
    cffi \
    pycparser

echo "✅ Python dependencies installed"

# --- Install Fabric GTK Framework (NOT the deployment tool) ---
echo "Installing Fabric GTK framework..."

FABRIC_DIR="$HOME/.local/src/fabric"
if [ -d "$FABRIC_DIR" ]; then
    echo "Updating Fabric repository..."
    cd "$FABRIC_DIR" && git pull || true
else
    echo "Cloning Fabric repository..."
    git clone --depth=1 https://github.com/Fabric-Development/fabric.git "$FABRIC_DIR"
fi

cd "$FABRIC_DIR"
# Install Fabric
"$VENV_DIR/bin/pip" install .
echo "✅ Fabric GTK framework installed"

# --- Install fabric-cli (AUR-style with meson) ---
echo "Installing fabric-cli..."

FABRIC_CLI_DIR="$HOME/.local/src/fabric-cli"
if [ -d "$FABRIC_CLI_DIR" ]; then
    echo "Updating fabric-cli repository..."
    cd "$FABRIC_CLI_DIR" && git pull || true
else
    echo "Cloning fabric-cli repository..."
    git clone --depth=1 https://github.com/Fabric-Development/fabric-cli.git "$FABRIC_CLI_DIR"
fi

# Build fabric-cli using meson (AUR-style)
cd "$FABRIC_CLI_DIR"
if [ -f "meson.build" ]; then
    echo "Building fabric-cli with meson..."
    rm -rf build
    if meson setup build --prefix=/usr --buildtype=release && \
       ninja -C build && \
       sudo ninja -C build install; then
        echo "✅ fabric-cli installed"
    else
        echo "❌ fabric-cli build failed"
        # Try alternative: check if there's a built binary
        if [ -f "build/fabric-cli" ]; then
            sudo cp build/fabric-cli /usr/local/bin/
            echo "✅ fabric-cli installed manually"
        fi
    fi
else
    echo "❌ fabric-cli: No meson.build found"
    # Fallback: if it's a Go project, build with Go
    if [ -f "go.mod" ]; then
        echo "Building fabric-cli with Go..."
        go build -o fabric-cli
        sudo cp fabric-cli /usr/local/bin/
        echo "✅ fabric-cli installed via Go"
    fi
fi

# --- Install Hyprpicker ---
echo "Installing Hyprpicker..."

HYPRPICKER_DIR="$HOME/.local/src/hyprpicker"
if [ -d "$HYPRPICKER_DIR" ]; then
    echo "Updating Hyprpicker repository..."
    cd "$HYPRPICKER_DIR" && git pull || true
else
    echo "Cloning Hyprpicker repository..."
    git clone --depth=1 https://github.com/hyprwm/hyprpicker.git "$HYPRPICKER_DIR"
fi

cd "$HYPRPICKER_DIR"
if [ -f "CMakeLists.txt" ]; then
    echo "Building Hyprpicker..."
    rm -rf build
    if cmake -B build -S . -DCMAKE_BUILD_TYPE=Release && \
       cmake --build build -j$(nproc) && \
       sudo cmake --install build; then
        echo "✅ Hyprpicker installed"
    else
        echo "❌ Hyprpicker build failed"
        echo "Checking for missing dependencies..."
        pkg-config --exists hyprwayland-scanner && echo "  - hyprwayland-scanner: found" || echo "  - hyprwayland-scanner: missing"
        pkg-config --exists hyprutils && echo "  - hyprutils: found" || echo "  - hyprutils: missing"
    fi
else
    echo "❌ Hyprpicker: No CMakeLists.txt found"
fi

# --- Install Hyprshot ---
echo "Installing Hyprshot..."

HYPRSHOT_DIR="$HOME/.local/src/hyprshot"
if [ -d "$HYPRSHOT_DIR" ]; then
    cd "$HYPRSHOT_DIR" && git pull || true
else
    git clone --depth=1 https://github.com/Gustash/Hyprshot.git "$HYPRSHOT_DIR"
fi

mkdir -p "$HOME/.local/bin"
cp "$HYPRSHOT_DIR/hyprshot" "$HOME/.local/bin/hyprshot"
chmod +x "$HOME/.local/bin/hyprshot"
echo "✅ Hyprshot installed"

# --- Install Hyprsunset ---
echo "Installing Hyprsunset..."

HYPRSUNSET_DIR="$HOME/.local/src/hyprsunset"
if [ -d "$HYPRSUNSET_DIR" ]; then
    cd "$HYPRSUNSET_DIR" && git pull || true
else
    git clone --depth=1 https://github.com/hyprwm/hyprsunset.git "$HYPRSUNSET_DIR"
fi

cd "$HYPRSUNSET_DIR"
if [ -f "CMakeLists.txt" ]; then
    echo "Building Hyprsunset..."
    rm -rf build
    if cmake -B build -S . -DCMAKE_BUILD_TYPE=Release && \
       cmake --build build -j$(nproc) && \
       sudo cmake --install build; then
        echo "✅ Hyprsunset installed"
    else
        echo "❌ Hyprsunset build failed"
        echo "Checking for missing dependencies..."
        pkg-config --exists hyprwayland-scanner && echo "  - hyprwayland-scanner: found" || echo "  - hyprwayland-scanner: missing"
        pkg-config --exists hyprlang && echo "  - hyprlang: found" || echo "  - hyprlang: missing"
    fi
else
    echo "❌ Hyprsunset: No CMakeLists.txt found"
fi

# --- Install Gray ---
echo "Installing Gray..."

GRAY_DIR="$HOME/.local/src/gray"
if [ -d "$GRAY_DIR" ]; then
    cd "$GRAY_DIR" && git pull || true
else
    git clone --depth=1 https://github.com/Fabric-Development/gray.git "$GRAY_DIR"
fi

cd "$GRAY_DIR"
if [ -f "meson.build" ]; then
    echo "Building Gray..."
    rm -rf build
    if meson setup build --prefix=/usr --buildtype=release && \
       ninja -C build && \
       sudo ninja -C build install; then
        echo "✅ Gray installed"
    else
        echo "❌ Gray build failed"
    fi
else
    echo "❌ Gray: No meson.build found"
fi

# --- Install Fonts ---
echo "Installing fonts..."

# Nerd Fonts
echo "Installing Nerd Fonts..."
curl -L -o "$HOME/.local/share/fonts/SymbolsNerdFont-Regular.ttf" \
    "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/v3.4.0/patched-fonts/NerdFontsSymbolsOnly/SymbolsNerdFont-Regular.ttf" 2>/dev/null || echo "⚠️ Failed to download SymbolsNerdFont-Regular"

curl -L -o "$HOME/.local/share/fonts/SymbolsNerdFontMono-Regular.ttf" \
    "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/v3.4.0/patched-fonts/NerdFontsSymbolsOnly/SymbolsNerdFontMono-Regular.ttf" 2>/dev/null || echo "⚠️ Failed to download SymbolsNerdFontMono"

# Zed Sans Fonts
echo "Installing Zed Sans fonts..."
if [ ! -d "$HOME/.local/share/fonts/zed-sans" ]; then
    mkdir -p "$HOME/.local/share/fonts/zed-sans"
    if curl -L -o "/tmp/zed-sans.zip" \
        "https://github.com/zed-industries/zed-fonts/releases/download/1.2.0/zed-sans-1.2.0.zip"; then
        unzip -q -o "/tmp/zed-sans.zip" -d "$HOME/.local/share/fonts/zed-sans"
        rm -f "/tmp/zed-sans.zip"
        echo "✅ Zed Sans fonts installed"
    else
        echo "⚠️ Failed to download Zed Sans fonts"
    fi
else
    echo "✅ Zed Sans fonts already installed"
fi

# Update font cache
fc-cache -fv
echo "✅ Fonts installation completed"

# --- Clone Ax-Shell ---
echo "Setting up Ax-Shell..."

if [ -d "$INSTALL_DIR" ]; then
    echo "Updating existing Ax-Shell installation..."
    cd "$INSTALL_DIR" && git pull || echo "⚠️ Git pull failed, using existing code"
else
    echo "Cloning Ax-Shell..."
    git clone --depth=1 "$REPO_URL" "$INSTALL_DIR"
fi

# Copy Ax-Shell fonts if available
if [ -d "$INSTALL_DIR/assets/fonts" ]; then
    echo "Copying Ax-Shell local fonts..."
    mkdir -p "$HOME/.local/share/fonts/tabler-icons"
    cp -r "$INSTALL_DIR/assets/fonts/"* "$HOME/.local/share/fonts/" 2>/dev/null || echo "⚠️ Some fonts could not be copied"
fi

# --- Network configuration ---
echo "Configuring network services..."
sudo systemctl disable iwd 2>/dev/null || echo "✅ iwd not present or already disabled"
sudo systemctl enable NetworkManager 2>/dev/null || echo "✅ NetworkManager already enabled"
sudo systemctl start NetworkManager 2>/dev/null || echo "✅ NetworkManager already running"

# --- Update PATH and create aliases ---
echo "Setting up environment..."

# Add ~/.local/bin to PATH if not already there
if ! grep -q "\.local/bin" "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi
export PATH="$HOME/.local/bin:$PATH"

# Add ax-shell alias
if ! grep -q "ax-shell" "$HOME/.bashrc"; then
    echo "alias ax-shell='$VENV_DIR/bin/python $INSTALL_DIR/main.py'" >> "$HOME/.bashrc"
fi

# --- Install Ax-Shell requirements ---
echo "Installing Ax-Shell specific requirements..."
if [ -f "$INSTALL_DIR/requirements.txt" ]; then
    "$VENV_DIR/bin/pip" install -r "$INSTALL_DIR/requirements.txt" || echo "⚠️ Some requirements failed to install"
else
    echo "No requirements.txt found, using default dependencies"
fi

# --- Final verification ---
echo "Final verification..."

# Test critical components
echo "Component status:"
pkg-config --exists hyprwayland-scanner && echo "✅ hyprwayland-scanner" || echo "❌ hyprwayland-scanner"
command -v hyprpicker >/dev/null 2>&1 && echo "✅ Hyprpicker" || echo "❌ Hyprpicker"
[ -f "$HOME/.local/bin/hyprshot" ] && echo "✅ Hyprshot" || echo "❌ Hyprshot"
command -v hyprsunset >/dev/null 2>&1 && echo "✅ Hyprsunset" || echo "❌ Hyprsunset"
command -v gray >/dev/null 2>&1 && echo "✅ Gray" || echo "❌ Gray"
"$VENV_DIR/bin/python" -c "import fabric" 2>/dev/null && echo "✅ Fabric" || echo "❌ Fabric"
command -v fabric-cli >/dev/null 2>&1 && echo "✅ fabric-cli" || echo "❌ fabric-cli"
"$VENV_DIR/bin/python" -c "import gi" 2>/dev/null && echo "✅ PyGObject" || echo "❌ PyGObject"

# Run configuration if available
if [ -f "$INSTALL_DIR/config/config.py" ]; then
    echo "Running Ax-Shell configuration..."
    cd "$INSTALL_DIR"
    if "$VENV_DIR/bin/python" "config/config.py"; then
        echo "✅ Ax-Shell configuration completed"
    else
        echo "⚠️ Ax-Shell configuration had issues"
    fi
else
    echo "⚠️ Ax-Shell configuration script not found"
fi

# Start Ax-Shell
echo "Starting Ax-Shell..."
pkill -f "ax-shell" 2>/dev/null || true

if command -v uwsm >/dev/null 2>&1; then
    uwsm app -- "$VENV_DIR/bin/python" "$INSTALL_DIR/main.py" > /dev/null 2>&1 & disown
    echo "✅ Ax-Shell started with uwsm"
else
    "$VENV_DIR/bin/python" "$INSTALL_DIR/main.py" > /dev/null 2>&1 &
    echo "✅ Ax-Shell started directly"
fi

echo ""
echo "=============================================="
echo "🎉 INSTALLATION COMPLETE!"
echo "=============================================="
echo ""
echo "Ax-Shell is now running!"
echo ""
echo "📍 Important locations:"
echo "   Config: $INSTALL_DIR"
echo "   Virtual Env: $VENV_DIR"
echo "   Fonts: $HOME/.local/share/fonts"
echo ""
echo "🚀 Quick start:"
echo "   Restart terminal or run: source ~/.bashrc"
echo "   Start manually: ax-shell"
echo "   Or: $VENV_DIR/bin/python $INSTALL_DIR/main.py"
echo ""
echo "🔧 Troubleshooting:"
echo "   Check component status above"
echo "   Missing components may need manual installation"
echo ""
echo "=============================================="
