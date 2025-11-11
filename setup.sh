#!/bin/bash
set -e

echo "=== Updating system ==="
sudo apt update && sudo apt full-upgrade -y

echo "=== Installing build dependencies ==="
sudo apt install -y g++ git cmake \
  libxrandr-dev libxcursor-dev libudev-dev \
  libflac-dev libvorbis-dev libgl1-mesa-dev \
  libegl1-mesa-dev libdrm-dev libgbm-dev \
  libfreetype-dev libharfbuzz-dev xorg-dev \
  libgpiod-dev x11-xserver-utils

echo "=== Cloning cc3dsfs repo ==="
cd /home/pi
git clone https://github.com/Lorenzooone/cc3dsfs.git || true
cd cc3dsfs

echo "=== Building cc3dsfs ==="
cmake -B build -DCMAKE_BUILD_TYPE=Release -DRASPBERRY_PI_COMPILATION=TRUE
cmake --build build --config Release -j$(nproc)

echo "=== Installing udev rules ==="
sudo cp usb_rules/*.rules /etc/udev/rules.d/ || true
sudo udevadm control --reload-rules
sudo udevadm trigger

echo "=== Creating autostart entry (kiosk mode) ==="
mkdir -p /home/pi/.config/autostart
cat > /home/pi/.config/autostart/cc3dsfs.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=cc3dsfs Kiosk
Exec=/home/pi/cc3dsfs/build/cc3dsfs --fullscreen
StartupNotify=false
Terminal=false
EOF

echo "=== Disabling screen blanking ==="
cat > /home/pi/.config/autostart/disable-screensaver.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Disable screensaver
Exec=/bin/sh -c "xset s off && xset -dpms && xset s noblank"
Terminal=false
EOF

echo "=== Setup complete! ==="
echo "Reboot your Pi to launch cc3dsfs automatically in fullscreen kiosk mode."
