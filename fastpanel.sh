#!/usr/bin/env bash

# FASTPANEL Standalone Installer for Proxmox
# This is a self-contained version for local testing
# For production use, split into CT and install scripts and host on GitHub

# Colors and formatting
YW="\033[33m"
BL="\033[36m"
RD="\033[01;31m"
BGN="\033[4;92m"
GN="\033[1;92m"
DGN="\033[32m"
CL="\033[m"
RETRY_NUM=10
RETRY_EVERY=3
NUM=$RETRY_NUM
CM="${GN}✔${CL}"
CROSS="${RD}✗${CL}"
BFR="\\r\\033[K"
HOLD="-"
SPINNER="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"

# Default values
APP="FASTPANEL"
CTID_DEFAULT=$(pvesh get /cluster/nextid)
HOSTNAME="fastpanel"
DISK_SIZE="5"
CPU_CORES="1"
RAM_SIZE="1024"
BRIDGE="vmbr0"
OS_TYPE="debian"
OS_VERSION="12"
STORAGE=$(pvesm status | awk '/active/ {print $1; exit}')
TEMPLATE="local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"

msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}..."
}

msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

msg_error() {
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

echo -e "${BFR}
 ${GN}____${YW}    __           __    _   __               __
${GN}/ __/__ _${YW}_/ /____  ___ _/ /__ / | / /___  ___ ___/ /
${GN}/ _// _ \`${YW}(_-</ _ \/ _ \`/ / -_)  |/ / -_) |  / _  /
${GN}/___/\_,${YW}_/___/_//_/\_,_/_/\__/|___/\__/  |_/\_,_/
${CL}"

echo -e "${GN}Creating FASTPANEL LXC Container${CL}"
echo -e "${YW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"

# Get next available CT ID
CTID=$CTID_DEFAULT
echo -e "${BL}Container ID: ${GN}${CTID}${CL}"

msg_info "Creating LXC Container"
pct create "$CTID" "$TEMPLATE" \
  --hostname "$HOSTNAME" \
  --cores "$CPU_CORES" \
  --memory "$RAM_SIZE" \
  --swap 0 \
  --net0 name=eth0,bridge="$BRIDGE",ip=dhcp \
  --ostype "$OS_TYPE" \
  --rootfs "$STORAGE:$DISK_SIZE" \
  --unprivileged 1 \
  --features nesting=1 \
  --onboot 1 &>/dev/null

if [ $? -eq 0 ]; then
  msg_ok "Created LXC Container ${CTID}"
else
  msg_error "Failed to create container"
  exit 1
fi

msg_info "Starting Container"
pct start "$CTID"
sleep 5
msg_ok "Started Container"

msg_info "Waiting for network"
for i in {1..30}; do
  if pct exec "$CTID" -- ping -c 1 google.com &>/dev/null; then
    break
  fi
  sleep 1
done
msg_ok "Network Ready"

msg_info "Updating Container OS"
pct exec "$CTID" -- bash -c "apt-get update &>/dev/null"
msg_ok "Updated Container OS"

msg_info "Installing Dependencies"
pct exec "$CTID" -- bash -c "apt-get install -y curl sudo mc ca-certificates wget &>/dev/null"
msg_ok "Installed Dependencies"

msg_info "Installing FASTPANEL (this may take several minutes)"
echo -e "${YW}   This includes downloading and installing MySQL/MariaDB, PHP, and other components...${CL}"

pct exec "$CTID" -- bash -c "wget https://repo.fastpanel.direct/install_fastpanel.sh -O - 2>/dev/null | bash - 2>&1 | tee /tmp/fastpanel_install.log"
INSTALL_EXIT=$?

if [ $INSTALL_EXIT -eq 0 ]; then
  msg_ok "Installed FASTPANEL"
else
  msg_error "FASTPANEL installation failed"
  echo -e "${YW}Check logs: pct exec $CTID -- cat /tmp/fastpanel_install.log${CL}"
  exit 1
fi

msg_info "Cleaning Up"
pct exec "$CTID" -- bash -c "apt-get -y autoremove &>/dev/null && apt-get -y autoclean &>/dev/null"
msg_ok "Cleaned"

# Get container IP
msg_info "Getting Container IP"
sleep 2
IP=$(pct exec "$CTID" -- hostname -I | awk '{print $1}')
msg_ok "Container IP: ${IP}"

# Extract credentials from install log
CREDS=$(pct exec "$CTID" -- grep -A 3 "Congratulations" /tmp/fastpanel_install.log 2>/dev/null)

echo -e ""
echo -e "${GN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
echo -e "${GN}   FASTPANEL Installation Complete!${CL}"
echo -e "${GN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
echo -e ""
echo -e "${BL}Container ID:${CL} ${GN}${CTID}${CL}"
echo -e "${BL}Web Interface:${CL} ${BGN}https://${IP}:8888${CL}"
echo -e ""

if [ ! -z "$CREDS" ]; then
  echo -e "${YW}Login Credentials:${CL}"
  echo "$CREDS"
else
  echo -e "${YW}To view login credentials, run:${CL}"
  echo -e "  ${BGN}pct exec ${CTID} -- cat /tmp/fastpanel_install.log | grep -A 3 'Congratulations'${CL}"
fi

echo -e ""
echo -e "${YW}Additional Commands:${CL}"
echo -e "  ${DGN}Access Console:${CL} pct console ${CTID}"
echo -e "  ${DGN}Stop Container:${CL} pct stop ${CTID}"
echo -e "  ${DGN}Start Container:${CL} pct start ${CTID}"
echo -e "  ${DGN}Delete Container:${CL} pct stop ${CTID} && pct destroy ${CTID}"
echo -e ""
