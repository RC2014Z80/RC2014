#ifndef _RC2014_H_
#define _RC2014_H_

extern char __LIB__ __FASTCALL__ rc2014_getc();
extern char __LIB__ __FASTCALL__ rc2014_pollc();
extern void __LIB__ __FASTCALL__ rc2014_putc(char c);
extern unsigned char __LIB__ __FASTCALL__ rc2014_inp(unsigned char port);
extern void __LIB__ __FASTCALL__ rc2014_outp(unsigned int port_value);

#endif
