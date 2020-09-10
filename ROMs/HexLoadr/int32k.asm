;==============================================================================
;
; The rework to support MS Basic HLOAD and the Z80 instruction tuning are
; copyright (C) 2020 Phillip Stevens
;
; This Source Code Form is subject to the terms of the Mozilla Public
; License, v. 2.0. If a copy of the MPL was not distributed with this
; file, You can obtain one at http://mozilla.org/MPL/2.0/.
;
; ACIA 6850 interrupt driven serial I/O to run modified NASCOM Basic 4.7.
; Full input and output buffering with incoming data hardware handshaking.
; Handshake shows full before the buffer is totally filled to allow run-on
; from the sender. Transmit and receive are interrupt driven.
;
; feilipu, August 2020
;
;==============================================================================
;
; The updates to the original BASIC within this file are copyright Grant Searle
;
; You have permission to use this for NON COMMERCIAL USE ONLY
; If you wish to use it elsewhere, please include an acknowledgement to myself.
;
; http://searle.wales/
;
;==============================================================================
;
; NASCOM ROM BASIC Ver 4.7, (C) 1978 Microsoft
; Scanned from source published in 80-BUS NEWS from Vol 2, Issue 3
; (May-June 1983) to Vol 3, Issue 3 (May-June 1984)
; Adapted for the freeware Zilog Macro Assembler 2.10 to produce
; the original ROM code (checksum A934H). PA
;
;==============================================================================
;
; INCLUDES SECTION
;

INCLUDE "rc2014.inc"

;==============================================================================
;
; CODE SECTION
;

;------------------------------------------------------------------------------
SECTION z80_acia_interrupt


serialInt:
        push af
        push hl
                                    ; start doing the Rx stuff
        in a,(SER_STATUS_ADDR)      ; get the status of the ACIA
        and SER_RDRF                ; check whether a byte has been received
        jr Z,im1_tx_check           ; if not, go check for bytes to transmit 

        in a,(SER_DATA_ADDR)        ; Get the received byte from the ACIA 
        ld l,a                      ; Move Rx byte to l

        ld a,(serRxBufUsed)         ; Get the number of bytes in the Rx buffer
        cp SER_RX_BUFSIZE-1         ; check whether there is space in the buffer
        jr NC,im1_tx_check          ; buffer full, check if we can send something

        ld a,l                      ; get Rx byte from l
        ld hl,serRxBufUsed
        inc (hl)                    ; atomically increment Rx buffer count
        ld hl,(serRxInPtr)          ; get the pointer to where we poke
        ld (hl),a                   ; write the Rx byte to the serRxInPtr address

        inc l                       ; move the Rx pointer low byte along, 0xFF rollover
        ld (serRxInPtr),hl          ; write where the next byte should be poked

im1_tx_check:                       ; now start doing the Tx stuff
        in a,(SER_STATUS_ADDR)      ; get the status of the ACIA
        and SER_TDRE                ; check whether a byte can be transmitted
        jr Z,im1_rts_check          ; if not, go check for the receive RTS selection

        ld a,(serTxBufUsed)         ; get the number of bytes in the Tx buffer
        or a                        ; check whether it is zero
        jr Z,im1_tei_clear          ; if the count is zero, then disable the Tx Interrupt

        ld hl,(serTxOutPtr)         ; get the pointer to place where we pop the Tx byte
        ld a,(hl)                   ; get the Tx byte
        out (SER_DATA_ADDR),a       ; output the Tx byte to the ACIA

        inc l                       ; move the Tx pointer, just low byte, along
        ld a,SER_TX_BUFSIZE-1       ; load the buffer size, (n^2)-1
        and l                       ; range check
        or serTxBuf&0xFF            ; locate base
        ld l,a                      ; return the low byte to l
        ld (serTxOutPtr),hl         ; write where the next byte should be popped

        ld hl,serTxBufUsed
        dec (hl)                    ; atomically decrement current Tx count

        jr NZ,im1_txa_end           ; if we've more Tx bytes to send, we're done for now

im1_tei_clear:
        ld a,(serControl)           ; get the ACIA control echo byte
        and ~SER_TEI_MASK           ; mask out the Tx interrupt bits
        or SER_TDI_RTS0             ; mask out (disable) the Tx Interrupt, keep RTS low
        ld (serControl),a           ; write the ACIA control byte back
        out (SER_CTRL_ADDR),a       ; Set the ACIA CTRL register

