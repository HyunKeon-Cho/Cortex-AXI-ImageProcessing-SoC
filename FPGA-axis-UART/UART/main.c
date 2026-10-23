#include "xparameters.h"
#include "xgpio.h"
#include "xstatus.h"
#include "xil_printf.h"
#include "sleep.h"

// button
#define BTN_DEVICE_ID  XPAR_AXI_GPIO_0_DEVICE_ID
#define LED_DEVICE_ID  XPAR_AXI_GPIO_1_DEVICE_ID
// FPGA
#define CLK_RATE 50000000U  // 50 MHz

// DUT AXI
#define UART_AXI_BASEADDR        XPAR_AXI_UART_0_BASEADDR // TODO : update
#define BAUD_RATE_OFFSET         0x00U
#define BAUD_RATE_INT_BITWITH    16
#define BAUD_RATE_FRAC_BITWITH   16
#define OVERSAMPLING_RATE        16U

#define GPIO_CHANNEL   1U
#define BAUD_COUNT     8U

static XGpio gpio_led;
static XGpio gpio_btn;

static const u32 baud_list[BAUD_COUNT] = { 9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600
};

static u32 baud_index = 1U;

static void update_baud_rate(u32 idx)
{
    u32 baud_rate = baud_list[idx];
    u32 denominator = baud_rate * OVERSAMPLING_RATE * 2U;
    u32 baud_rate_int = CLK_RATE / denominator - 1;

    // 현재 clock_generator의 소수 누산 방식에 맞춘 계산
    u32 frac_denominator = CLK_RATE - denominator;
    u32 baud_rate_frac = (u32)(
        ((u64)(CLK_RATE % denominator)
            * (1U << BAUD_RATE_FRAC_BITWITH)
            + frac_denominator / 2U)
        / frac_denominator
    );

    u32 axi_args =
        (baud_rate_int << BAUD_RATE_FRAC_BITWITH) |
        (baud_rate_frac & ((1U << BAUD_RATE_FRAC_BITWITH) - 1U));

    Xil_Out32(UART_AXI_BASEADDR, axi_args);

    xil_printf("[update] Baud rate: %u\r\n", baud_list[idx]);
    XGpio_DiscreteWrite(&gpio_led, GPIO_CHANNEL, idx);
}

int main(void)
{
    xil_printf("[boot] UART_control\r\n");

    if (XGpio_Initialize(&gpio_led, LED_DEVICE_ID) != XST_SUCCESS) {
        xil_printf("[fail] LED initialization\r\n");
        return XST_FAILURE;
    }

    if (XGpio_Initialize(&gpio_btn, BTN_DEVICE_ID) != XST_SUCCESS) {
        xil_printf("[fail] BTN initialization\r\n");
        return XST_FAILURE;
    }

    /* 방향 비트: 0 = 출력, 1 = 입력 */
    XGpio_SetDataDirection(&gpio_led, GPIO_CHANNEL, 0x00U);
    XGpio_SetDataDirection(&gpio_btn, GPIO_CHANNEL, 0x03U);

    xil_printf("[done] GPIO initialized\r\n");

    update_baud_rate(baud_index);
    while (1) {
        sleep(1);
        // detect button
        u32 buttons = XGpio_DiscreteRead(&gpio_btn, GPIO_CHANNEL);
        if (buttons == 0) { continue; }

        // update
        baud_index = (baud_index + ((buttons == 1) ? 1 : -1)) % BAUD_COUNT;
        update_baud_rate(baud_index);
    }
}
