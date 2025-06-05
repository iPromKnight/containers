# Custom Jellyfin with Jemalloc

This is a custom Jellyfin image that uses Jemalloc as the memory allocator. It is based on the official Jellyfin image but includes Jemalloc for improved memory management.

Also included is the DeoVRDeeplink deepling plugin by `Toastyice` from (here)[https://github.com/Toastyice/DeoVRDeeplink].

---

## What is Jemalloc?
Jemalloc is a general-purpose memory allocator that emphasizes fragmentation avoidance and scalable concurrency support.
It is designed to be efficient in multi-threaded applications, making it suitable for high-performance environments like Jellyfin.

---

## What is DeoVRDeeplink?

DeoVR Deeplink Proxy Plugin for Jellyfin

> [!CAUTION]
> All movies are exposed UNAUTHENTICATED from DeoVRDeeplink/json/videoID/response.json

A plugin for Jellyfin that enables secure, expiring, signed video stream URLs for use with [DeoVR](https://deovr.com/) and other clients needing quick access to individual media files without exposing your Jellyfin credentials.

## Features
- **UI Changes:** adds a Play in DeoVR button
- **Secure signed links:** Temporary, HMAC-signed links for proxying video streams.
- **Expiry enforcement:** Links are only valid for a short time window.
- **Chunked proxy streaming:** Efficient forwarding without direct Jellyfin API exposure.
- **DeoVR-compatible JSON responses:** Works seamlessly with [DeoVR](https://deovr.com/).
- **Embedded client JS and icon resources.**

---

## Usage
To enable the VR plugin to be copied into the plugins directory and activated on boot, set the following env var
```yaml
ENABLE_DEOVR_PLUGIN: true
```