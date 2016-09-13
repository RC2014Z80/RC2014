;@---------------------------------------------------------------------
;@  PiGFX Z80 Interface Library
;@      Filippo Bergamasco 2016
;@
;@  Tested with z88dk. To compile:
;@      $ z80asm -l -xpigfx.lib pigfx.asm
;@
;@---------------------------------------------------------------------

MODULE pigfx

SECTION code_user

;@---------------------------------------------------------------------
;@ pigfx_print
;@
;@  output the null-terminated string pointed by HL
;@  to the system UART
;@
;@      HL: memory address of the null-terminated string
;@
;@---------------------------------------------------------------------
public pigfx_print
pigfx_print:
            ld a, (hl)
            or a
            ret z
            rst $08
            inc hl
            jp pigfx_print


;@---------------------------------------------------------------------
;@ pigfx_printnum
;@
;@  print the decimal number in HL to the system UART
;@  as an ascii string
;@
;@      HL: number to print
;@
;@---------------------------------------------------------------------
public pigfx_printnum
pigfx_printnum:
            ld  a, 0
            or h
            or l             ; if the number is 0
            jr  z, PNa       ; print it and exit
            ld  a, 0         ; reset a
            ld  bc, -1000    ; else check powers of 10
            call    PNDOSUB
            ld  bc, -100
            call    PNDOSUB
            ld  c, -10
            call    PNDOSUB
            ld  c, b
            jp      PNDOSUB0
PNCOUNT:    inc a
PNDOSUB:    add hl, bc
            jr  c, PNCOUNT
            sbc hl, bc
            or a
            ret z
            jp PNa
PNDOSUB0:   add hl, bc
            jr  c, PNCOUNT
            sbc hl, bc
PNa:        add a, '0'
            rst $08
            ld a, 0
            ret


;@---------------------------------------------------------------------
;@ pigfx_printhex
;@
;@  print the hex number in HL to the system UART
;@  as an ascii string
;@
;@  See: http://map.grauw.nl/sources/external/z80bits.html#5.1
;@
;@      HL: number to print
;@
;@---------------------------------------------------------------------
public pigfx_printhex
pigfx_printhex:
     ld  a,h
    call    Num1
    ld  a,h
    call    Num2
    ld  a,l
    call    Num1
    ld  a,l
    jr  Num2

Num1:    rra
    rra
    rra
    rra
Num2:    or  $F0
    daa
    add a,$A0
    adc a,$40
    rst $08
    ret


;@---------------------------------------------------------------------
;@ pigfx_showcursor
;@
;@  Set the cursor visible
;@
;@---------------------------------------------------------------------
public pigfx_show_cursor
pigfx_show_cursor:
            call ANSI_START
            ld hl, cursor_vis_str
            call pigfx_print
            ret


;@---------------------------------------------------------------------
;@ pigfx_hidecursor
;@
;@  Set the cursor invisible
;@
;@---------------------------------------------------------------------
public pigfx_hide_cursor
pigfx_hide_cursor:
            call ANSI_START
            ld hl, cursor_inv_str
            call pigfx_print
            ret


;@---------------------------------------------------------------------
;@ pigfx_cls
;@
;@  Clear the screen and move cursor to 0-0
;@
;@---------------------------------------------------------------------
public pigfx_cls
pigfx_cls:
            call ANSI_START
            ld hl, cursor_cls_str
            call pigfx_print
            ret


;@---------------------------------------------------------------------
;@ pigfx_fgcol
;@
;@  Set the foreground color
;@
;@      HL: color index
;@  (see https://en.wikipedia.org/wiki/File:Xterm_256color_chart.svg)
;@
;@---------------------------------------------------------------------
public pigfx_fgcol
pigfx_fgcol:
            push hl             ; push color value to stack
            call ANSI_START     ; start sequence
            ld hl, fgcol_str    ; load fgcolor command identifier
            call pigfx_print    ; and print it
            pop hl              ; pop color value
            call pigfx_printnum ; print color value as ascii string
            ld a, 'm'           ; terminate code with 'm'
            rst $08             ;
            ret                 ; end


;@---------------------------------------------------------------------
;@ pigfx_bgcol
;@
;@  Set the background color
;@
;@      HL: color index
;@  (see https://en.wikipedia.org/wiki/File:Xterm_256color_chart.svg)
;@
;@---------------------------------------------------------------------
public pigfx_bgcol
pigfx_bgcol:
            push hl             ; push color value to stack
            call ANSI_START     ; start sequence
            ld hl, bgcol_str    ; load fgcolor command identifier
            call pigfx_print    ; and print it
            pop hl              ; pop color value
            call pigfx_printnum ; print color value as ascii string
            ld a, 'm'           ; terminate code with 'm'
            rst $08             ;
            ret                 ; end



;@---------------------------------------------------------------------
;@ pigfx_movecursor
;@
;@  Move the cursor to -row- -col- (read from stack)
;@
;@  stack:  <row > <col> <return addr>
;@
;@---------------------------------------------------------------------
public pigfx_movecursor
pigfx_movecursor:
            call ANSI_START

            pop  de             ; return addr
            pop  bc             ; col
            pop  hl             ; row

            push de             ; push ret addr
            push bc             ; push col to swap row/col

            call pigfx_printnum ; print row
            ld a, ';'
            rst $08
            pop hl              ; pop col
            call pigfx_printnum ; print col
            ld a, 'H'
            rst $08

            pop hl              ; pop return address
            push hl             ;
            push hl
            push hl

            ret                 ; end



;@ Utility functions
;@---------------------------------------------------------------------
ANSI_START: ld a, 0x1B
            rst $08
            ld a, '['
            rst $08
            ret


;@ -------------------------------------------------------------------

SECTION rodata_user

cursor_inv_str: DEFM "?25l",0
cursor_vis_str: DEFM "?25h",0
cursor_cls_str: DEFM "2J",0
fgcol_str:      DEFM "38;5;",0
bgcol_str:      DEFM "48;5;",0
