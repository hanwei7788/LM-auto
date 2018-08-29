#! /bin/sh
set -x
ip addr add 10.11.12.13/24 dev veth1
if [ "$2" = "ics" ]
then
    ip route add default via 10.11.12.1
#   echo "nameserver 217.30.180.230" > /etc/resolv.conf
#   echo "Using Tampere office nameserver. Edit /root/container3.sh on host to use another nameserver in later boots"
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "Using Google nameserver. Edit /root/container3.sh on host to use another nameserver in later boots"
else
   ip route add "$1" via 10.11.12.1
fi

