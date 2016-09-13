#ifndef _PIGFX_H_
#define _PIGFX_H_

extern void __LIB__ __FASTCALL__ pigfx_hide_cursor(void);
extern void __LIB__ __FASTCALL__ pigfx_show_cursor(void);
extern void __LIB__ __FASTCALL__ pigfx_cls(void);
extern void __LIB__ __FASTCALL__ pigfx_fgcol(int cl);
extern void __LIB__ __FASTCALL__ pigfx_bgcol(int cl);
extern void __LIB__ __FASTCALL__ pigfx_print(char* str);
extern void __LIB__ __FASTCALL__ pigfx_printnum(int cl);
extern void __LIB__ __FASTCALL__ pigfx_printhex(int cl);
extern void __LIB__ pigfx_movecursor(int row, int col);

#endif
