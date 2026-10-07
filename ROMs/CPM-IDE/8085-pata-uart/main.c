/***************************************************************************//**

  @file         main.c
  @author       Phillip Stevens, inspired by Stephen Brennan
  @brief        YASH (Yet Another SHell)

  This RC2014 programme reached working state March 2025.

*******************************************************************************/

#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/compiler.h>

#include <config_rc2014-8085.h>
#include <arch/rc2014.h>

#include "../common/yash.h"
#include "../common/fatfs.h"

#pragma output REGISTER_SP = 0xDAE0
#pragma printf = "%c %s %d %u %lu %X"

extern uint8_t bios_iobyte;

extern uint8_t uarta_control;
extern uint8_t uartb_control;
extern uint8_t uarta_reset(void);
extern uint8_t uarta_pollc(void);
extern uint8_t uarta_getc(void);
extern uint8_t uartb_reset(void);
extern uint8_t uartb_pollc(void);
extern uint8_t uartb_getc(void);

extern void cpm_boot(void);

void select_console(void)
{
    for (;;) {
        if ((uarta_control != 0) && (uarta_pollc() != 0)) {
            if (uarta_getc() == ':') {
                input = stdin;
                output = stdout;
                error = stderr;
                bios_iobyte = 0x81;
                fprintf(output, "\b-)");
                return;
            }
            uarta_reset();
        }
        if ((uartb_control != 0) && (uartb_pollc() != 0)) {
            if (uartb_getc() == ':') {
                input = ttyin;
                output = ttyout;
                error = ttyerr;
                bios_iobyte = 0x80;
                fprintf(output, "\b-)");
                return;
            }
            uartb_reset();
        }
    }
}

int main(int argc, char ** argv)
{
    (void)argc;
    (void *)argv;

    buffer = (char *)malloc(BUFFER_SIZE * sizeof(char));

    fprintf(stdout, "\n\nRC2014 - CP/M-IDE - 8085 - PATA - UART\nfeilipu 2026\n\n> :?");

    if (buffer) {
        put_rc(fat_mount());
        ya_loop();
    }

    free(buffer);
    return 0;
}
