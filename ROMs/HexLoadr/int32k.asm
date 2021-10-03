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
; 115200 baud, 8n2
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
SECTION acia_interrupt              ; ORG $0080

.acia_int
        push af
        push hl

        in a,(SER_STATUS_ADDR)      ; get the status of the ACIA
        rrca                        ; check whether a byte has been received, via SER_RDRF
        jr NC,acia_tx_send          ; if not, go check for bytes to transmit

.acia_rx_get
        in a,(SER_DATA_ADDR)        ; Get the received byte from the ACIA 
        ld l,a                      ; Move Rx byte to l

        ld a,(serRxBufUsed)         ; Get the number of bytes in the Rx buffer
        cp SER_RX_BUFSIZE-1         ; check whether there is space in the buffer
        jr NC,acia_tx_check         ; buffer full, check if we can send something

        ld a,l                      ; get Rx byte from l
        ld hl,(serRxInPtr)          ; get the pointer to where we poke
        ld (hl),a                   ; write the Rx byte to the serRxInPtr address
        inc l                       ; move the Rx pointer low byte along, 0xFF rollover
        ld (serRxInPtr),hl          ; write where the next byte should be poked

        ld hl,serRxBufUsed
        inc (hl)                    ; atomically increment Rx buffer count

        ld a,(serRxBufUsed)         ; get the current Rx count
        cp SER_RX_FULLSIZE          ; compare the count with the preferred full size
        jp NZ,acia_tx_check         ; leave the RTS low, and check for Rx/Tx possibility

        ld a,(serControl)           ; get the ACIA control echo byte
        and ~SER_TEI_MASK           ; mask out the Tx interrupt bits
        or SER_TDI_RTS1             ; set RTS high, and disable Tx Interrupt
        ld (serControl),a           ; write the ACIA control echo byte back
        out (SER_CTRL_ADDR),a       ; set the ACIA CTRL register

.acia_tx_check
        in a,(SER_STATUS_ADDR)      ; get the status of the ACIA
        rrca                        ; check whether a byte has been received, via SER_RDRF
        jr C,acia_rx_get            ; another byte received, go get it

.acia_tx_send
        rrca                        ; check whether a byte can be transmitted, via SER_TDRE
        jr NC,acia_txa_end          ; if not, we're done for now

        ld a,(serTxBufUsed)         ; get the number of bytes in the Tx buffer
        or a                        ; check whether it is zero
        jp Z,acia_tei_clear         ; if the count is zero, then disable the Tx Interrupt

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

        jr NZ,acia_txa_end          ; if we've more Tx bytes to send, we're done for now

.acia_tei_clear
        ld a,(serControl)           ; get the ACIA control echo byte
        and ~SER_TEI_RTS0           ; mask out (disable) the Tx Interrupt
        ld (serControl),a           ; write the ACIA control byte back
        out (SER_CTRL_ADDR),a       ; set the ACIA CTRL register

.acia_txa_end
        pop hl
        pop af

        ei
        reti

;------------------------------------------------------------------------------
; SECTION acia_rxa_chk              ; ORG $00F0
;
; .RXA_CHK                          ; insert directly into JumP table
;       ld a,(serRxBufUsed)
;       ret

;------------------------------------------------------------------------------
SECTION acia_rxa                    ; ORG $00F0

.RXA
        ld a,(serRxBufUsed)         ; get the number of bytes in the Rx buffer
        or a                        ; see if there are zero bytes available
        jr Z,RXA                    ; wait, if there are no bytes available

        cp SER_RX_EMPTYSIZE         ; compare the count with the preferred empty size
        jp NZ,rxa_get_byte          ; if the buffer is too full, don't change the RTS

        di                          ; critical section begin
        ld a,(serControl)           ; get the ACIA control echo byte
        and ~SER_TEI_MASK           ; mask out the Tx interrupt bits
        or SER_TDI_RTS0             ; set RTS low.
        ld (serControl),a           ; write the ACIA control echo byte back
        ei                          ; critical section end
        out (SER_CTRL_ADDR),a       ; set the ACIA CTRL register

.rxa_get_byte
        push hl                     ; store HL so we don't clobber it

        ld hl,(serRxOutPtr)         ; get the pointer to place where we pop the Rx byte
        ld a,(hl)                   ; get the Rx byte
        inc l                       ; move the Rx pointer low byte along
        ld (serRxOutPtr),hl         ; write where the next byte should be popped

        ld hl,serRxBufUsed
        dec (hl)                    ; atomically decrement Rx count

        pop hl                      ; recover HL
        ret                         ; char ready in A

;------------------------------------------------------------------------------
SECTION acia_txa                    ; ORG $0120

.TXA                                ; output a character in A via ACIA
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

