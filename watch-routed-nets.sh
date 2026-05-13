#!/bin/sh
# Subscribe to the kernel's IPv4 route netlink group via `ip monitor`
# and refresh the nb_routed nft set whenever a route in NetBird's
# routing table (7120 = 0x1bd0) is added or removed.
# NetBird installs/removes routes as policy changes; without this watcher,
# we would have to restart bypass.service after every policy change.

set -eu

populate=/usr/lib/netbird-mullvad-bypass/populate-routed-nets.sh
nb_table=7120

ip -4 monitor route | {
    # populate is atomic and idempotent, so racing with bypass.service's own ExecStartPost is harmless.
    # No `|| true` here on purpose: a failure at startup propagates out the pipeline and lets systemd's
    # Restart=on-failure kick in
    "$populate"

    # `ip monitor` lines look like:
    #   10.0.0.0/24 dev wt0 table 7120
    #   Deleted 10.0.0.0/24 dev wt0 table 7120
    while IFS= read -r line; do
        case " $line " in
            *" table $nb_table "*)
                "$populate" || true
                ;;
        esac
    done
}
