#include "usbh_core.h"
#include "usbh_hid.h"
#include "usb_osal.h"
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#include "instrument_keys.h"
#include "touch_input.h"
#include "touch_usb.h"
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

extern instrument_keys_t instrument;
extern SemaphoreHandle_t instrument_mutex;
extern void usb_diag_reached(uint8_t stage);

/* Waveshare 7inch LCD Display-B Rev3.5, USB product MPI7002. */
#define TOUCH_VID 0x0484
#define TOUCH_PID 0x5750
enum touch_state { TOUCH_STOPPED, TOUCH_RUNNING, TOUCH_STOPPING };
static struct usbh_hid *touch_device;
static volatile enum touch_state state=TOUCH_STOPPED;
static volatile int received;
static volatile bool busy;
static SemaphoreHandle_t done_sem,stop_sem;
static TaskHandle_t worker_handle;
static USB_NOCACHE_RAM_SECTION USB_MEM_ALIGNX uint8_t report[128];

static void received_report(void *arg,int nbytes){
    (void)arg;received=nbytes;busy=false;
    usb_osal_sem_give((usb_osal_sem_t)done_sem);
}

static void touch_worker(void *unused){
    (void)unused;
    struct usbh_hid *hid=touch_device;
    unsigned transient_errors=0;
    if(!hid || !hid->intin)goto leave;
    uint16_t max_packet=USB_GET_MAXPACKETSIZE(hid->intin->wMaxPacketSize);
    if(max_packet<TOUCH_REPORT_BYTES || max_packet>sizeof(report))goto leave;
    vTaskDelay(pdMS_TO_TICKS(250));
    if(state!=TOUCH_RUNNING)goto leave;
    xSemaphoreTake(instrument_mutex,portMAX_DELAY);
    instrument_touch_connect(&instrument,(uint32_t)(xTaskGetTickCount()*portTICK_PERIOD_MS));
    xSemaphoreGive(instrument_mutex);
    usb_diag_reached(8);
    bool touch_report_seen=false;
    while(state==TOUCH_RUNNING){
        if(!busy){
            if(received<0){
                if(++transient_errors>=5)break;
                received=0;
                vTaskDelay(pdMS_TO_TICKS(5));
                if(state!=TOUCH_RUNNING)break;
            }
            if(received>0){
                touch_frame_t frame;
                int decoded=touch_decode_mpi7002(report,(size_t)received,&frame)==0;
                if(decoded){
                    if(!touch_report_seen){
                        for(unsigned i=0;i<TOUCH_MAX_CONTACTS;i++)if(frame.points[i].active){
                            touch_report_seen=true;
                            usb_diag_reached(9);
                            break;
                        }
                    }
                    xSemaphoreTake(instrument_mutex,portMAX_DELAY);
                    instrument_touch_report(&instrument,&frame,
                                            (uint32_t)(xTaskGetTickCount()*portTICK_PERIOD_MS));
                    xSemaphoreGive(instrument_mutex);
                }
                transient_errors=0;
            }
            received=0;busy=true;
            usbh_int_urb_fill(&hid->intin_urb,hid->hport,hid->intin,
                              report,max_packet,0,received_report,NULL);
            if(usbh_submit_urb(&hid->intin_urb)<0){busy=false;break;}
        }
        xSemaphoreTake(done_sem,pdMS_TO_TICKS(20));
    }
leave:
    if(hid)usbh_kill_urb(&hid->intin_urb);
    xSemaphoreTake(instrument_mutex,portMAX_DELAY);
    instrument_touch_disconnect(&instrument);
    xSemaphoreGive(instrument_mutex);
    state=TOUCH_STOPPED;touch_device=NULL;busy=false;
    xSemaphoreGive(stop_sem);
    vTaskDelete(NULL);
}

void touch_usb_run(struct usbh_hid *hid){
    if(state!=TOUCH_STOPPED || !hid || !hid->hport || !hid->intin)return;
    if(hid->hport->device_desc.idVendor!=TOUCH_VID ||
       hid->hport->device_desc.idProduct!=TOUCH_PID)return;
    usb_diag_reached(7);
    /* The report descriptor length varies across interfaces and firmware.
       Select by endpoint packet size; decoding still validates the report ID. */
    uint16_t max_packet=USB_GET_MAXPACKETSIZE(hid->intin->wMaxPacketSize);
    if(max_packet<TOUCH_REPORT_BYTES || max_packet>sizeof(report))return;
    if(!done_sem)done_sem=xSemaphoreCreateBinary();
    if(!stop_sem)stop_sem=xSemaphoreCreateBinary();
    if(!done_sem || !stop_sem)return;
    xSemaphoreTake(done_sem,0);xSemaphoreTake(stop_sem,0);
    touch_device=hid;received=0;busy=false;state=TOUCH_RUNNING;
    if(xTaskCreate(touch_worker,"usb_touch",1536,NULL,5,&worker_handle)!=pdPASS){
        touch_device=NULL;state=TOUCH_STOPPED;
    }
}

void touch_usb_stop(struct usbh_hid *hid){
    if(touch_device!=hid || state==TOUCH_STOPPED)return;
    state=TOUCH_STOPPING;
    xSemaphoreGive(done_sem);
    xSemaphoreTake(stop_sem,portMAX_DELAY);
}
