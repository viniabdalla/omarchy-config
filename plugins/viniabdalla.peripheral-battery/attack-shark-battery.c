#include <libusb.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>

#define VID 0x1d57
#define PID_WIRELESS 0xfa60
#define IFACE 2
#define ENDPOINT 0x83

static void debugf(int debug, const char *message, int rc) {
  if (debug) fprintf(stderr, "%s: %s (%d)\n", message, libusb_error_name(rc), rc);
}

int main(int argc, char **argv) {
  int debug = argc > 1 && strcmp(argv[1], "--debug") == 0;
  libusb_context *ctx = NULL;
  libusb_device_handle *handle = NULL;
  unsigned char buf[64];
  int rc;

  rc = libusb_init(&ctx);
  if (rc != 0) {
    debugf(debug, "libusb_init failed", rc);
    return 1;
  }

  handle = libusb_open_device_with_vid_pid(ctx, VID, PID_WIRELESS);
  if (!handle) {
    if (debug) fprintf(stderr, "Attack Shark X11 wireless dongle not found: %04x:%04x\n", VID, PID_WIRELESS);
    libusb_exit(ctx);
    return 2;
  }

  libusb_set_auto_detach_kernel_driver(handle, 1);

  rc = libusb_claim_interface(handle, IFACE);
  if (rc != 0) {
    debugf(debug, "claim interface failed", rc);
    libusb_close(handle);
    libusb_exit(ctx);
    return 3;
  }

  for (int i = 0; i < 40; i++) {
    int transferred = 0;
    rc = libusb_interrupt_transfer(handle, ENDPOINT, buf, sizeof(buf), &transferred, 250);
    if (rc == 0 && transferred >= 5) {
      if (debug) {
        fprintf(stderr, "packet:");
        for (int j = 0; j < transferred && j < 16; j++) fprintf(stderr, " %02x", buf[j]);
        fprintf(stderr, "\n");
      }
      if (buf[0] == 0x03 && buf[1] == 0x55 && buf[2] == 0x40 && buf[3] == 0x01) {
        int battery = (int)buf[4];
        if (battery >= 0 && battery <= 100) {
          printf("%d\n", battery);
          libusb_release_interface(handle, IFACE);
          libusb_close(handle);
          libusb_exit(ctx);
          return 0;
        }
      }
    } else if (rc != LIBUSB_ERROR_TIMEOUT) {
      debugf(debug, "interrupt read failed", rc);
      break;
    }
  }

  if (debug) fprintf(stderr, "no battery packet received\n");
  libusb_release_interface(handle, IFACE);
  libusb_close(handle);
  libusb_exit(ctx);
  return 4;
}
