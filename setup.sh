#!/bin/bash

set -e
set -a

DEPLOY_CLIENT=true

# If x86_64 deploy Linux client app and RFID bridge
# Else, deploy only RFID bridge, app is not currently available for other architectures
# You can access the web client at http://openpark.com
if [[ "$(uname -m)" != "x86_64" ]]; then
    DEPLOY_CLIENT=false
    echo "Open Park Project client app is not available for this architecture. Only RFID bridge will be deployed."
fi

CLIENT_SERVICE_NAME="opp-client.service"
USER_NAME=$USER
CLIENT_EXECUTABLE_DIR=$HOME/opp-frontend/
CLIENT_EXECUTABLE_NAME="openpark"
# Create the rfid bridge service
RFID_BRIDGE_SERVICE_NAME="rfid-bridge.service"
RFID_BRIDGE_EXECUTABLE_DIR=$HOME/rfid-bridge/
RFID_BRIDGE_EXECUTABLE_NAME="rfid-bridge.py"

echo "Open Park Project totem configuration started"

echo "Preventive cleanup..."
# Remove old client app if it exists
if [ -d "$CLIENT_EXECUTABLE_DIR" ]; then
    echo "Removing old client app..."
    rm -rf $CLIENT_EXECUTABLE_DIR
fi
# Remove old RFID bridge if it exists
if [ -d "$RFID_BRIDGE_EXECUTABLE_DIR" ]; then
    echo "Removing old RFID bridge..."
    rm -rf $RFID_BRIDGE_EXECUTABLE_DIR
fi

if [ $DEPLOY_CLIENT = true ]; then
  echo "Fetching latest client app..."
  # Download the latest OPP client frontend
  OPP_CLIENT_URL_BASE="https://api.github.com/repos/OpenParkProject/OPP-frontend/releases/latest"
  DOWNLOAD_URL=$(curl -s $OPP_CLIENT_URL_BASE | grep "browser_download_url" | grep "opp-linux-.*\.tar\.gz" | cut -d '"' -f 4)

  echo "Downloading from $DOWNLOAD_URL"
  curl -s -L -o /tmp/opp-client.tar.gz "$DOWNLOAD_URL"
  mkdir -p $CLIENT_EXECUTABLE_DIR
  tar -xzf /tmp/opp-client.tar.gz -C $CLIENT_EXECUTABLE_DIR --strip-components=1
  rm -f /tmp/opp-client.tar.gz
fi

echo "Installing OPP RFID Bridge..."
mkdir -p $RFID_BRIDGE_EXECUTABLE_DIR
cp -rf rfid-bridge/* $RFID_BRIDGE_EXECUTABLE_DIR
echo "Installing OPP RFID Bridge dependencies..."
python3 -m venv $RFID_BRIDGE_EXECUTABLE_DIR/venv || {
    echo "Failed to create virtual environment. Please install python3-venv package."
    exit 1
}
source $RFID_BRIDGE_EXECUTABLE_DIR/venv/bin/activate
pip install -r $RFID_BRIDGE_EXECUTABLE_DIR/requirements.txt
deactivate

echo "Creating systemd service files..."
# Substitute environment variables in service files
envsubst < services/$RFID_BRIDGE_SERVICE_NAME > /tmp/$RFID_BRIDGE_SERVICE_NAME
sudo cp /tmp/$RFID_BRIDGE_SERVICE_NAME /etc/systemd/system/
if [ $DEPLOY_CLIENT = true ]; then
  envsubst < services/$CLIENT_SERVICE_NAME > /tmp/$CLIENT_SERVICE_NAME
  sudo cp /tmp/$CLIENT_SERVICE_NAME /etc/systemd/system/
fi

# Clean up temporary files
rm /tmp/$CLIENT_SERVICE_NAME /tmp/$RFID_BRIDGE_SERVICE_NAME
echo "Enabling and starting services..."
sudo systemctl daemon-reload
sudo systemctl enable $RFID_BRIDGE_SERVICE_NAME
sudo systemctl start $RFID_BRIDGE_SERVICE_NAME
if [ $DEPLOY_CLIENT = true ]; then
  sudo systemctl enable $CLIENT_SERVICE_NAME
  sudo systemctl start $CLIENT_SERVICE_NAME
fi

echo "Open Park Project totem configuration completed successfully!"
