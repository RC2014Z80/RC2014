;==============================================================================
; Contents of this file are copyright Phillip Stevens
;
; You have permission to use this for NON COMMERCIAL USE ONLY
; If you wish to use it elsewhere, please include an acknowledgement to myself.
;
; https://github.com/feilipu/
;
; https://feilipu.me/
;

INCLUDE     "rc2014.h"

SECTION     z80_vector_rst
ORG         0x0000

SECTION     z80_vector_table_prototype
ORG         Z80_VECTOR_PROTO

SECTION     z80_vector_null_ret
ORG         Z80_VECTOR_PROTO+Z80_VECTOR_SIZE

SECTION     z80_vector_nmi
ORG         0x0066

SECTION     z80_acia_interrupt
ORG         0x0080

SECTION     z80_acia_rxa_chk
ORG         0x00F0

SECTION     z80_acia_rxa
ORG         0x0100

SECTION     z80_acia_txa
ORG         0x0130

SECTION     z80_acia_print
ORG         0x0180

SECTION     z80_hexloadr
ORG         0x0190

SECTION     z80_init
ORG         0x0240

SECTION     z80_init_strings
ORG         0x02D0

;==============================================================================
