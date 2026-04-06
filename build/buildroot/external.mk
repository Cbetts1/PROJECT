################################################################################
# build/buildroot/external.mk — AIOS-Lite Buildroot external tree
#
# Included by Buildroot when BR2_EXTERNAL points here.
# Declares the aios-lite package so it is available in menuconfig.
################################################################################

include $(sort $(wildcard $(BR2_EXTERNAL_AIOS_PATH)/package/*/*.mk))
