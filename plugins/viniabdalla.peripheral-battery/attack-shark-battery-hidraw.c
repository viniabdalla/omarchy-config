#include <dirent.h>
#include <fcntl.h>
#include <limits.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

/* Reads the Attack Shark X11 battery level from the dongle's hidraw node for
 * interface 2. Unlike the libusb helper, this never detaches hid-generic, so
 * the kernel does not re-create input devices on every poll. */

#define VID "1d57"
#define PID_WIRELESS "fa60"
#define IFACE_SUFFIX ":1.2"

static int read_attr(const char *path, char *out, size_t len) {
  FILE *f = fopen(path, "r");
  if (!f) return -1;
  if (!fgets(out, (int)len, f)) {
    fclose(f);
    return -1;
  }
  fclose(f);
  out[strcspn(out, "\n")] = 0;
  return 0;
}

/* Walk up from the hidraw device to the USB interface (…/1-11.2:1.2) and the
 * USB device (…/1-11.2), checking the interface number and VID:PID. */
static int is_target(const char *name) {
  char link[PATH_MAX], real[PATH_MAX], iface[PATH_MAX], attr[PATH_MAX], val[16];
  snprintf(link, sizeof(link), "/sys/class/hidraw/%s/device", name);
  if (!realpath(link, real)) return 0;

  /* real = …/1-11.2/1-11.2:1.2/0003:1D57:FA60.000D */
  char *slash = strrchr(real, '/');
  if (!slash) return 0;
  *slash = 0;
  strncpy(iface, real, sizeof(iface) - 1);
  iface[sizeof(iface) - 1] = 0;
  size_t n = strlen(iface);
  if (n < strlen(IFACE_SUFFIX) || strcmp(iface + n - strlen(IFACE_SUFFIX), IFACE_SUFFIX) != 0) return 0;

  slash = strrchr(real, '/');
  if (!slash) return 0;
  *slash = 0;
  snprintf(attr, sizeof(attr), "%s/idVendor", real);
  if (read_attr(attr, val, sizeof(val)) != 0 || strcmp(val, VID) != 0) return 0;
  snprintf(attr, sizeof(attr), "%s/idProduct", real);
  if (read_attr(attr, val, sizeof(val)) != 0 || strcmp(val, PID_WIRELESS) != 0) return 0;
  return 1;
}

static long now_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return ts.tv_sec * 1000L + ts.tv_nsec / 1000000L;
}

int main(int argc, char **argv) {
  int debug = argc > 1 && strcmp(argv[1], "--debug") == 0;
  char devpath[PATH_MAX] = "";

  DIR *dir = opendir("/sys/class/hidraw");
  if (!dir) return 1;
  struct dirent *ent;
  while ((ent = readdir(dir))) {
    if (strncmp(ent->d_name, "hidraw", 6) != 0) continue;
    if (is_target(ent->d_name)) {
      snprintf(devpath, sizeof(devpath), "/dev/%s", ent->d_name);
      break;
    }
  }
  closedir(dir);

  if (!devpath[0]) {
    if (debug) fprintf(stderr, "hidraw for %s:%s interface 2 not found\n", VID, PID_WIRELESS);
    return 2;
  }

  int fd = open(devpath, O_RDONLY | O_NONBLOCK);
  if (fd < 0) {
    if (debug) perror(devpath);
    return 3;
  }
  if (debug) fprintf(stderr, "reading %s\n", devpath);

  unsigned char buf[64];
  long deadline = now_ms() + 10000;
  while (now_ms() < deadline) {
    struct pollfd pfd = {.fd = fd, .events = POLLIN};
    int rc = poll(&pfd, 1, (int)(deadline - now_ms()));
    if (rc <= 0) break;
    ssize_t got = read(fd, buf, sizeof(buf));
    if (got < 5) continue;
    if (debug) {
      fprintf(stderr, "packet:");
      for (ssize_t j = 0; j < got && j < 16; j++) fprintf(stderr, " %02x", buf[j]);
      fprintf(stderr, "\n");
    }
    if (buf[0] == 0x03 && buf[1] == 0x55 && buf[2] == 0x40 && buf[3] == 0x01 && buf[4] <= 100) {
      printf("%d\n", (int)buf[4]);
      close(fd);
      return 0;
    }
  }

  if (debug) fprintf(stderr, "no battery packet received\n");
  close(fd);
  return 4;
}
