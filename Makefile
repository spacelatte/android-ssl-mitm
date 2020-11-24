#!//usr/bin/env -S make -f

PROJECT_NAME     := mitm
ANDROID_SDK_ROOT := $(ANDROID_SDK_ROOT)
HOST_ADDRESS     := $(shell ipconfig getifaddr en0 || hostname -i )
EMULATOR_VER     := android-25
EMULATOR_ARCH    := x86_64
EMULATOR_NAME    := androidemu
EMULATOR_IMAGE   := system-images/$(EMULATOR_VER)/google_apis/$(EMULATOR_ARCH)
EMULATOR_DEVICE  := Nexus 5
EMULATOR_MEMORY  := 2048

ifndef  ANDROID_SDK_ROOT
$(error ANDROID_SDK_ROOT is not set)
endif

ifeq ($(ANDROID_SDK_ROOT),)
$(error ANDROID_SDK_ROOT must not be empty)
endif

all: containers virtualdevice

logs:
	docker-compose -p $(PROJECT_NAME) logs --tail=1 -f

containers:
	ADDRESS=$(HOST_ADDRESS) \
		docker-compose -p $(PROJECT_NAME) up -d --build --remove-orphans \
		;

space :=
space +=
virtualdevice: $(ANDROID_SDK_ROOT)/$(EMULATOR_IMAGE) ~/.android/avd/$(EMULATOR_NAME).avd
	$(ANDROID_SDK_ROOT)/emulator/emulator \
		-shell \
		-verbose \
		-wipe-data \
		-no-boot-anim \
		-skip-adb-auth \
		-writable-system \
		-avd "$(EMULATOR_NAME)" \
		-dns-server "$(HOST_ADDRESS)" \
		-skin "$(subst $(space),_,$(EMULATOR_DEVICE))" \
		-skindir "$(ANDROID_SDK_ROOT)/skins" \
		-memory "$(EMULATOR_MEMORY)" \
		-prop debug.hwui.renderer=skiagl \
		;

~/.android/avd/$(EMULATOR_NAME).avd:
	$(ANDROID_SDK_ROOT)/tools/bin/avdmanager -v create avd -f \
		-k "$(subst /,;,$(EMULATOR_IMAGE))" \
		-d "$(EMULATOR_DEVICE)" \
		-n "$(EMULATOR_NAME)" \
		;
	echo hw.keyboard=yes | tee -a ~/.android/avd/$(EMULATOR_NAME).avd/config.ini

$(ANDROID_SDK_ROOT)/$(EMULATOR_IMAGE):
	$(ANDROID_SDK_ROOT)/tools/bin/sdkmanager --install "$(subst /,;,$(EMULATOR_IMAGE))"

clean:
	-docker-compose down -v --remove-orphans
	-killall qemu-system-$(EMULATOR_ARCH)
	-$(ANDROID_SDK_ROOT)/tools/bin/avdmanager -v delete avd -n "$(EMULATOR_NAME)"

domains: ssl
	find $< -iname '*.pub' -exec basename {} .pub \;
