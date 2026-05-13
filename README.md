# netbird-mullvad-bypass

Mullvad's nftables rules interfere with NetBird's traffic, even when LAN traffic is allowed. This package prevents Mullvad's rules from dropping or misrouting NetBird traffic.

## The problem

* Mullvad has a filter chain (`table inet mullvad`) with `policy drop` on everything except `ct mark 0x00000f41`
* Mullvad's routing table catches every packet without `meta mark 0x6d6f6c65` (its split-tunnel skip mark)
* NetBird expects to send control plane traffic out the physical interface
* NetBird expects to carry overlay traffic on `wt0`
* NetBird expects to route networks exposed by peers via its own routing table

* Mullvad's filter chains drop NetBird packets
* Mullvad's routing table takes priority over NetBird's

## The solution

This package installs a single nftables table (`inet netbird-mullvad-bypass`) with its filter/route chains at priority -199, after the kernel conntrack hook (-200) and before the Mullvad filter chains (0).
A separate NAT chain runs at `srcnat - 5` so its masquerade wins the conntrack race against Mullvad's and any other NAT rules sitting at the default srcnat priority.

* Stamp Mullvad's accept mark `ct mark 0x00000f41` on every NetBird packet, so Mullvad's filter chain accepts them.
* Re-mark NetBird packets with Mullvad's split-tunnel mark (`meta mark 0x6d6f6c65`), so Mullvad's routing table skips them and the kernel falls through to the next table
* Masquerade re-routed routed-network traffic to wt0's IP, because the kernel doesn't always re-pick a source address when our `type route` chain re-evaluates routing

It also installs a netlink watcher service that mirrors NetBird's routing table 7120 into an nft set, so newly exposed peer networks are picked up without manual intervention. Mullvad or NetBird restarting will tear down and rewrite their own rules; the watcher re-runs the populate script on every route change in table 7120 so the set stays in sync.

## Installation

Packages are provided for Arch, Fedora/RHEL, and Debian/Ubuntu. Download the latest release from the [releases page](https://github.com/d10n/netbird-mullvad-bypass/releases).

For Arch, the AUR has `netbird-mullvad-bypass`.

## Notes

### Mark index

| Mark         | Purpose               | Origin                                                     |
|--------------|-----------------------|------------------------------------------------------------|
| `0x0001bd00` | NetBird control plane | `netbird/client/net/net.go`                                |
| `0x6d6f6c65` | Mullvad split-tunnel  | `mullvadvpn-app/mullvad-types/src/lib.rs`                  |
| `0x00000f41` | Mullvad filter accept | `mullvadvpn-app/talpid-core/src/split_tunnel/linux/mod.rs` |

### Inspecting state

```sh
# What's in the routed-network set
sudo nft list set inet netbird-mullvad-bypass nb_routed

# Full bypass ruleset
sudo nft list table inet netbird-mullvad-bypass

# Verify routing for a routed-network destination
ip route get 192.168.1.10                  # would-be (unmarked) path
ip route get 192.168.1.10 mark 0x6d6f6c65  # post-bypass path (should hit wt0)
```

## Troubleshooting

### `ping 192.168.1.x` times out

Most likely cause: the destination network isn't in the `nb_routed` set.

```sh
# Is the route in NetBird's table?
ip -4 route show table 7120

# Is the watcher running?
systemctl status netbird-mullvad-bypass-watch.service

# Force a refresh
sudo systemctl restart netbird-mullvad-bypass.service
```

If the route is in table 7120 but the set is empty, check the watcher journal:
* `journalctl -u netbird-mullvad-bypass-watch.service`

### `ping 100.64.x.y` works but `ping 192.168.1.x` doesn't

Specifically the routed-network case. Check that masquerade is firing:

```sh
sudo conntrack -L | grep 192.168.1
# Expect: src=<some IP> dst=192.168.1.x ... mark=3905
#         src=192.168.1.x dst=100.64.<your wt0 IP> ...
# (mark=3905 is 0xf41; the reply tuple's dst should be your wt0 IP)
```

If reply-tuple dst is the `wg0-mullvad` IP instead, masquerade isn't firing.
Verify the `nat-postrouting` chain exists in the bypass table.

### Nothing works after Mullvad / NetBird restart

```sh
sudo systemctl restart netbird-mullvad-bypass.service
```

This regenerates the bypass table. The watcher restarts automatically via `PartOf=`.

### Constants have changed

* NetBird's `SO_MARK` and Mullvad's marks are constants in their respective source trees
* NetBird hardcodes `wt0` and Mullvad hardcodes `wg0-mullvad`

If any of these constants change, please file a bug or a PR.

## Limitations

- IPv4 only
  - NetBird just merged IPv6 support on 2026-05-07 but hasn't published a release at the time of writing

## License

MIT.
