#!/bin/bash

set -e # Exit immediately if a command fails
set -o pipefail # Prevent errors in a pipeline from being masked

REPO_URL="https://github.com/Ackerman-00/Ax-Shell-Quiet.git"
INSTALL_DIR="$HOME/.config/Ax-Shell"

# --- FIX FUNCTIONS ---
# Function to automatically fix missing Python imports and indentation errors
fix_python_imports() {
    local file_path="$1"
    local import_line="$2"
    local target_line_number="$3"
    
    if [ ! -f "$file_path" ]; then
        echo "⚠️ Warning: File not found: $file_path"
        return
    fi

    echo "⚙️ Fixing imports in $file_path..."
    
    # Check if the line already exists
    if grep -qF -- "$import_line" "$file_path"; then
        echo "✅ Import '$import_line' already present in $file_path."
        return
    fi

    # Read all lines into an array
    mapfile -t lines < "$file_path"
    
    # Check if the target line number is valid
    if [ "$target_line_number" -gt "${#lines[@]}" ]; then
        echo "⚠️ Warning: Target line number $target_line_number exceeds file length in $file_path. Skipping fix."
        return
    fi

    # Determine indentation from the surrounding lines (using spaces)
    local target_index=$((target_line_number - 1))
    local reference_line="${lines[target_index]}"
    local current_indentation=$(echo "$reference_line" | sed 's/\([^[:space:]]\).*//')
    
    # Use a specific line number to insert the new import
    if [ -n "$target_line_number" ]; then
        local before=("${lines[@]:0:target_index}")
        local after=("${lines[@]:target_index}")
        
        # Write content back to the file with the new line added and proper indentation
        printf "%s\n" "${before[@]}" > "$file_path"
        # The added line must be correctly indented (no tabs, just spaces)
        echo "${current_indentation}${import_line}" >> "$file_path"
        printf "%s\n" "${after[@]}" >> "$file_path"
        
        echo "✅ Added '$import_line' to $file_path."
    fi
}
# --------------------

echo "Starting Ax-Shell installation for PikaOS..."
echo "=============================================="

# Update package lists
echo "Updating package lists..."
sudo apt update

# Install essential packages, including the necessary GObject Introspection bindings
echo "Installing required packages and fixing missing dependencies..."
sudo apt install -y \
    brightnessctl cava cliphist \
    gobject-introspection gpu-screen-recorder hypridle hyprlock \
    libnotify-bin matugen network-manager-applet nm-connection-editor \
    fonts-noto fonts-noto-color-emoji fonts-noto-mono \
    nvtop power-profiles-daemon swappy swww \
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
    libcvc0t64 gir1.2-cvc-1.0 python3-xdg python3-dbus scdoc \
    # --- ADDED DEPENDENCIES FOR AX-SHELL FUNCTIONALITY ---
    socat \
    playerctl \
    python3-networkmanager \
    gir1.2-nm-1.0 \
    gir1.2-playerctl-2.0 \
    gir1.2-gnomebluetooth-3.0

# Create necessary directories
echo "Creating necessary directories..."
mkdir -p "$HOME/.local/bin" "$HOME/.local/share/fonts" "$HOME/.local/src"

# Clone or update the repository
if [ -d "$INSTALL_DIR" ]; then
    echo "Updating Ax-Shell..."
    cd "$INSTALL_DIR" && git pull || echo "⚠️ Git pull failed, using existing code"
else
    echo "Cloning Ax-Shell..."
    git clone --depth=1 "$REPO_URL" "$INSTALL_DIR"
fi

# Install uwsm (Wayland session manager) from source
echo "Installing uwsm from source..."
UWSM_DIR="$HOME/.local/src/uwsm"
if [ -d "$UWSM_DIR" ]; then
    echo "Updating uwsm repository..."
    cd "$UWSM_DIR" && git pull || true
else
    echo "Cloning uwsm repository..."
    git clone --depth=1 https://github.com/Vladimir-csp/uwsm.git "$UWSM_DIR"
fi

cd "$UWSM_DIR"
meson setup build -Duuctl=enabled -Dfumon=enabled -Duwsm-app=enabled
meson compile -C build
sudo meson install -C build
echo "✅ uwsm installed"

# --- FABRIC CLEANUP AND INSTALLATION FIX (Crucial for PyGObject) ---
echo "Cleaning up conflicting user-installed Python packages..."
# Force removal of potentially conflicting local packages
/usr/bin/env python3 -m pip uninstall -y fabric PyGObject pycairo --break-system-packages 2>/dev/null || true

echo "Installing Fabric GUI framework using --break-system-packages and skipping dependencies..."
# Install Fabric without dependencies to force it to use the system PyGObject
/usr/bin/env python3 -m pip install --break-system-packages --no-deps --no-cache-dir git+https://github.com/Fabric-Development/fabric.git
echo "✅ Fabric installed"
# --- END FABRIC FIX ---


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

# --- PYTHON CODE FIXES (Crucial for launch) ---
echo "Applying Python import fixes to Ax-Shell source files..."
# 1. Fix missing NetworkClient import in modules/metrics.py (Line 22)
fix_python_imports \
    "$INSTALL_DIR/modules/metrics.py" \
    "from services.network import NetworkClient" \
    22

# 2. Fix missing NetworkClient import in modules/buttons.py (approx Line 15)
fix_python_imports \
    "$INSTALL_DIR/modules/buttons.py" \
    "from services.network import NetworkClient" \
    15
# --- END PYTHON CODE FIXES ---


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

# Run configuration
echo "Running Ax-Shell configuration..."
cd "$INSTALL_DIR"
python3 config/config.py

# Start Ax-Shell with uwsm (the proper way)
echo "Starting Ax-Shell..."
pkill -f "ax-shell" 2>/dev/null || true
uwsm app -- python3 "$INSTALL_DIR/main.py" > /dev/null 2>&1 &
disown

echo ""
echo "=============================================="
echo "🎉 INSTALLATION COMPLETE!"
echo "=============================================="
echo ""
echo "**Ax-Shell is now running with uwsm!**"
echo ""
echo "🔥 **IMPORTANT LAST STEP (Visibility)**:"
echo "If the widgets are not visible, ensure you have the correct layer rule in your Hyprland config (~/.config/hypr/hyprland.conf):"
echo "layerrule = all, fabric"
echo "Then run: **hyprctl reload**"
echo ""
echo "=============================================="
