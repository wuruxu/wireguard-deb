#!/bin/bash
# Get the last handshake time for the peer
LAST_HANDSHAKE=$(ip netns exec wg0-ns wg show $WG_INTERFACE latest-handshakes | grep "$PEER_PUBKEY" | awk '{print $2}')
# Get the current time
CURRENT_TIME=$(date +%s)

if [ -z "$LAST_HANDSHAKE" ]; then
    echo "Peer $PEER_PUBKEY has no recorded handshake."
    bash /usr/bin/wireguard-wg0.sh
else
    # Calculate the time elapsed since the last handshake
    ELAPSED_TIME=$((CURRENT_TIME - LAST_HANDSHAKE))

    if [ $ELAPSED_TIME -ge 120 ]; then
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

            echo "Hostname: $hostname" "Port: $port"

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
            echo "Peer $PEER_PUBKEY handshake timeout. Reconnecting..."
            # Set the endpoint again to trigger reconnection
            ip netns exec wg0-ns wg set $WG_INTERFACE peer $PEER_PUBKEY endpoint $PEER_ENDPOINT
            echo "Reconnected peer $PEER_PUBKEY to $PEER_ENDPOINT"
        fi
    else
        echo "Peer $PEER_PUBKEY is active. Last handshake $ELAPSED_TIME seconds ago."
    fi
fi
