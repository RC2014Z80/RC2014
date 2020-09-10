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

INCLUDE         "rc2014.inc"

;==============================================================================
;
; Z80 INTERRUPT ORIGINATING VECTOR TABLE
;
SECTION         z80_vector_rst

EXTERN          INIT

;------------------------------------------------------------------------------
; RST 00 - RESET / TRAP
;               ALIGN    0x0000         ; ORG     0000H
                DI                      ; Disable interrupts
                JP      INIT            ; Initialize Hardware and go

;------------------------------------------------------------------------------
; RST 08
                ALIGN   0x0008          ; ORG     0008H
                JP      Z80_VECTOR_BASE-Z80_VECTOR_PROTO+RST_08_LBL

;------------------------------------------------------------------------------
; RST 10
                ALIGN   0x0010          ; ORG     0010H
                JP      Z80_VECTOR_BASE-Z80_VECTOR_PROTO+RST_10_LBL

;------------------------------------------------------------------------------
; RST 18
                ALIGN   0x0018          ; ORG     0018H
                JP      Z80_VECTOR_BASE-Z80_VECTOR_PROTO+RST_18_LBL

;------------------------------------------------------------------------------
; RST 20
                ALIGN   0x0020          ; ORG     0020H
                JP      Z80_VECTOR_BASE-Z80_VECTOR_PROTO+RST_20_LBL

;------------------------------------------------------------------------------
; RST 28
                ALIGN   0x0028          ; ORG     0028H
                JP      Z80_VECTOR_BASE-Z80_VECTOR_PROTO+RST_28_LBL

;------------------------------------------------------------------------------
; RST 30
                ALIGN   0x0030          ; ORG     0030H
                JP      Z80_VECTOR_BASE-Z80_VECTOR_PROTO+RST_30_LBL

;------------------------------------------------------------------------------
; RST 38 - INTERRUPT VECTOR INT0 [ with IM 1 ]

                ALIGN   0x0038          ; ORG     0038H
                JP      Z80_VECTOR_BASE-Z80_VECTOR_PROTO+INT_INT0_LBL

;==============================================================================
;
; Z80 INTERRUPT VECTOR TABLE PROTOTYPE
;
; WILL BE DUPLICATED DURING INIT TO:
;
;               ORG     Z80_VECTOR_BASE

SECTION         z80_vector_table_prototype

EXTERN          Z180_TRAP
EXTERN          RST_08, RST_10, RST_18, RST_20, RST_28, RST_30
EXTERN          INT_INT0, INT_NMI

Z180_TRAP_LBL:
                JP      Z180_TRAP
                NOP
RST_08_LBL:
                JP      RST_08
                NOP
RST_10_LBL:
                JP      RST_10
                NOP
RST_18_LBL:       
                LD      A,(serRxBufUsed)    ; this is called each token,
                RET                         ; so optimise it to here
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

SECTION         z80_vector_null_ret

PUBLIC          NULL_NMI, NULL_INT, NULL_RET

NULL_NMI:
                RETN
NULL_INT:
                EI
                RETI
NULL_RET:
                RET

;------------------------------------------------------------------------------
; NMI - INTERRUPT VECTOR NMI

SECTION         z80_vector_nmi
                JP      Z80_VECTOR_BASE-Z80_VECTOR_PROTO+INT_NMI_LBL

;==============================================================================

