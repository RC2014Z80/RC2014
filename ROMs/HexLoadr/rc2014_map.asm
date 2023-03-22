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

INCLUDE     "rc2014.inc"

SECTION     vector_rst
ORG         $0000

SECTION     vector_table_prototype
ORG         VECTOR_PROTO

SECTION     vector_null_ret
ORG         VECTOR_PROTO+VECTOR_SIZE

SECTION     vector_nmi
ORG         $0066

SECTION     acia_interrupt
ORG         $0070

SECTION     acia_rxa
ORG         $00D8

SECTION     acia_txa
ORG         $0108

SECTION     init
ORG         $0150

SECTION     init_strings
ORG         $01F0

;==============================================================================
