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

#include <arch.h>
#include <arch/rc2014.h>

#include "../common/yash.h"
#include "../common/fatfs.h"

#pragma output CRT_ORG_VECTOR_TABLE = 0
#pragma output REGISTER_SP = 0xDAE0
#pragma output CRT_ITERM_TERMINAL_FLAGS = 0
#pragma output TTY_ITERM_TERMINAL_FLAGS = 0
#pragma printf = "%c %s %d %u %lu %X"

extern uint8_t bios_iobyte;

extern uint8_t uarta_pollc(void) __preserves_regs(b,c,d,e,h,iyl,iyh);
extern uint8_t uarta_getc(void) __preserves_regs(b,c,d,e,h,iyl,iyh);
extern uint8_t uartb_pollc(void) __preserves_regs(b,c,d,e,h,iyl,iyh);
extern uint8_t uartb_getc(void) __preserves_regs(b,c,d,e,h,iyl,iyh);

extern void cpm_boot(void) __preserves_regs(a,b,c,d,e,h,iyl,iyh);

static void uarta_flush_rx_di(void)
{
    while (uarta_pollc())
        (void)uarta_getc();
}

static void uartb_flush_rx_di(void)
{
    while (uartb_pollc())
        (void)uartb_getc();
}

void select_console(void)
{
    for (;;) {
        if (uarta_pollc() != 0) {
            if (uarta_getc() == ':') {
                input = stdin;
                output = stdout;
                error = stderr;
                bios_iobyte = 1;
                fprintf(output, "\b-)");
                return;
            }
            uarta_flush_rx_di();
        }
        if (uartb_pollc() != 0) {
            if (uartb_getc() == ':') {
                input = ttyin;
                output = ttyout;
                error = ttyerr;
                bios_iobyte = 0;
                fprintf(output, "\b-)");
                return;
            }
            uartb_flush_rx_di();
        }
    }
}

int main(int argc, char ** argv)
{
    (void)argc;
    (void *)argv;

    buffer = (char *)malloc(BUFFER_SIZE * sizeof(char));

    fprintf(stdout, "\n\nRC2014 - CP/M-IDE - CF - UART\nfeilipu 2026\n\n> :?");
    fprintf(ttyout, "\n\nRC2014 - CP/M-IDE - CF - UART\nfeilipu 2026\n\n> :?");

    if (buffer) {
        put_rc(fat_mount());
        ya_loop();
    }

    free(buffer);
    return 0;
}
