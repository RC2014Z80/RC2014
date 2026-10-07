/***************************************************************************//**

  @file         main.c
  @author       Phillip Stevens, inspired by Stephen Brennan
  @brief        YASH (Yet Another SHell)

  This RC2014 programme reached working state on St Patrick's Day 2018.

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

#pragma output REGISTER_SP = 0xDBE0
#pragma output CRT_ITERM_TERMINAL_FLAGS = 0
#pragma printf = "%c %s %d %u %lu %X"

extern uint8_t bios_iobyte;

extern uint8_t acia_pollc(void) __preserves_regs(b,c,d,e,h,iyl,iyh);
extern uint8_t acia_getc(void) __preserves_regs(b,c,d,e,h,iyl,iyh);
extern uint8_t acia_reset(void) __preserves_regs(b,c,d,e,h,iyl,iyh);

extern void cpm_boot(void) __preserves_regs(a,b,c,d,e,h,iyl,iyh);

void select_console(void)
{
    input = stdin;
    output = stdout;
    error = stderr;
    bios_iobyte = 1;
    fprintf(output, "> :-)");
}

int main(int argc, char ** argv)
{
    (void)argc;
    (void *)argv;

    buffer = (char *)malloc(BUFFER_SIZE * sizeof(char));

    fprintf(stdout, "\n\nRC2014 - CP/M-IDE - CF - ACIA\nfeilipu 2026\n\n");

    if (buffer) {
        put_rc(fat_mount());
        ya_loop();
    }

    free(buffer);
    return 0;
}
