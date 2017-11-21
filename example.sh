#!/usr/bin/env zsh

# needed to pass VPN_COMMAND with args
# if there is another way, please let me know
setopt shwordsplit

# sample setup for an vpnc client with
# the local config file vpn_network_001
export VPN_COMMAND="/usr/bin/vpnc vpn_network_001"
export VPN_SET_COMMAND_STOP="/usr/bin/vpnc-disconnect"

# bind virtual network to device
export VPN_SET_INTERFACE_CONNECT="eth0"
# virtual network interface name
export VPN_SET_INTERFACE_VPN="vpn-001"
# virtual network netns name
export VPN_SET_NAME="${VPN_SET_INTERFACE_CONNECT}-${VPN_SET_INTERFACE_VPN}"
# shortcut to minimze writing in the next lines
vpn=./vpn-single-application.sh

#
$vpn execute ....

#
# or
#
$vpn up
$vpn start

$vpn run ...

$vpn stop
$vpn down
