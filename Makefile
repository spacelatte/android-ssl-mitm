#!//usr/bin/env -S make -f

PROJECT_NAME     := mitm
ANDROID_SDK_ROOT := $(ANDROID_SDK_ROOT)
HOST_ADDRESS     := $(shell ipconfig getifaddr en0 )
EMILATOR_ARCH    := x86_64
EMULATOR_NAME    := androidemu
EMULATOR_IMAGE   := system-images;android-25;google_apis;$(EMILATOR_ARCH)
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
virtualdevice: ~/.android/avd/$(EMULATOR_NAME).avd ~/.android/avd/$(EMULATOR_NAME).ini
	$(ANDROID_SDK_ROOT)/emulator/emulator -verbose -shell \
		-wipe-data -writable-system -skip-adb-auth -no-boot-anim \
		-avd "$(EMULATOR_NAME)" -dns-server "$(HOST_ADDRESS)" \
		-skin "$(subst $(space),_,$(EMULATOR_DEVICE))" \
		-skindir "$(ANDROID_SDK_ROOT)/skins" \
		-memory "$(EMULATOR_MEMORY)" \
		;

~/.android/avd/$(EMULATOR_NAME).avd ~/.android/avd/$(EMULATOR_NAME).ini:
	$(ANDROID_SDK_ROOT)/tools/bin/avdmanager -v create avd -f \
		-d "$(EMULATOR_DEVICE)" -k "$(EMULATOR_IMAGE)" -n "$(EMULATOR_NAME)" \
		;

clean:
	-docker-compose down -v --remove-orphans
	-killall qemu-system-$(EMILATOR_ARCH)
	-$(ANDROID_SDK_ROOT)/tools/bin/avdmanager -v delete avd -n "$(EMULATOR_NAME)"
