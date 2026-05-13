PKG     := netbird-mullvad-bypass
VERSION := $(shell cat VERSION)

DIST_FILES := \
	VERSION \
	README.md \
	netbird-mullvad-bypass.nft \
	netbird-mullvad-bypass.service \
	netbird-mullvad-bypass-watch.service \
	populate-routed-nets.sh \
	watch-routed-nets.sh

DIST_DIR  := dist
BUILD_DIR := build

TARBALL   := $(DIST_DIR)/$(PKG)-$(VERSION).tar.gz

.PHONY: all dist arch rpm deb bump bump-do clean help unpackaged-install

help:
	@echo "Targets:"
	@echo "  make dist               - produce $(TARBALL)"
	@echo "  make arch               - build .pkg.tar.zst (Arch, local tarball)"
	@echo "  make rpm                - build .rpm (Fedora)"
	@echo "  make deb                - build .deb (Debian)"
	@echo "  make bump NEW=x.y.z     - update VERSION + sync PKGBUILD/.spec/changelog"
	@echo "  make clean              - remove build artifacts"
	@echo "  make unpackaged-install - install files manually (no package)"

dist: $(TARBALL)

$(TARBALL): $(DIST_FILES)
	@mkdir -p $(DIST_DIR) $(BUILD_DIR)/dist
	@rm -rf $(BUILD_DIR)/dist/$(PKG)-$(VERSION)
	@mkdir -p $(BUILD_DIR)/dist/$(PKG)-$(VERSION)
	cp -a $(DIST_FILES) $(BUILD_DIR)/dist/$(PKG)-$(VERSION)/
	tar -C $(BUILD_DIR)/dist -czf $@ $(PKG)-$(VERSION)
	@echo "==> $@"

arch: $(TARBALL)
	@mkdir -p $(DIST_DIR)
	cp $(TARBALL) packaging/arch/
	cd packaging/arch && makepkg -f
	rm -f packaging/arch/$(PKG)-$(VERSION).tar.gz
	cp packaging/arch/$(PKG)-$(VERSION)-*.pkg.tar.zst $(DIST_DIR)/
	@echo "==> $(DIST_DIR)/$(PKG)-$(VERSION)-*.pkg.tar.zst"

rpm: $(TARBALL)
	@mkdir -p $(DIST_DIR) $(BUILD_DIR)/rpm/SOURCES $(BUILD_DIR)/rpm/SPECS
	cp $(TARBALL) $(BUILD_DIR)/rpm/SOURCES/
	cp packaging/rpm/$(PKG).spec $(BUILD_DIR)/rpm/SPECS/
	rpmbuild --define "_topdir $(CURDIR)/$(BUILD_DIR)/rpm" \
	         -ba $(BUILD_DIR)/rpm/SPECS/$(PKG).spec
	cp $(BUILD_DIR)/rpm/RPMS/noarch/*.rpm $(DIST_DIR)/
	cp $(BUILD_DIR)/rpm/SRPMS/*.rpm       $(DIST_DIR)/
	@echo "==> $(DIST_DIR)/*.rpm"

deb: $(TARBALL)
	@mkdir -p $(DIST_DIR)
	rm -rf $(BUILD_DIR)/deb
	mkdir -p $(BUILD_DIR)/deb/$(PKG)-$(VERSION)
	cp -a $(DIST_FILES) $(BUILD_DIR)/deb/$(PKG)-$(VERSION)/
	cp -aL packaging/debian $(BUILD_DIR)/deb/$(PKG)-$(VERSION)/debian
	cd $(BUILD_DIR)/deb/$(PKG)-$(VERSION) && dpkg-buildpackage -us -uc -b
	cp $(BUILD_DIR)/deb/$(PKG)_$(VERSION)-*_all.deb $(DIST_DIR)/
	@echo "==> $(DIST_DIR)/$(PKG)_$(VERSION)-*_all.deb"

bump:
	@if [ -z "$(NEW)" ]; then echo "Usage: make bump NEW=x.y.z"; exit 1; fi
	@if [ "$(NEW)" = "$(VERSION)" ]; then echo "VERSION already $(NEW)"; \
	 else $(MAKE) --no-print-directory bump-do NEW="$(NEW)"; fi

bump-do:
	echo "$(NEW)" > VERSION
	sed -i "s/^pkgver=.*/pkgver=$(NEW)/" packaging/arch/PKGBUILD
	sed -i "s/^Version: .*/Version:        $(NEW)/" packaging/rpm/$(PKG).spec
	@NAME="$$(git config user.name)"; \
	 EMAIL="$$(git config user.email)"; \
	 DEB_DATE="$$(date -R)"; \
	 RPM_DATE="$$(date +'%a %b %d %Y')"; \
	 { \
	    printf "%s (%s-1) unstable; urgency=medium\n\n" "$(PKG)" "$(NEW)"; \
	    printf "  * Release %s.\n\n" "$(NEW)"; \
	    printf " -- %s <%s>  %s\n\n" "$$NAME" "$$EMAIL" "$$DEB_DATE"; \
	    #cat packaging/debian/changelog; \
	 } > packaging/debian/changelog.new && \
	 mv packaging/debian/changelog.new packaging/debian/changelog && \
	 RPM_CHANGE="$$(printf '* %s %s <%s> - %s-1\n- Release %s.\n' \
	                "$$RPM_DATE" "$$NAME" "$$EMAIL" "$(NEW)" "$(NEW)")"; \
	 awk -vnew="$$RPM_CHANGE" '/^%changelog/{ \
	     print; \
	     print new; \
	     print ""; \
	     exit; # comment to preserve the rest \
	     next; \
	   } 1' \
	   packaging/rpm/$(PKG).spec > packaging/rpm/$(PKG).spec.new && \
	 mv packaging/rpm/$(PKG).spec.new packaging/rpm/$(PKG).spec
	@echo "==> Bumped to $(NEW). Review:"
	@echo "    git diff VERSION packaging/"

unpackaged-install:
	@echo "==> Installing $(PKG) files..."
	install -Dm644 netbird-mullvad-bypass.service /etc/systemd/system/netbird-mullvad-bypass.service
	install -Dm644 netbird-mullvad-bypass-watch.service /etc/systemd/system/netbird-mullvad-bypass-watch.service
	install -Dm644 netbird-mullvad-bypass.nft /usr/lib/$(PKG)/netbird-mullvad-bypass.nft
	install -Dm755 populate-routed-nets.sh /usr/lib/$(PKG)/populate-routed-nets.sh
	install -Dm755 watch-routed-nets.sh /usr/lib/$(PKG)/watch-routed-nets.sh
	@echo "==> Reloading systemd..."
	systemctl daemon-reload
	@echo "==> Done. Enable with:"
	@echo "    sudo systemctl enable --now netbird-mullvad-bypass"

clean:
	rm -rf $(DIST_DIR) $(BUILD_DIR)
	rm -rf packaging/arch/src packaging/arch/pkg packaging/arch/*.pkg.tar.zst
