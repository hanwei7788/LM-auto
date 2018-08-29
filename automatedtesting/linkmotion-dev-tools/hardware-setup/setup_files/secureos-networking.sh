#! /bin/sh
echo
echo Setting up networking for secureos container..
set -x
ip link add sech type veth peer name secg
pid=$(pgrep -x -U secureuser init)
ip link set dev secg netns ${pid}
ip addr add 10.11.13.1/24 dev sech
iptables  -t nat -A POSTROUTING -s 10.11.13.0/24 -o eth0 -j MASQUERADE
echo 1 > /proc/sys/net/ipv4/ip_forward
cp secureos-container-networking.sh /altdata/lxc/secure/rootfs/root/
echo Running container-side setup script..
lxc-attach -P /usr/lib/lm_containers -n secure -- /root/secureos-container-networking.sh
echo
echo Networking should now work inside container.
echo

