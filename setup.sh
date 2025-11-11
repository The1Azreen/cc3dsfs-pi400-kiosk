#!/bin/bash
set -e

LOG_FILE="/home/pi/cc3dsfs-kiosk.log"

echo "=== Updating system ==="
sudo apt update && sudo apt full-upgrade -y

echo "=== Installing build dependencies ==="
sudo apt install -y g++ git cmake \
  libxrandr-dev libxcursor-dev libudev-dev \
  libflac-dev libvorbis-dev libgl1-mesa-dev \
  libegl1-mesa-dev libdrm-dev libgbm-dev \
  libfreetype-dev libharfbuzz-dev xorg-dev \
  libgpiod-dev x11-xserver-utils

echo "=== Installing GPIO libraries ==="
sudo apt install -y python3-gpiozero python3-rpi.gpio pigpio

echo "=== Enabling pigpio daemon ==="
sudo systemctl enable pigpiod
sudo systemctl start pigpiod

echo "=== Adding 'pi' user to GPIO group ==="
sudo usermod -a -G gpio pi

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

echo "=== Creating systemd user service for auto-restart ==="
mkdir -p /home/pi/.config/systemd/user
cat > /home/pi/.config/systemd/user/cc3dsfs.service <<'EOF'
[Unit]
Description=cc3dsfs kiosk (auto-restart)
After=graphical-session.target

[Service]
ExecStart=/home/pi/cc3dsfs/build/cc3dsfs --fullscreen
Restart=always
RestartSec=5
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/pi/.Xauthority
StandardOutput=append:/home/pi/cc3dsfs-kiosk.log
StandardError=append:/home/pi/cc3dsfs-kiosk.log

[Install]
WantedBy=default.target
EOF

echo "=== Enabling systemd user service ==="
sudo loginctl enable-linger pi || true
systemctl --user daemon-reload
systemctl --user enable --now cc3dsfs.service || true

echo "=== Setup complete! ==="
echo "GPIO support enabled: user 'pi' added to gpio group, pigpiod running"
echo "Log file: $LOG_FILE"
echo "Reboot your Pi to start cc3dsfs in kiosk mode with auto-restart."
