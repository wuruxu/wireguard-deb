#!/bin/bash
ip link del dev $WG_INTERFACE
ip link add dev $WG_INTERFACE type wireguard
ip address add dev $WG_INTERFACE 192.168.108.22/24
ip -6 address add dev $WG_INTERFACE 'fd08:5399:1008::22/64'
wg set $WG_INTERFACE private-key /etc/wg0/private.key
wg set $WG_INTERFACE peer $PEER_PUBKEY endpoint $PEER_ENDPOINT persistent-keepalive 60 allowed-ips 192.168.108.0/24,fd08:5399:1008::/64
ip link set up dev $WG_INTERFACE