.txa_buffer_out
        ld a,(serTxBufUsed)         ; get the number of bytes in the Tx buffer
        cp SER_TX_BUFSIZE-1         ; check whether there is space in the buffer
        jr NC,txa_buffer_out        ; buffer full, so wait till it has space

        ld a,l                      ; retrieve Tx character

        ld hl,(serTxInPtr)          ; get the pointer to where we poke
        ld (hl),a                   ; write the Tx byte to the serTxInPtr

        inc l                       ; move the Tx pointer, just low byte along
        ld a,SER_TX_BUFSIZE-1       ; load the buffer size, (n^2)-1
        and l                       ; range check
        or serTxBuf&0xFF            ; locate base
        ld l,a                      ; return the low byte to l
        ld (serTxInPtr),hl          ; write where the next byte should be poked

        ld hl,serTxBufUsed
        inc (hl)                    ; atomic increment of Tx count

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
SECTION init                        ; ORG $0170

PUBLIC  INIT

.INIT
        LD SP,TEMPSTACK             ; set up a temporary stack

        LD HL,VECTOR_PROTO          ; establish Z80 RST Vector Table
        LD DE,VECTOR_BASE
        LD BC,VECTOR_SIZE
        LDIR

        LD HL,serRxBuf              ; initialise Rx Buffer
        LD (serRxInPtr),HL
        LD (serRxOutPtr),HL

        LD HL,serTxBuf              ; initialise Tx Buffer
        LD (serTxInPtr),HL
        LD (serTxOutPtr),HL

        XOR A                       ; zero the RXA & TXA Buffer Counts
        LD (serRxBufUsed),A
        LD (serTxBufUsed),A

        LD A,SER_RESET              ; master RESET the ACIA
        OUT (SER_CTRL_ADDR),A

        LD A,SER_REI|SER_TDI_RTS0|SER_8N2|SER_CLK_DIV_64
                                    ; load the default ACIA configuration
                                    ; 8n2 at 115200 baud
                                    ; receive interrupt enabled
                                    ; transmit interrupt disabled
                            
        LD (serControl),A           ; write the ACIA control byte echo
        OUT (SER_CTRL_ADDR),A       ; output to the ACIA control byte

        IM 1                        ; interrupt mode 1
        EI                          ; enable interrupts

.START
        LD HL,SIGNON1               ; sign-on message
        CALL PRINT                  ; output string
        LD A,(basicStarted)         ; check the BASIC STARTED flag
        CP 'Y'                      ; to see if this is power-up
        JP NZ,COLDSTART             ; if not BASIC started then always do cold start
        LD HL,SIGNON2               ; cold/warm message
        CALL PRINT                  ; output string
.CORW
        RST 10H
        AND 11011111B               ; lower to uppercase
        CP 'C'
        JP NZ,CHECKWARM
        RST 08H
        LD A,CR
        RST 08H
        LD A,LF
        RST 08H
.COLDSTART
        LD A,'Y'                    ; set the BASIC STARTED flag
        LD (basicStarted),A
        JP $0240                    ; <<<< Start Basic COLD

.CHECKWARM
        CP 'W'
        JP NZ,CORW
        RST 08H
        LD A,CR
        RST 08H
        LD A,LF
        RST 08H
.WARMSTART
        JP $0243                    ; <<<< Start Basic WARM

.PRINT
        LD A,(HL)                   ; get character
        OR A                        ; is it $00 ?
        RET Z                       ; then RETurn on terminator
        CALL TXA                    ; output character in A
        INC HL                      ; next Character
        JP PRINT                    ; continue until $00

;==============================================================================
;
; STRINGS
;
SECTION init_strings                ; ORG $01F0

.SIGNON1
        DEFM    CR,LF
        DEFM    "RC2014 - MS Basic Loader",CR,LF
        DEFM    "z88dk - feilipu",CR,LF,0

.SIGNON2
        DEFM    CR,LF
        DEFM    "Cold | Warm start (C|W) ? ",0

;==============================================================================
;
; Z80 INTERRUPT VECTOR PROTOTYPE ASSIGNMENTS
;

EXTERN  NULL_RET, NULL_INT, NULL_NMI

PUBLIC  RST_00, RST_08, RST_10; RST_18
PUBLIC  RST_20, RST_28, RST_30

PUBLIC  INT_INT, INT_NMI

DEFC    RST_00      =       INIT            ; Initialise, should never get here
DEFC    RST_08      =       TXA             ; TX character, loop until space
DEFC    RST_10      =       RXA             ; RX character, loop until byte
;       RST_18      =       RXA_CHK         ; Check receive buffer status, return # bytes available
DEFC    RST_20      =       NULL_RET        ; RET
DEFC    RST_28      =       NULL_RET        ; RET
DEFC    RST_30      =       NULL_RET        ; RET
DEFC    INT_INT     =       acia_int        ; ACIA interrupt
DEFC    INT_NMI     =       NULL_NMI        ; RETN

;==============================================================================

