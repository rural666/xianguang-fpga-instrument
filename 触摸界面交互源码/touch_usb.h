#ifndef XIANGUANG_TOUCH_USB_H
#define XIANGUANG_TOUCH_USB_H
struct usbh_hid;
void touch_usb_run(struct usbh_hid *hid);
void touch_usb_stop(struct usbh_hid *hid);
#endif
