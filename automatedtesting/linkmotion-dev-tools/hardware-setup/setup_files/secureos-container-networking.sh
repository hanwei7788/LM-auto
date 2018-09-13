#! /bin/sh
set -x
ip addr add 10.11.13.13/24 dev secg
ip link set secg up
ip route add default via 10.11.13.1
echo "nameserver 8.8.8.8" > /etc/resolv.conf 
echo Using Google nameserver. Edit /etc/resolv.conf in container if you want to use another nameserver.

