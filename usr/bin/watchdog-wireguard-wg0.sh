#!/bin/bash
# WireGuard interface name

# Get the last handshake time for the peer
LAST_HANDSHAKE=$(wg show $WG_INTERFACE latest-handshakes | grep "$PEER_PUBKEY" | awk '{print $2}')
# Get the current time
CURRENT_TIME=$(date +%s)

if [ -z "$LAST_HANDSHAKE" ]; then
    echo "Peer $PEER_PUBKEY has no recorded handshake."
else
    # Calculate the time elapsed since the last handshake
    ELAPSED_TIME=$((CURRENT_TIME - LAST_HANDSHAKE))

    if [ $ELAPSED_TIME -ge 120 ]; then
        echo "Peer $PEER_PUBKEY handshake timeout. Reconnecting..."
        # Set the endpoint again to trigger reconnection
        wg set $WG_INTERFACE peer $PEER_PUBKEY endpoint $PEER_ENDPOINT
        echo "Reconnected peer $PEER_PUBKEY to $PEER_ENDPOINT"
    else
        echo "Peer $PEER_PUBKEY is active. Last handshake $ELAPSED_TIME seconds ago."
    fi
fi
