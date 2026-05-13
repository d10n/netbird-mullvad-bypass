#!/bin/sh
# Mirror NetBird's routing table (7120 = 0x1bd0) into the netbird-mullvad-bypass `nb_routed` set
# client/internal/routemanager/systemops/systemops_linux.go # NetbirdVPNTableID = 0x1BD0

set -eu

nft_table='inet netbird-mullvad-bypass'
nft_set='nb_routed'
nb_table=7120

# Only CIDR-form prefixes; skip "default" and anything that doesn't look like a route entry.
# Before NetBird has published any routes, table 7120 doesn't exist and
# `ip route show` prints "Error: ipv4: FIB table does not exist." (exit 2)
prefixes="$(ip -4 route show table "$nb_table" 2>/dev/null | awk '$1 ~ /\//{print $1}' || true)"

if [ -z "$prefixes" ]; then
    nft flush set "$nft_table" "$nft_set"
    exit 0
fi

elements="$(echo "$prefixes" | paste -sd ',')"
nft -f - <<EOF
flush set $nft_table $nft_set
add element $nft_table $nft_set { $elements }
EOF
