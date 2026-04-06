################################################################################
# build/buildroot/package/aios-lite/aios-lite.mk
#
# Buildroot package makefile for AIOS-Lite.
# Installs the project tree from the repo root into /opt/aios on the target.
################################################################################

AIOS_LITE_VERSION    = 1.0.0
AIOS_LITE_SITE       = $(BR2_EXTERNAL_AIOS_PATH)/../..
AIOS_LITE_SITE_METHOD = local
AIOS_LITE_LICENSE    = MIT
AIOS_LITE_LICENSE_FILES = LICENSE

define AIOS_LITE_INSTALL_TARGET_CMDS
	$(INSTALL) -d $(TARGET_DIR)/opt/aios
	rsync -a --exclude='.git' --exclude='build/buildroot/work' \
		$(AIOS_LITE_SITE)/ $(TARGET_DIR)/opt/aios/
	chmod +x $(TARGET_DIR)/opt/aios/bin/aios
	chmod +x $(TARGET_DIR)/opt/aios/bin/aios-sys
	chmod +x $(TARGET_DIR)/opt/aios/bin/aios-heartbeat
	ln -sf /opt/aios/bin/aios $(TARGET_DIR)/usr/local/bin/aios
endef

$(eval $(generic-package))
