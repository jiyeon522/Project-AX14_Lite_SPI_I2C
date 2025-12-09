#include <stdio.h>
#include <stdint.h>
#include "platform.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "sleep.h"

typedef struct{
    volatile uint32_t MODER;
    volatile uint32_t ODR;
    volatile uint32_t IDR;
} GPIOB_TypeDef;

typedef struct{
    volatile uint32_t CR;
    volatile uint32_t WDATA;
    volatile uint32_t SR;
    volatile uint32_t DATA1;
    volatile uint32_t DATA2;
    volatile uint32_t DATA3;
} I2C_Typedef;

typedef struct{
    volatile uint32_t FDR;
} FND_Typedef;

#define FND_BASEADDR 0x44A00000u
#define GPIOB_BASEADDR 0x44A10000u
#define I2C_BASEADDR 0x44A20000u

#define GPIOB ((GPIOB_TypeDef *) GPIOB_BASEADDR)
#define I2C ((I2C_Typedef *) I2C_BASEADDR)
#define FND ((FND_Typedef *) FND_BASEADDR)


const uint32_t PASSWORD[3] = {9, 1, 4};

uint32_t user_input[3] = {0, 0, 0};
uint32_t input_count = 0;  

uint32_t result[3] = {0, 0, 0};
uint32_t checked = 0;  

// I2C
void start_I2C(I2C_Typedef *I2Cx);
void stop_I2C(I2C_Typedef *I2Cx);
void data_I2C(I2C_Typedef *I2Cx);
void delay(int n);
uint32_t is_ready(I2C_Typedef *I2Cx);
uint32_t is_txDone(I2C_Typedef *I2Cx);

// GPIO 
void GPI_INIT(GPIOB_TypeDef *GPIOx);
uint32_t GPI_read(GPIOB_TypeDef *GPIOx);

// FND 
void write_fndFont(FND_Typedef *FNDx, uint32_t fndFont);

void WRITE_I2C_GAME(I2C_Typedef *I2Cx, uint32_t data0, uint32_t data1, uint32_t data2);
void READ_I2C_GAME(I2C_Typedef *I2Cx, uint32_t *DATA1, uint32_t *DATA2, uint32_t *DATA3);
uint32_t get_switch_value(void);
void check_password(void);
void reset_game(void);
void wait_button_press(uint8_t button_num);
void wait_button_release(uint8_t button_num);
void update_fnd_by_switch(void);

int main()
{
    init_platform();
    GPI_INIT(GPIOB);

    xil_printf("\r\n=== I2C Password Game Start (3 Digits) ===\r\n");
    xil_printf("Password is set to: %d%d%d\r\n", PASSWORD[0], PASSWORD[1], PASSWORD[2]);
    xil_printf("\r\n[Instructions]\r\n");
    xil_printf("- Use SW4-7 to input number (0-9 in binary)\r\n");
    xil_printf("- Press BTN0 to enter each digit\r\n");
    xil_printf("- Press BTN1 to check answer\r\n");
    xil_printf("- Press BTN2 to reset game\r\n");
    xil_printf("- After checking, use SW4-6 to view each digit result on FND\r\n");
    xil_printf("  SW4: Digit 1, SW5: Digit 2, SW6: Digit 3\r\n");
    xil_printf("==========================================\r\n\r\n");

    reset_game();

    while(1) {
        uint32_t gpio_state = GPI_read(GPIOB);

        if (checked) {
            update_fnd_by_switch();
        }


        if ((gpio_state & (1 << 0)) != 0) {
            if (input_count < 3) {
                uint32_t switch_val = get_switch_value();

                if (switch_val <= 9) {
                    user_input[input_count] = switch_val;
                    input_count++;

                    xil_printf("Input digit %d: %d\r\n", input_count, switch_val);
                    xil_printf("Current input: %d%d%d\r\n",
                               user_input[0], user_input[1], user_input[2]);

                    WRITE_I2C_GAME(I2C, user_input[0], user_input[1], user_input[2]);
                    wait_button_release(0);

                    if (input_count == 3) {
                        xil_printf("\r\nAll 3 digits entered! Press BTN1 to check.\r\n");
                    }
                } else {
                    xil_printf("Error: Switch value %d is out of range (0-9)!\r\n", switch_val);
                    wait_button_release(0);
                }
            } else {
                xil_printf("Already entered 3 digits. Press BTN1 to check or BTN2 to reset.\r\n");
                wait_button_release(0);
            }
        }

        if ((gpio_state & (1 << 1)) != 0) {
            if (input_count == 3) {
                check_password();
                wait_button_release(1);
            } else {
                xil_printf("Please enter all 3 digits first! (Current: %d/3)\r\n", input_count);
                wait_button_release(1);
            }
        }

        if ((gpio_state & (1 << 2)) != 0) {
            xil_printf("\r\n=== Game Reset ===\r\n");
            reset_game();
            wait_button_release(2);
        }

        usleep(50000);  
    }

    cleanup_platform();
    return 0;
}

void update_fnd_by_switch(void) {
    uint32_t gpio = GPI_read(GPIOB);

    if (gpio & (1 << 4)) {
        write_fndFont(FND, result[0]);
    } else if (gpio & (1 << 5)) {
        write_fndFont(FND, result[1]);
    } else if (gpio & (1 << 6)) {
        write_fndFont(FND, result[2]);
    } else {
        write_fndFont(FND, 0);
    }
}

