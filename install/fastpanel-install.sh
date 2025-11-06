#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts
# Author: Marleybop
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://fastpanel.direct/

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y --no-install-recommends curl
$STD apt-get install -y --no-install-recommends sudo
$STD apt-get install -y --no-install-recommends mc
$STD apt-get install -y --no-install-recommends ca-certificates
$STD apt-get install -y --no-install-recommends wget
msg_ok "Installed Dependencies"

msg_info "Installing FASTPANEL (this may take several minutes)"
wget https://repo.fastpanel.direct/install_fastpanel.sh -O /tmp/fastpanel_installer.sh
bash /tmp/fastpanel_installer.sh | tee /tmp/fastpanel_install.log
msg_ok "Installed FASTPANEL"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