im1_rts_check:
        ld a,(serRxBufUsed)         ; get the current Rx count
        cp SER_RX_FULLSIZE          ; compare the count with the preferred full size
        jr C,im1_txa_end            ; leave the RTS low, and end

        ld a,(serControl)           ; get the ACIA control echo byte
        and ~SER_TEI_MASK           ; mask out the Tx interrupt bits
        or SER_TDI_RTS1             ; Set RTS high, and disable Tx Interrupt
        ld (serControl),a           ; write the ACIA control echo byte back
        out (SER_CTRL_ADDR),a       ; Set the ACIA CTRL register

im1_txa_end:
        pop hl
        pop af

        ei
        reti

;------------------------------------------------------------------------------
; SECTION z80_acia_rxa_chk          ; ORG $00F0
; RXA_CHK:                          ; insert directly into JumP table
;       ld a,(serRxBufUsed)
;       ret

;------------------------------------------------------------------------------
SECTION z80_acia_rxa                ; ORG $00F0
RXA:
        ld a,(serRxBufUsed)         ; get the number of bytes in the Rx buffer
        or a                        ; see if there are zero bytes available
        jr Z,RXA                    ; wait, if there are no bytes available

        cp SER_RX_EMPTYSIZE         ; compare the count with the preferred empty size
        jr NC,rxa_clean_up          ; if the buffer is too full, don't change the RTS

        di                          ; critical section begin
        ld a,(serControl)           ; get the ACIA control echo byte
        and ~SER_TEI_MASK           ; mask out the Tx interrupt bits
        or SER_TDI_RTS0             ; set RTS low.
        ld (serControl),a           ; write the ACIA control echo byte back
        ei                          ; critical section end
        out (SER_CTRL_ADDR),a       ; set the ACIA CTRL register

rxa_clean_up:
        push hl                     ; store HL so we don't clobber it

        ld hl,serRxBufUsed
        di
        dec (hl)                    ; atomically decrement Rx count
        ld hl,(serRxOutPtr)         ; get the pointer to place where we pop the Rx byte
        ei
        ld a,(hl)                   ; get the Rx byte

        inc l                       ; move the Rx pointer low byte along
        ld (serRxOutPtr),hl         ; write where the next byte should be popped

        pop hl                      ; recover HL
        ret                         ; char ready in A

;------------------------------------------------------------------------------
SECTION z80_acia_txa                ; ORG $0120
TXA:
        push hl                     ; store HL so we don't clobber it
        ld l,a                      ; store Tx character

        ld a,(serTxBufUsed)         ; Get the number of bytes in the Tx buffer
        or a                        ; check whether the buffer is empty
        jr NZ,txa_buffer_out        ; buffer not empty, so abandon immediate Tx

        in a,(SER_STATUS_ADDR)      ; get the status of the ACIA
        and SER_TDRE                ; check whether a byte can be transmitted
        jr Z,txa_buffer_out         ; if not, so abandon immediate Tx

        ld a,l                      ; Retrieve Tx character for immediate Tx
        out (SER_DATA_ADDR),a       ; immediately output the Tx byte to the ACIA

        pop hl                      ; recover HL
        ret                         ; and just complete

txa_buffer_out:
        ld a,(serTxBufUsed)         ; Get the number of bytes in the Tx buffer
        cp SER_TX_BUFSIZE-1         ; check whether there is space in the buffer
        jr NC,txa_buffer_out        ; buffer full, so wait till it has space

        ld a,l                      ; Retrieve Tx character

        ld hl,serTxBufUsed
        di
        inc (hl)                    ; atomic increment of Tx count
        ld hl,(serTxInPtr)          ; get the pointer to where we poke
        ei
        ld (hl),a                   ; write the Tx byte to the serTxInPtr

        inc l                       ; move the Tx pointer, just low byte along
        ld a,SER_TX_BUFSIZE-1       ; load the buffer size, (n^2)-1
        and l                       ; range check
        or serTxBuf&0xFF            ; locate base
        ld l,a                      ; return the low byte to l
        ld (serTxInPtr),hl          ; write where the next byte should be poked

        pop hl                      ; recover HL

        ld a,(serControl)           ; get the ACIA control echo byte
        and SER_TEI_RTS0            ; test whether ACIA interrupt is set
        ret NZ                      ; if so then just return

        di                          ; critical section begin
        ld a,(serControl)           ; get the ACIA control echo byte again
        and ~SER_TEI_MASK           ; mask out the Tx interrupt bits
        or SER_TEI_RTS0             ; set RTS low. if the TEI was not set, it will work again
        ld (serControl),a           ; write the ACIA control echo byte back
        out (SER_CTRL_ADDR),a       ; set the ACIA CTRL register
        ei                          ; critical section end
        ret

