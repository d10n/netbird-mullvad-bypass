Name:           netbird-mullvad-bypass
Version:        1.2.0
Release:        1%{?dist}
Summary:        Allow Mullvad and Netbird to coexist

License:        MIT
URL:            https://github.com/d10n/netbird-mullvad-bypass
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  systemd-rpm-macros
Requires:       nftables, iproute
Recommends:     netbird, mullvad-vpn
%{?systemd_requires}

%description
nftables and systemd glue that prevents Mullvad's rules from dropping or
misrouting NetBird traffic

%prep
%autosetup

%install
install -Dm644 netbird-mullvad-bypass.service \
    %{buildroot}%{_unitdir}/netbird-mullvad-bypass.service
install -Dm644 netbird-mullvad-bypass-watch.service \
    %{buildroot}%{_unitdir}/netbird-mullvad-bypass-watch.service
# Literal /usr/lib instead of %{_libdir} so paths match the
# hardcoded script references on x86_64 (%{_libdir} = /usr/lib64)
install -Dm644 netbird-mullvad-bypass.nft \
    %{buildroot}/usr/lib/%{name}/netbird-mullvad-bypass.nft
install -Dm755 populate-routed-nets.sh \
    %{buildroot}/usr/lib/%{name}/populate-routed-nets.sh
install -Dm755 watch-routed-nets.sh \
    %{buildroot}/usr/lib/%{name}/watch-routed-nets.sh

%post
%systemd_post netbird-mullvad-bypass.service netbird-mullvad-bypass-watch.service

%preun
%systemd_preun netbird-mullvad-bypass.service netbird-mullvad-bypass-watch.service

%postun
%systemd_postun_with_restart netbird-mullvad-bypass.service netbird-mullvad-bypass-watch.service

%files
%doc README.md
%{_unitdir}/netbird-mullvad-bypass.service
%{_unitdir}/netbird-mullvad-bypass-watch.service
%dir /usr/lib/%{name}
/usr/lib/%{name}/netbird-mullvad-bypass.nft
/usr/lib/%{name}/populate-routed-nets.sh
/usr/lib/%{name}/watch-routed-nets.sh

%changelog
* Wed May 13 2026 d10n <david@bitinvert.com> - 1.2.0-1
- Release 1.2.0.

