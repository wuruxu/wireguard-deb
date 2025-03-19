#!/bin/bash
WG_IP4ADDR=192.108.18.8
WG_IP6ADDR=fd08:1008:18::8
DEFAULT_ROUTE_LINE=$(ip route show default 0.0.0.0/0 | head -n1)
if [ -z "$DEFAULT_ROUTE_LINE" ]; then
  echo "ERROR: No default route found on this system."
  exit 1
fi

LOCAL_GATEWAY=$(echo "$DEFAULT_ROUTE_LINE" | awk '{print $3}')
LOCAL_IF=$(echo "$DEFAULT_ROUTE_LINE" | awk '{print $5}')

echo "Detected local gateway: $LOCAL_GATEWAY"
echo "Detected local interface: $LOCAL_IF"

if [[ "$PEER_ENDPOINT" =~ ^([^:]+):([0-9]+)$ ]]; then
  hostname="${BASH_REMATCH[1]}"
  port="${BASH_REMATCH[2]}"

  echo "Hostname: $hostname"
  echo "Port: $port"

  #ip_address=$(nslookup "$hostname" | awk '/Address: / {print $2; exit}')
  ip_address=$(getent hosts "$hostname" | awk '{print $1}')


  if [[ -n "$ip_address" ]]; then
    echo "IP Address: $ip_address"
  else
    echo "Failed to resolve hostname: $hostname"
  fi
  if ! ip route show $ip_address | grep -q "$LOCAL_GATEWAY dev $LOCAL_IF"; then
    echo "ip route add for $ip_address"
    ip route add ${ip_address}/32 via ${LOCAL_GATEWAY} dev ${LOCAL_IF}
  fi
  ip netns exec wg0-ns ip link del dev $WG_INTERFACE
  ip netns del wg0-ns
  ip netns add wg0-ns
  ip link add dev $WG_INTERFACE type wireguard
  ip link set $WG_INTERFACE netns wg0-ns
  ip netns exec wg0-ns ip address add dev $WG_INTERFACE $WG_IP4ADDR/24
  ip netns exec wg0-ns ip -6 address add dev $WG_INTERFACE $WG_IP6ADDR/64
  ip netns exec wg0-ns wg set $WG_INTERFACE private-key /etc/wg0/private.key
  ip link add veth-host type veth peer name veth-ns netns wg0-ns
  ip link set veth-host up
  ip addr add 192.168.222.1/24 dev veth-host
  ip netns exec wg0-ns sysctl -w net.ipv4.ip_forward=1
  ip netns exec wg0-ns ip link set veth-ns up
  ip netns exec wg0-ns ip addr add 192.168.222.2/24 dev veth-ns
  ip netns exec wg0-ns ip route add default via 192.168.222.1
  iptables -t nat -I POSTROUTING 1 -s 192.168.222.0/24 -j MASQUERADE
  if [[ -f /etc/wg0/preshared.key ]]; then
    ip netns exec wg0-ns wg set $WG_INTERFACE peer $PEER_PUBKEY preshared-key /etc/wg0/preshared.key endpoint $PEER_ENDPOINT persistent-keepalive 60 allowed-ips 192.168.111.0/24,fd08:5399:1111::/64
  else
    ip netns exec wg0-ns wg set $WG_INTERFACE peer $PEER_PUBKEY endpoint $PEER_ENDPOINT persistent-keepalive 60 allowed-ips 192.168.111.0/24,fd08:5399:1111::/64
  fi
  ip netns exec wg0-ns ip link set up dev $WG_INTERFACE
  ip netns exec wg0-ns iptables -t nat -A PREROUTING -d $WG_IP4ADDR/32 -p tcp --dport 22 -j DNAT --to-destination 192.168.222.1:22
  ip netns exec wg0-ns iptables -t nat -A POSTROUTING -p tcp -d 192.168.222.1 --dport 22 -j MASQUERADE
fi
