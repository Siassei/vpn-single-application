#!/usr/bin/env zsh

# needed to pass VPN_COMMAND with args
# if there is another way, please let me know
setopt shwordsplit


#VPN_COMMAND=
VPN_COMMAND_STOP=${VPN_SET_COMMAND_STOP:-""}

VPN_NETWORK_BASE=${VPN_SET_NETWORK_BASE:-10.200.200.0}
VPN_NETWORK_SUFFIX=${VPN_SET_NETWORK_SUFFIX:-/24}
VPN_NETWORK_ADDR_GATEWAY=${VPN_SET_NETWORK_ADDR_GATEWAY:-10.200.200.1}
VPN_NETWORK_ADDR_PEER=${VPN_SET_NETWORK_ADDR_PEER:-10.200.200.2}

VPN_INTERFACE_CONNECT=${VPN_SET_INTERFACE_CONNECT:-eth0}
VPN_INTERFACE_VPN=${VPN_SET_INTERFACE_VPN:-"vpn-${VPN_INTERFACE_CONNECT}"}
VPN_INTERFACE_PEER_NAME=${VPN_SET_INTERFACE_PEER_NAME:-"v-peer1"}

VPN_NETWORK_CUSTOM_NAMESERVER=${VPN_ENABLE_NETWORK_CUSTOM_NAMESERVER:-0}
VPN_NETWORK_CUSTOM_NAMESERVER_LIST=${VPN_SET_NETWORK_CUSTOM_NAMESERVER_LIST:-"nameserver 8.8.8.8"}

VPN_NAME=${VPN_SET_NAME:-"${VPN_SET_INTERFACE_CONNECT}-${VPN_SET_INTERFACE_VPN}"}


# check root
if [[ $UID != 0 ]]; then
    echo "This must be run as root."
    exit 1
fi

function iface_up() {
  echo "create virtual network"
  echo "  vpn name   : $VPN_NAME"
  echo "  interface  : $VPN_INTERFACE_VPN"
  echo "  connect to : $VPN_INTERFACE_CONNECT"
  echo "  peer       : $VPN_INTERFACE_PEER_NAME"
  echo "  gateway    : $VPN_NETWORK_ADDR_GATEWAY"

  ip netns add $VPN_NAME

  # create veth link and add peer
  ip link add $VPN_INTERFACE_VPN type veth peer name $VPN_INTERFACE_PEER_NAME
  ip link set $VPN_INTERFACE_PEER_NAME netns $VPN_NAME

  # Setup IP address of $VPN_INTERFACE_VPN
  ip addr add "${VPN_NETWORK_ADDR_GATEWAY}${VPN_NETWORK_SUFFIX}" dev $VPN_INTERFACE_VPN
  ip link set $VPN_INTERFACE_VPN up

  # Setup IP address of peer
  ip netns exec $VPN_NAME ip addr add "${VPN_NETWORK_ADDR_PEER}${VPN_NETWORK_SUFFIX}" dev $VPN_INTERFACE_PEER_NAME
  ip netns exec $VPN_NAME ip link set $VPN_INTERFACE_PEER_NAME up
  ip netns exec $VPN_NAME ip link set lo up

  # all trafic through $VPN_INTERFACE_VPN
  ip netns exec $VPN_NAME ip route add default via $VPN_NETWORK_ADDR_GATEWAY

  # Enable IP-forwarding
  echo 1 > /proc/sys/net/ipv4/ip_forward

  # Flush forward rules, policy DROP by default.
  iptables -P FORWARD DROP
  iptables -F FORWARD

  # Flush nat rules.
  iptables -t nat -F

  # Enable masquerading
  iptables -t nat -A POSTROUTING -s "${VPN_NETWORK_BASE}${VPN_NETWORK_SUFFIX}" -o $VPN_INTERFACE_CONNECT -j MASQUERADE

  # Allow forwarding between eth0 and v-eth1.
  iptables -A FORWARD -i $VPN_INTERFACE_CONNECT -o $VPN_INTERFACE_VPN -j ACCEPT
  iptables -A FORWARD -o $VPN_INTERFACE_CONNECT -i $VPN_INTERFACE_VPN -j ACCEPT

  if [[ $VPN_NETWORK_CUSTOM_NAMESERVER -eq 1 ]] ; then
    mkdir -p /etc/netns/$VPN_NAME
    echo "$VPN_NETWORK_CUSTOM_NAMESERVER_LIST" > /etc/netns/$VPN_NAME/resolv.conf
  fi

  ip netns exec $VPN_NAME fping 8.8.8.8
}

function iface_down() {
  echo "remove virtual network"
  echo "  vpn name   : $VPN_NAME"
  echo "  interface  : $VPN_INTERFACE_VPN"
  echo "  peer       : $VPN_INTERFACE_PEER_NAME"

  if [[ $VPN_NETWORK_CUSTOM_NAMESERVER -eq 1 ]] ; then
    rm -rf /etc/netns/$VPN_NAME
  fi

  echo 0 > /proc/sys/net/ipv4/ip_forward

  iptables -t nat -D POSTROUTING -s "${VPN_NETWORK_BASE}${VPN_NETWORK_SUFFIX}" -o $VPN_INTERFACE_CONNECT -j MASQUERADE

  # Allow forwarding between eth0 and v-eth1.
  iptables -D FORWARD -i $VPN_INTERFACE_CONNECT -o $VPN_INTERFACE_VPN -j ACCEPT
  iptables -D FORWARD -o $VPN_INTERFACE_CONNECT -i $VPN_INTERFACE_VPN -j ACCEPT

  # Flush forward rules, policy DROP by default.
  iptables -P FORWARD DROP
  iptables -F FORWARD

  # Flush nat rules.
  iptables -t nat -F

  ip link set $VPN_INTERFACE_VPN down
  ip link delete $VPN_INTERFACE_VPN type veth peer name $VPN_INTERFACE_PEER_NAME

  ip netns delete $VPN_NAME
}

function run() {
  echo "run command"
  shift
  exec ip netns exec $VPN_NAME "$@"
}

function start_vpn() {
  echo "start vpn network"
  ip netns exec $VPN_NAME $VPN_COMMAND &

  while ! ip netns exec $VPN_NAME ip a show dev tun0 up; do
    sleep .5
  done
}

function stop_vpn() {
  echo "stop vpn network"
  if [[ -n $VPN_COMMAND_STOP ]] ; then
    ip netns exec $VPN_NAME $VPN_COMMAND_STOP
  fi
}


case "$1" in
  execute)
    iface_up; start_vpn; run "$@"; stop_vpn; iface_down ;;
  up)
    iface_up ;;
  down)
    iface_down ;;
  run)
    run "$@" ;;
  start)
    start_vpn ;;
  stop)
    stop_vpn ;;
  *)
    echo "Syntax: $0 execute|up|down|run|start|stop"
    exit 1
    ;;
esac
