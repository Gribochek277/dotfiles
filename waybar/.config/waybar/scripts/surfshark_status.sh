#!/bin/bash

STATUS=$(surfshark-vpn status)

if [ "$STATUS" != "Not connected to Surfshark VPN" ]; then
    LOCATION=$(surfshark-vpn status | grep "Location:" | awk '{$1=""; print $0}')
    echo "{Surfshark: Connected $LOCATION 🔒}"
elif [ "$STATUS" == "Not connected to Surfshark VPN" ]; then
    echo "{Surfshark: Disconnected}"
else
    echo "{Surfshark: unknonown}"
fi
