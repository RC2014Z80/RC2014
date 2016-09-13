;@---------------------------------------------------------------------
;@  RC2014 Initialization and I/O routines
;@      Filippo Bergamasco 2016
;@
;@
;@  See http://rc2014.co.uk for schematics and description
;@  of the RC2014 homebrew computer
;@
;@---------------------------------------------------------------------

section INIT
EXTERN __Start

ORG 0000h			; start at 0x0000

RST00:      di                  ; disable interrupts
            jp bootstrap
            nop
            nop
            nop
            nop                 ; pad to address 0x0008

RST08:      jp TX
            nop
            nop
            nop
            nop
            nop

RST10:      jp rc2014_getc
            nop
            nop
            nop
            nop
            nop
RST18:      jp rc2014_pollc
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            nop
            nop
RST38:      reti

TX:         push af
txbusy:     in a,($80)          ; read serial status
            bit 1,a             ; check status bit 1
            jr z, txbusy        ; loop if zero (serial is busy)
            pop af
            out ($81), a        ; transmit the character
            ret

bootstrap:  ld hl,$FFF9         ; stack initialization
            ld sp,hl

            ld a, $96           ; Initialize ACIA
            out ($80),a

            di

            jp __Start  ;; this label is exported by the crt
                        ;; if you expect main() to return here use call instead
                        ;; if you know the c compiled portion will append here
                        ;; you can just fall through


;@ Follows additional functions to interact with rc2014 hardware
;@
;@---------------------------------------------------------------------
;@ rc2014_getc
;@
;@  wait for system UART and return the received character in HL
;@
;@---------------------------------------------------------------------
public rc2014_getc
rc2014_getc:
            push af
waitch:     in a, ($80)
            bit 0, a
            jr z, waitch
            in a, ($81)
            ld h, 0
            ld l, a
            pop af
            ret


;@---------------------------------------------------------------------
;@ rc2014_putc
;@
;@ output the byte in register L to system UART
;@
;@---------------------------------------------------------------------
public rc2014_putc
rc2014_putc:
            ld a, l
            rst $08
            ret


;@---------------------------------------------------------------------
;@ rc2014_pollc
;@
;@ polls the uart receive buffer status and
;@ returns the result in the register L:
;@   L=0 : no data available
;@   L=1 : data available
;@
;@---------------------------------------------------------------------
public rc2014_pollc
rc2014_pollc:
            ld l, 0
            in a, ($80)
            bit 0, a
            ret z
            ld l, 1
            ret


;@---------------------------------------------------------------------
;@ rc2014_inp
;@
;@ reads a byte from port l and returns the results in l
;@
;@---------------------------------------------------------------------
public rc2014_inp
rc2014_inp:
            push bc
            ld c, l
            in b, (c)
            ld l, b
            pop bc
            ret


;@---------------------------------------------------------------------
;@ rc2014_inp
;@
;@ writes register l to port h
;@
;@---------------------------------------------------------------------
public rc2014_outp
rc2014_outp:
            push bc
            ld c, h
            ld b, l
            out (c), b
            pop bc
            ret
