# vpn-single-application
Simple helper script to pass shell commands through an vpn network, that does not affect another 
local programs/services.


## Usage

Setup all needed information into an small shell script like *example.sh*. General you can use 
any vpn client what you like / need.

Alternativ put all things into an single command line. That could look like followed lines for an 
vpnc setup with the vpnc configuration file *vpn_network_001* (normally located at 
/etc/vpnc/vpn_network_001.conf).

```bash
env                                                \
  VPN_COMMAND="/usr/bin/vpnc vpn_network_001"      \
  VPN_SET_COMMAND_STOP="/usr/bin/vpnc-disconnect"  \
  VPN_SET_INTERFACE_CONNECT="eth0"                 \
  VPN_SET_INTERFACE_VPN="vpn-001"                  \
  ./vpn-single-application.sh execute              \
    /usr/local/bin/....
```
