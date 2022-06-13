#!/bin/sh

BRIFACE="br-lan"
PORT_WAN="eth0"
PORT_LAN="eth1"
BRMAC=`cat /sys/class/net/$BRIFACE/address`
BR_IP=`192.168.8.1`

start(){
	ebtables -t broute -A BROUTING -i  $PORT_LAN -p  arp  -j ACCEPT
	ebtables -t broute -A BROUTING -i $PORT_LAN -p IPV4 --ip-protocol udp --ip-source-port 68 -j  ACCEPT
	ebtables -t broute -A BROUTING  -i $PORT_LAN  -j   redirect --redirect-target  DROP
	
	iptables -N BROUTER
	iptables -t nat  -N BROUTER
	iptables -I FORWARD -j BROUTER
	iptables -t nat -I POSTROUTING -j BROUTER
}

update(){
	gaddr=$1
	saddr=$2
	iptables -t nat -F BROUTER
	iptables -t nat -I BROUTER -o br-lan  -s  $BR_IP -j SNAT --to-source "$saddr"
	iptables -t nat -I BROUTER -o br-lan  ! -d  "$gaddr"/24 -j SNAT --to-source "$saddr"

	iptables -F BROUTER
	iptables -I BROUTER -j ACCEPT

	ebtables -t nat -F
	ebtables -t nat -A PREROUTING -p arp --arp-opcode Request --arp-ip-dst "$saddr" -j arpreply --arpreply-mac $BRMAC --arpreply-target DROP
	ebtables -t nat -A PREROUTING -p arp --arp-opcode Request --arp-ip-dst "$gaddr" -j arpreply --arpreply-mac $BRMAC --arpreply-target DROP

	ip route add 0.0.0.0/0 via "$gaddr" dev br-lan scope global
}

stop(){

	iptables -t nat -D POSTROUTING -j BROUTER
	iptables -t nat -F BROUTER
	iptables -t nat -X BROUTER

	iptables -D POSTROUTING -j BROUTER
	iptables -F BROUTER
	iptables -X BROUTER

	ebtables -t broute -F 
	ebtables -t nat -F
}

case $1 in
	"start")
		stop
		start
	;;
	"stop")
		stop
	;;
	"update")
		update "$2" "$3"
	;;
	*)
esac
