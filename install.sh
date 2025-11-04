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

# Remove conflicting system packages that might cause issues
echo "Cleaning up conflicting packages..."
sudo apt remove -y python3-fabric fabric 2>/dev/null || true
sudo apt autoremove -y

# Install essential packages from PikaOS repos
echo "Installing required packages..."
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
    gir1.2-girepository-2.0 golang-go libpugixml-dev \
    libcvc0t64 gir1.2-cvc-1.0

# Create necessary directories
echo "Creating necessary directories..."
mkdir -p "$HOME/.local/bin" "$HOME/.local/share/fonts" "$HOME/.local/src"

# Setup Python virtual environment properly
echo "Setting up Python virtual environment..."
if [ -d "$VENV_DIR" ]; then
    echo "Updating existing virtual environment..."
    rm -rf "$VENV_DIR"
fi

python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

# Upgrade pip and install required Python packages in venv
echo "Installing Python dependencies in virtual environment..."
"$VENV_DIR/bin/pip" install --upgrade pip
"$VENV_DIR/bin/pip" install \
    pillow \
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

# Install Fabric GUI framework in virtual environment
echo "Installing Fabric GUI framework..."
"$VENV_DIR/bin/pip" install git+https://github.com/Fabric-Development/fabric.git

# Clone or update the repository
if [ -d "$INSTALL_DIR" ]; then
    echo "Updating Ax-Shell..."
    cd "$INSTALL_DIR" && git pull || echo "⚠️ Git pull failed, using existing code"
else
    echo "Cloning Ax-Shell..."
    git clone --depth=1 "$REPO_URL" "$INSTALL_DIR"
fi

# Install Hyprshot (simple copy)
echo "Installing Hyprshot..."
HYPRSHOT_DIR="$HOME/.local/src/hyprshot"
if [ -d "$HYPRSHOT_DIR" ]; then
    cd "$HYPRSHOT_DIR" && git pull || true
else
    git clone --depth=1 https://github.com/Gustash/Hyprshot.git "$HYPRSHOT_DIR"
fi
cp "$HYPRSHOT_DIR/hyprshot" "$HOME/.local/bin/hyprshot"
chmod +x "$HOME/.local/bin/hyprshot"
echo "✅ Hyprshot installed"

# Install Fonts
echo "Installing fonts..."

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

# Copy Ax-Shell fonts if available
if [ -d "$INSTALL_DIR/assets/fonts" ]; then
    echo "Copying Ax-Shell local fonts..."
    mkdir -p "$HOME/.local/share/fonts/tabler-icons"
    cp -r "$INSTALL_DIR/assets/fonts/"* "$HOME/.local/share/fonts/" 2>/dev/null || echo "⚠️ Some fonts could not be copied"
fi

# Update font cache
fc-cache -fv
echo "✅ Fonts installation completed"

# Network services handling
echo "Configuring network services..."

# Disable iwd if enabled/active
if systemctl is-enabled --quiet iwd 2>/dev/null || systemctl is-active --quiet iwd 2>/dev/null; then
    echo "Disabling iwd..."
    sudo systemctl disable --now iwd
else
    echo "iwd is already disabled."
fi

# Enable NetworkManager if not enabled
if ! systemctl is-enabled --quiet NetworkManager 2>/dev/null; then
    echo "Enabling NetworkManager..."
    sudo systemctl enable NetworkManager
else
    echo "NetworkManager is already enabled."
fi

# Start NetworkManager if not running
if ! systemctl is-active --quiet NetworkManager 2>/dev/null; then
    echo "Starting NetworkManager..."
    sudo systemctl start NetworkManager
else
    echo "NetworkManager is already running."
fi

# Update PATH and create aliases
echo "Setting up environment..."

# Add ~/.local/bin to PATH if not already there
if ! grep -q "\.local/bin" "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi
export PATH="$HOME/.local/bin:$PATH"

# Create a smart wrapper script for Ax-Shell that uses the virtual environment
echo "Creating Ax-Shell launcher..."
cat > "$HOME/.local/bin/ax-shell" << EOF
#!/bin/bash
# Activate virtual environment and run Ax-Shell
source "$VENV_DIR/bin/activate"
cd "$INSTALL_DIR"
python main.py "\$@"
EOF
chmod +x "$HOME/.local/bin/ax-shell"

# Create a direct Python launcher as backup
cat > "$HOME/.local/bin/ax-shell-direct" << EOF
#!/bin/bash
"$VENV_DIR/bin/python" "$INSTALL_DIR/main.py" "\$@"
EOF
chmod +x "$HOME/.local/bin/ax-shell-direct"

# Test the installation before running
echo "Testing installation..."
if "$VENV_DIR/bin/python" -c "import fabric, gi; gi.require_version('Cvc', '1.0'); print('✅ All imports successful')"; then
    echo "✅ Environment test passed"
else
    echo "❌ Environment test failed"
    exit 1
fi

# Run configuration
echo "Running Ax-Shell configuration..."
cd "$INSTALL_DIR"
"$VENV_DIR/bin/python" config/config.py

# Start Ax-Shell
echo "Starting Ax-Shell..."
pkill -f "ax-shell" 2>/dev/null || true
"$VENV_DIR/bin/python" "$INSTALL_DIR/main.py" > /dev/null 2>&1 &
disown

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
echo "   Local Bin: $HOME/.local/bin"
echo "   Fonts: $HOME/.local/share/fonts"
echo ""
echo "🚀 Quick start:"
echo "   Restart terminal or run: source ~/.bashrc"
echo "   Start normally: ax-shell"
echo "   Direct start: ax-shell-direct"
echo "   Manual start: $VENV_DIR/bin/python $INSTALL_DIR/main.py"
echo ""
echo "🔧 Smart features:"
echo "   - Virtual environment prevents system conflicts"
echo "   - Automatic dependency management"
echo "   - Multiple launch options"
echo "   - Pre-flight testing"
echo ""
echo "=============================================="
