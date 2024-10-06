#!/bin/bash
function the_Title {
    echo ""
    echo "┏━┓╻ ╻╻┏━╸╻┏ ┏━┓┏━┓ ┏━┓╻ ╻"
    echo "┃┓┃┃ ┃┃┃  ┣┻┓┣━┫┣━┛ ┗━┓┣━┫"
    echo "┗┻┛┗━┛╹┗━╸╹ ╹╹ ╹╹  ╹┗━┛╹ ╹ by pmartinez@proton.me GNU/GPLv3"
}

function start_hostapd {
    #Hostapd
    echo "****************************************************************************************"
    echo -e "Trying to init hostapd AP with name ${RED}$ssid${NC} and wpa-key: ${RED}$wpa_key${NC}"
    echo "****************************************************************************************"
    hostapd $HOME/hostapd.conf
}

function startRouting {
    ifaces="$(ip link show | grep -v 'lo:' | grep -v altname | grep -v link | awk '{print $2}' | tr -d ':')"
    x=1
    for iface in $ifaces; do
        echo "$x - $iface"
        x=$((x + 1))
    done
    echo "Select the interface for bridge routing, the once is connected to internet:"
    read selection
    router_selected="$(echo $ifaces | tr ' ' '\n' | head -n $selection)"
    echo "router_iface $router_selected"
    #since apparmor is extended on GNU/Linux this is the easiest way to use dhcp config file
    cp dhcpd_quickap.conf /etc/dhcp/dhcpd_quickap.conf
    dhcpd -cf /etc/dhcp/dhcpd_quickap.conf
    echo 1 >/proc/sys/net/ipv4/ip_forward
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -P INPUT ACCEPT
    iptables -A FORWARD -o $wireless_iface_selected -j ACCEPT
    iptables -t nat -A POSTROUTING -o $router_selected -j MASQUERADE
    echo "NEW IPTABLES RULES:"
    iptables -nvL | grep all
    iptables -t nat -nvL | grep all
    sleep 3
}

IP=10.0.0.1
RED='\033[0;31m'
NC='\033[0m'
echo ""
clear
the_Title

#Setup
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi
if ! [ -x "$(command -v hostapd)" ]; then
    echo 'Error: hostapd is not installed.' >&2
    exit 1
fi

if ! [ -x "$(command -v dhcpd)" ]; then
    echo 'Error: isc-dhcp-server is not installed.' >&2
    exit 1
fi

if lsof -Pi :53 -sTCP:LISTEN -t >/dev/null; then
    lsof -Pi :53
    echo -e "${RED}Some proces is running on port 53, please stop it before launch this script${NC}"
    exit 1
fi
echo "Setting up...."
service isc-dhcp-server stop

#Select wireless inteface
wireless_ifaces="$(iw dev | grep Interface | awk '{print $2}')"
x=1
for iface in $wireless_ifaces; do
    echo "$x - $iface"
    x=$((x + 1))
done
echo "Select the interface for AP mode:"
read selection


#AP Settings
wireless_iface_selected="$(echo $wireless_ifaces | head -n $selection)"
echo "selected: $wireless_iface_selected"
sed "s/INTERFACESv4=.*/INTERFACESv4=\"$wireless_iface_selected\"/g" isc-dhcp-server.sample > /etc/default/isc-dhcp-server
sed "s/interface=.*/interface=$wireless_iface_selected/g" hostapd_sample.conf > $HOME/hostapd.conf
echo "Enter name for the Network-AP:"
read ssid
sed -i "s/ssid=.*/ssid=$ssid/g" $HOME/hostapd.conf 
echo "Enter the paraphrase:"
read wpa_key
sed -i "s/wpa_passphrase=.*/wpa_passphrase=$wpa_key/g" $HOME/hostapd.conf

#setup the desired IP
ip a add $IP dev $wireless_iface_selected 

#AP Firewall routing and dhcpd
echo "Activate firewall rules for Internet bride sharing?(y/n):"
read activate_yn
case $activate_yn in
"y") startRouting ;;
"n") start_hostapd ;;
esac

#start_hostapd
