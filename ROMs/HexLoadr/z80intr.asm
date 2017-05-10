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

;==============================================================================
;
; REQUIRES
;
; Z80_VECTOR_BASE   .EQU    RAM vector address for Z80 RST eg.
;
; Z80_VECTOR_BASE   .EQU    RAMSTART_CA0    ; RAM vector address for Z80 RST
;
; #include          "d:/yaz180.h"           ; OR
; #include          "d:/rc2014.h"

;==============================================================================
;
; Z80 INTERRUPT ORIGINATING VECTOR TABLE
;

;------------------------------------------------------------------------------
; RST 00 - RESET / TRAP
                .ORG    0000H
                DI                  ; Disable interrupts
                JP      INIT        ; Initialize Hardware and go

;------------------------------------------------------------------------------
; RST 08
                .ORG    0008H
                JP      Z80_VECTOR_BASE-Z80_VECTOR_PROTO+RST_08_LBL

;------------------------------------------------------------------------------
; RST 10
                .ORG    0010H
                JP      Z80_VECTOR_BASE-Z80_VECTOR_PROTO+RST_10_LBL

;------------------------------------------------------------------------------
; RST 18
                .ORG    0018H
                JP      Z80_VECTOR_BASE-Z80_VECTOR_PROTO+RST_18_LBL

;------------------------------------------------------------------------------
; RST 20
                .ORG    0020H
                JP      Z80_VECTOR_BASE-Z80_VECTOR_PROTO+RST_20_LBL

;------------------------------------------------------------------------------
; RST 28
                .ORG    0028H
                JP      Z80_VECTOR_BASE-Z80_VECTOR_PROTO+RST_28_LBL

;------------------------------------------------------------------------------
; RST 30
                .ORG    0030H
                JP      Z80_VECTOR_BASE-Z80_VECTOR_PROTO+RST_30_LBL

;------------------------------------------------------------------------------
; RST 38 - INTERRUPT VECTOR INT0 [ with IM 1 ]

                .ORG    0038H
                JP      Z80_VECTOR_BASE-Z80_VECTOR_PROTO+INT_INT0_LBL

;==============================================================================
;
; Z80 INTERRUPT VECTOR TABLE PROTOTYPE
;
; WILL BE DUPLICATED DURING INIT TO:
;
;               .ORG    Z80_VECTOR_BASE

                .ORG    Z80_VECTOR_PROTO
RST_08_LBL:
                JP      RST_08
                NOP
RST_10_LBL:
                JP      RST_10
                NOP
RST_18_LBL:
                JP      RST_18
                NOP
RST_20_LBL:
                JP      RST_20
                NOP
RST_28_LBL:
                JP      RST_28
                NOP
RST_30_LBL:
                JP      RST_30
                NOP
INT_INT0_LBL:
                JP      INT_INT0
                NOP
INT_NMI_LBL:
                JP      INT_NMI
                NOP

;------------------------------------------------------------------------------
; NULL RETURN INSTRUCTIONS

                .ORG    Z80_VECTOR_PROTO+Z80_VECTOR_SIZE
NULL_NMI:
                RETN
NULL_INT:
                EI
                RETI
NULL_RET:
                RET

;------------------------------------------------------------------------------
; NMI - INTERRUPT VECTOR NMI

                .ORG    0066H
                JP      Z80_VECTOR_BASE-Z80_VECTOR_PROTO+INT_NMI_LBL

;==============================================================================
;
                .END
;
;==============================================================================


