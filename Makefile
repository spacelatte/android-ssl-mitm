#!//usr/bin/env -S make -f

PROJECT_NAME    := mitm
ANDROID_HOME    := $(ANDROID_HOME)
HOST_ADDRESS    := $(shell ipconfig getifaddr en0 )
EMILATOR_ARCH   := x86_64
EMULATOR_NAME   := androidemu
EMULATOR_IMAGE  := system-images;android-25;google_apis;$(EMILATOR_ARCH)
EMULATOR_DEVICE := Nexus 5

ifndef  ANDROID_HOME
$(error ANDROID_HOME is not set)
endif

ifeq ($(ANDROID_HOME),)
$(error ANDROID_HOME must not be empty)
endif

all: containers virtualdevice

logs:
	docker-compose -p $(PROJECT_NAME) logs --tail=1 -f

containers:
	ADDRESS=$(HOST_ADDRESS) \
		docker-compose -p $(PROJECT_NAME) up -d --build --remove-orphans \
		;

virtualdevice: ~/.android/avd/$(EMULATOR_NAME).avd ~/.android/avd/$(EMULATOR_NAME).ini
	$(ANDROID_HOME)/emulator/emulator -verbose -shell \
		-wipe-data -writable-system -skip-adb-auth -no-boot-anim \
		-avd "$(EMULATOR_NAME)" -dns-server "$(HOST_ADDRESS)" \
		;

~/.android/avd/$(EMULATOR_NAME).avd ~/.android/avd/$(EMULATOR_NAME).ini:
	$(ANDROID_HOME)/tools/bin/avdmanager create avd \
		-d "$(EMULATOR_DEVICE)" -k "$(EMULATOR_IMAGE)" -n "$(EMULATOR_NAME)" \
		;

clean:
	-docker-compose down -v --remove-orphans
	-killall qemu-system-$(EMILATOR_ARCH)
	-$(ANDROID_HOME)/tools/bin/avdmanager delete avd -n "$(EMULATOR_NAME)"