;------------------------------------------------------------------------------
SECTION z80_acia_print              ; ORG $0170
PRINT:
        LD        A,(HL)            ; Get character
        OR        A                 ; Is it $00 ?
        RET       Z                 ; Then RETurn on terminator
        CALL      TXA               ; Print it
        INC       HL                ; Next Character
        JR        PRINT             ; Continue until $00

;------------------------------------------------------------------------------
SECTION        z80_init             ; ORG $0180

PUBLIC  INIT

INIT:
        LD SP,TEMPSTACK             ; Set up a temporary stack

        LD HL,Z80_VECTOR_PROTO      ; Establish Z80 RST Vector Table
        LD DE,Z80_VECTOR_BASE
        LD BC,Z80_VECTOR_SIZE
        LDIR

        LD HL,serRxBuf              ; Initialise Rx Buffer
        LD (serRxInPtr),HL
        LD (serRxOutPtr),HL

        LD HL,serTxBuf              ; Initialise Tx Buffer
        LD (serTxInPtr),HL
        LD (serTxOutPtr),HL              

        XOR A                       ; 0 the RXA & TXA Buffer Counts
        LD (serRxBufUsed),A
        LD (serTxBufUsed),A

        LD A,SER_RESET              ; Master Reset the ACIA
        OUT (SER_CTRL_ADDR),A

        LD A,SER_REI|SER_TDI_RTS0|SER_8N1|SER_CLK_DIV_64
                                    ; load the default ACIA configuration
                                    ; 8n1 at 115200 baud
                                    ; receive interrupt enabled
                                    ; transmit interrupt disabled
                            
        LD (serControl),A           ; write the ACIA control byte echo
        OUT (SER_CTRL_ADDR),A       ; output to the ACIA control byte

        IM 1                        ; interrupt mode 1
        EI

START:
        LD HL,SIGNON1               ; Sign-on message
        CALL PRINT                  ; Output string
        LD A,(basicStarted)         ; Check the BASIC STARTED flag
        CP 'Y'                      ; to see if this is power-up
        JR NZ,COLDSTART             ; If not BASIC started then always do cold start
        LD HL,SIGNON2               ; Cold/warm message
        CALL PRINT                  ; Output string
CORW:
        RST 10H
        AND 11011111B               ; lower to uppercase
        CP 'C'
        JR NZ,CHECKWARM
        RST 08H
        LD A,CR
        RST 08H
        LD A,LF
        RST 08H
COLDSTART:
        LD A,'Y'                    ; Set the BASIC STARTED flag
        LD (basicStarted),A
        JP $0250                    ; <<<< Start Basic COLD:
CHECKWARM:
        CP 'W'
        JR NZ,CORW
        RST 08H
        LD A,CR
        RST 08H
        LD A,LF
        RST 08H
WARMSTART:
        JP $0253                    ; <<<< Start Basic WARM:

;==============================================================================
;
; STRINGS
;
SECTION         z80_init_strings    ; ORG $01F0

SIGNON1:        DEFM    CR,LF
                DEFM    "RC2014 - MS Basic Loader",CR,LF
                DEFM    "z88dk - feilipu",CR,LF,0

SIGNON2:        DEFM    CR,LF
                DEFM    "Cold | Warm start (C|W) ? ",0

;==============================================================================
;
; Z80 INTERRUPT VECTOR PROTOTYPE ASSIGNMENTS
;

EXTERN  NULL_RET, NULL_INT, NULL_NMI

PUBLIC  Z180_TRAP
PUBLIC  RST_08, RST_10, RST_20, RST_28, RST_30
PUBLIC  INT_INT0, INT_NMI

DEFC    Z180_TRAP   =       INIT            ; Initialise, should never get here
DEFC    RST_08      =       TXA             ; TX character over ACIA, loop until space
DEFC    RST_10      =       RXA             ; RX character over ACIA, loop until byte
;       RST_18      =       RXA_CHK         ; Check ACIA status, return # bytes available
DEFC    RST_20      =       NULL_RET        ; RET
DEFC    RST_28      =       NULL_RET        ; RET
DEFC    RST_30      =       NULL_RET        ; RET
DEFC    INT_INT0    =       serialInt       ; ACIA interrupt
DEFC    INT_NMI     =       NULL_NMI        ; RETN

;==============================================================================

