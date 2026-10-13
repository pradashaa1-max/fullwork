ARCHS = arm64
TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AstralCheat

AstralCheat_FILES = src/cheat.mm
AstralCheat_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore
AstralCheat_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-deprecated-declarations -std=c++17
AstralCheat_CCFLAGS = -std=c++17
AstralCheat_LDFLAGS = -ObjC

include $(THEOS_MAKE_PATH)/tweak.mk

after-package::
	@echo "=== dylib ==="
	@find packages .theos -name "*.dylib" 2>/dev/null | head -5
