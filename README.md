
# Android SSL MITM

This projects helps you to easily setup man-in-the-middle proxy for virtual android device.

Includes NGINX as a reverse-proxy, CoreDNS as a resolver and Debian image.

**DEMO** (12:41): https://youtu.be/QS1VPGZRf2U

The NGINX part is actually using OpenResty, which includes Lua module. I am using this to **automatically issue certificates on demand**.

**I also create a certificate authority**. (1 self-signed root CA and 1 intermediate CA signed by that root) Then via android emulator's `-writable-system` option, pushing those as trusted root certificates at the system level. **Removing all other certificates in the process!** (In the virtual device itself)

### Prerequistes:

- Docker and `docker-compose`
- Android SDK (only command line tools are enough)
- Android Emulator
- Android System Image: 25, Google APIs
- Set your `$ANDROID_SDK_ROOT` to proper value;
  - on macOS: `export ANDROID_SDK_ROOT="${HOME}/Library/Android/sdk"`

### Usage:

- Clone the repository.
- Execute `make` inside the repo.

```bash
$ git clone https://github.com/pvtmert/android-ssl-mitm.git
$ make -C android-ssl-mitm ANDROID_SDK_ROOT="${HOME}/Library/Android/sdk"
```

> Optionally, comment out `./ssl:/home/ssl:rw` in [docker-compose.yml](docker-compose.yml) to see generated certs and possibly use them in Wireshark...

### How it works:

- [docker-compose](docker-compose.yml) Creates 3 services;
  - adb: Waits for root certificate creation. Then connects to the android emulator, removes & adds those certificates to the system.
  - dns: CoreDNS resolver for all possible domains. See [Corefile](Corefile).
  - http: OpenResty (NGINX) reverse proxy for connection handling
    - [cert.sh](cert.sh): Initializes root and intermediate CAs.
    - [issue.sh](issue.sh): Script to issue a certificate signed by CA.
    - [nginx.conf](nginx.conf): NGINX config with embedded Lua blocks.
- `make` first creates containers then android virtual device.
  - Virtual device named `androidemu` will be created.
  - AVD name can be overridden using `EMULATOR_NAME` variable.
  - Memory size in MB of AVD is 2048, `EMULATOR_MEMORY` can override that.