uint32_t get_switch_value(void) {
    uint32_t gpio = GPI_read(GPIOB);
    uint32_t switch_val = (gpio >> 4) & 0x0F; 
    return switch_val;
}

void check_password(void) {
    uint32_t slave_data[3];

    xil_printf("\r\n=== Checking Password ===\r\n");

    READ_I2C_GAME(I2C, &slave_data[0], &slave_data[1], &slave_data[2]);

    xil_printf("Your input: %d%d%d\r\n", slave_data[0], slave_data[1], slave_data[2]);
    xil_printf("Password:   %d%d%d\r\n", PASSWORD[0], PASSWORD[1], PASSWORD[2]);

    uint32_t correct_count = 0;

    for (int i = 0; i < 3; i++) {
        if (slave_data[i] == PASSWORD[i]) {
            result[i] = 1;  
            correct_count++;
            xil_printf("Digit %d: CORRECT\r\n", i + 1);
        } else {
            result[i] = 0; 
            xil_printf("Digit %d: WRONG\r\n", i + 1);
        }
    }

    checked = 1;  

    xil_printf("\r\nCorrect: %d/3\r\n", correct_count);
    xil_printf("\r\n[Result Check Mode]\r\n");
    xil_printf("Use SW4-6 to check each digit result:\r\n");
    xil_printf("  SW4: Digit 1 result (%d)\r\n", result[0]);
    xil_printf("  SW5: Digit 2 result (%d)\r\n", result[1]);
    xil_printf("  SW6: Digit 3 result (%d)\r\n", result[2]);
    xil_printf("FND will display 0 (wrong) or 1 (correct)\r\n");

    if (correct_count == 3) {
        xil_printf("\r\n*** CONGRATULATIONS! PASSWORD CORRECT! ***\r\n");
    } else {
        xil_printf("\r\nTry again! Press BTN2 to reset.\r\n");
    }
    xil_printf("========================\r\n\r\n");
}

void reset_game(void) {
    for (int i = 0; i < 3; i++) {
        user_input[i] = 0;
        result[i] = 0;
    }
    input_count = 0;
    checked = 0;

    WRITE_I2C_GAME(I2C, 0, 0, 0);

    write_fndFont(FND, 0);

    xil_printf("Game reset complete. Enter your guess!\r\n\r\n");
}

void wait_button_press(uint8_t button_num) {
    while ((GPI_read(GPIOB) & (1 << button_num)) == 0) {
        usleep(10000);
    }
}

void wait_button_release(uint8_t button_num) {
    while ((GPI_read(GPIOB) & (1 << button_num)) != 0) {
        usleep(10000);
    }
}

void WRITE_I2C_GAME(I2C_Typedef *I2Cx, uint32_t data0, uint32_t data1, uint32_t data2) {
    I2C->CR = 0x00;

    while(is_ready(I2C) == 0);

    delay(5);
    start_I2C(I2C);
    I2C->CR = 0x00;
    while(is_ready(I2C) == 0);

    delay(5);
    I2C->WDATA = 0xAA;
    data_I2C(I2C);
    I2C->CR = 0x00;
    while(is_ready(I2C) == 0);

    delay(5);
    I2C->WDATA = data0;
    data_I2C(I2C);
    I2C->CR = 0x00;
    while(is_ready(I2C) == 0);

    delay(5);
    I2C->WDATA = data1;
    data_I2C(I2C);
    I2C->CR = 0x00;
    while(is_ready(I2C) == 0);

    delay(5);
    I2C->WDATA = data2;
    data_I2C(I2C);
    I2C->CR = 0x00;
    while(is_ready(I2C) == 0);

    delay(5);
    stop_I2C(I2C);
    delay(5);
    I2C->CR = 0x00;
    while(is_ready(I2C) == 0);
}

void READ_I2C_GAME(I2C_Typedef *I2Cx, uint32_t *DATA1, uint32_t *DATA2, uint32_t *DATA3) {
    delay(5);
    start_I2C(I2C);
    delay(5);
    I2C->CR = 0x00;
    while(is_ready(I2C) == 0);

    delay(5);
    I2C->WDATA = 0xAB;
    data_I2C(I2C);
    I2C->CR = 0x00;

    while(is_ready(I2C) == 0);
    I2C->CR = 0x07; 
    I2C->CR = 0x00;
    while(is_ready(I2C) == 0);

    stop_I2C(I2C);

    *DATA1 = I2C->DATA1;
    *DATA2 = I2C->DATA2;
    *DATA3 = I2C->DATA3;
}

void write_fndFont(FND_Typedef *FNDx, uint32_t fndFont) {
    FNDx->FDR = fndFont;
}

void start_I2C(I2C_Typedef *I2Cx) {
    I2Cx->CR = 0x05; 
}

void stop_I2C(I2C_Typedef *I2Cx) {
    I2Cx->CR = 0x03;  
}

void data_I2C(I2C_Typedef *I2Cx) {
    I2Cx->CR = 0x01;
}

uint32_t is_ready(I2C_Typedef *I2Cx) {
    return (I2Cx->SR) & (1 << 0);
}

uint32_t is_txDone(I2C_Typedef *I2Cx) {
    return (I2Cx->SR) & (1 << 1);
}

void GPI_INIT(GPIOB_TypeDef *GPIOx) {
    GPIOx->MODER = 0x00;
}

uint32_t GPI_read(GPIOB_TypeDef *GPIOx) {
    return GPIOx->IDR;
}

void delay(int n) {
    volatile uint32_t temp = 0;
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < 1000; j++) {
            temp++;
        }
    }
}
