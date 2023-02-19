#!/bin/bash
function the_Title {
    echo ""
    echo "┏━┓╻ ╻╻┏━╸╻┏ ┏━┓┏━┓ ┏━┓╻ ╻"
    echo "┃┓┃┃ ┃┃┃  ┣┻┓┣━┫┣━┛ ┗━┓┣━┫"
    echo "┗┻┛┗━┛╹┗━╸╹ ╹╹ ╹╹  ╹┗━┛╹ ╹ by pmartinezr@proton.me GNU/GPLv3"
}

function start_hostapd {
   #Hostapd 
   echo "****************************************************************************************"
   echo -e "Trying to init hostapd AP with name ${RED}$ssid${NC} and wpa-key: ${RED}$wpa_key${NC}"
   echo "****************************************************************************************"
    hostapd ~/hostapd.conf
}

function startRouting {
	ifconfig | grep flags | grep -v lo: | awk '{FS=":";print $1}' | sed 's/://g' > connected_ifaces.txt
	#ifaces="$(ifconfig | grep flags | grep -v lo: | awk '{FS=":";print $1}' | sed 's/://g' )"
    ifaces="$( ip link show | grep -v 'lo:' | grep -v altname | grep -v link |  awk '{print $2}' | sed 's/://g')"  
    x=1
	for iface in $ifaces
	do
		echo "$x - $iface"
		x=$((x + 1))
	done
	echo "Select the interface for bridge routing, the once is connected to internet:"
    read selection
    router_selected="$(head -n $selection connected_ifaces.txt | tail -1)"
    dhcpd -cf dhcpd.conf 
    echo 1 > /proc/sys/net/ipv4/ip_forward
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -P INPUT ACCEPT
    iptables -A FORWARD -o $wireless_iface_selected -j ACCEPT
    iptables -t nat -A POSTROUTING -o $router_selected -j MASQUERADE
    clear
    the_Title
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
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
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

if lsof -Pi :53 -sTCP:LISTEN -t >/dev/null ; then
    lsof -Pi :53 
    echo -e "${RED}Some proces is running on port 53, please stop it before launch this script${NC}"
    exit 1
fi
echo "Setting up...."
service isc-dhcp-server stop

#Select wireless inteface
iw dev | grep Interface | awk '{print $2}' > wireless_ifaces.txt
wireless_ifaces="$(iw dev | grep Interface | awk '{print $2}')"
x=1
for iface in $wireless_ifaces
do
    echo "$x - $iface"
    x=$((x + 1))
done
echo "Select the interface for AP mode:"
read selection

#AP Settings
wireless_iface_selected="$(head -n $selection wireless_ifaces.txt | tail -1)"
sed "s/INTERFACESv4=.*/INTERFACESv4=\"$wireless_iface_selected\"/g" isc-dhcp-server.sample > /etc/default/isc-dhcp-server 
sed "s/interface=.*/interface=$wireless_iface_selected/g" hostapd_sample.conf >  $HOME/hostapd.conf
echo "Enter name for the Network-AP:"
read ssid
sed "s/ssid=.*/ssid=$ssid/g"  $HOME/hostapd.conf > $HOME/tmp_hostapd.conf 
echo "Enter the paraphrase:"
read wpa_key
sed "s/wpa_passphrase=.*/wpa_passphrase=$wpa_key/g" $HOME/tmp_hostapd.conf > $HOME/hostapd.conf
#dont sure this line is needed with isc-dhcp-server
ifconfig $wireless_iface_selected $IP 


#AP Firewall routing and dhcpd
clear
the_Title
echo "Activate firewall rules for Internet bride sharing?(y/n):"
read activate_yn
case $activate_yn in
    "y" ) startRouting ;;
    "n" ) start_hostapd;;
esac

start_hostapd


#Restoring stuff
#mv /etc/dhcp/dhcpd.conf.old /etc/dhcp/dhcpd.conf
rm $HOME/hostapd.conf
rm $HOME/tmp_hostapd.conf








