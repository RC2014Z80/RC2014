;==============================================================================
; Contents of parts of this file are copyright Grant Searle
;
; You have permission to use this for NON COMMERCIAL USE ONLY
; If you wish to use it elsewhere, please include an acknowledgement to myself.
;
; http://searle.hostei.com/grant/index.html
;
; eMail: home.micros01@btinternet.com
;
; If the above don't work, please perform an Internet search to see if I have
; updated the web page hosting service.
;
;==============================================================================
;
; ACIA 6850 interrupt driven serial I/O to run modified NASCOM Basic 4.7.
; Full input and output buffering with incoming data hardware handshaking.
; Handshake shows full before the buffer is totally filled to
; allow run-on from the sender. Transmit and receive are interrupt driven.
;
; https://github.com/feilipu/
; https://feilipu.me/
;
;==============================================================================
;
; HexLoadr option by @feilipu,
; derived from the work of @fbergama and @foxweb at RC2014
; https://github.com/RC2014Z80
;

;==============================================================================
;
; INCLUDES SECTION
;

INCLUDE "rc2014.h"

;==============================================================================
;
; CODE SECTION
;
SECTION z80_acia_interrupt
;------------------------------------------------------------------------------

serialInt:
        push af
        push hl
                                    ; start doing the Rx stuff
        in a, (SER_STATUS_ADDR)     ; get the status of the ACIA
        and SER_RDRF                ; check whether a byte has been received
        jr z, im1_tx_check          ; if not, go check for bytes to transmit 

        in a, (SER_DATA_ADDR)       ; Get the received byte from the ACIA 
        ld l, a                     ; Move Rx byte to l

        ld a, (serRxBufUsed)        ; Get the number of bytes in the Rx buffer
        cp SER_RX_BUFSIZE-1         ; check whether there is space in the buffer
        jr nc, im1_tx_check         ; buffer full, check if we can send something

        ld a, l                     ; get Rx byte from l
        ld hl, (serRxInPtr)         ; get the pointer to where we poke
        ld (hl), a                  ; write the Rx byte to the serRxInPtr address

        inc l                       ; move the Rx pointer low byte along, 0xFF rollover
        ld (serRxInPtr), hl         ; write where the next byte should be poked

        ld hl, serRxBufUsed
        inc (hl)                    ; atomically increment Rx buffer count

im1_tx_check:                       ; now start doing the Tx stuff
        in a, (SER_STATUS_ADDR)     ; get the status of the ACIA
        and SER_TDRE                ; check whether a byte can be transmitted
        jr z, im1_rts_check         ; if not, go check for the receive RTS selection

        ld a, (serTxBufUsed)        ; get the number of bytes in the Tx buffer
        or a                        ; check whether it is zero
        jr z, im1_tei_clear         ; if the count is zero, then disable the Tx Interrupt

        ld hl, (serTxOutPtr)        ; get the pointer to place where we pop the Tx byte
        ld a, (hl)                  ; get the Tx byte
        out (SER_DATA_ADDR), a      ; output the Tx byte to the ACIA

        inc l                       ; move the Tx pointer, just low byte, along
        ld a, SER_TX_BUFSIZE-1      ; load the buffer size, (n^2)-1
        and l                       ; range check
        ld l, a                     ; return the low byte to l
        ld (serTxOutPtr), hl        ; write where the next byte should be popped

        ld hl, serTxBufUsed
        dec (hl)                    ; atomically decrement current Tx count

        jr nz, im1_txa_end          ; if we've more Tx bytes to send, we're done for now

im1_tei_clear:
        ld a, (serControl)          ; get the ACIA control echo byte
        and ~SER_TEI_MASK           ; mask out the Tx interrupt bits
        or SER_TDI_RTS0             ; mask out (disable) the Tx Interrupt, keep RTS low
        ld (serControl), a          ; write the ACIA control byte back
        out (SER_CTRL_ADDR), a      ; Set the ACIA CTRL register

im1_rts_check:
        ld a, (serRxBufUsed)        ; get the current Rx count
        cp SER_RX_FULLSIZE          ; compare the count with the preferred full size
        jr c, im1_txa_end           ; leave the RTS low, and end

        ld a, (serControl)          ; get the ACIA control echo byte
        and ~SER_TEI_MASK           ; mask out the Tx interrupt bits
        or SER_TDI_RTS1             ; Set RTS high, and disable Tx Interrupt
        ld (serControl), a          ; write the ACIA control echo byte back
        out (SER_CTRL_ADDR), a	    ; Set the ACIA CTRL register

im1_txa_end:
        pop hl
        pop af

        ei
        reti

;------------------------------------------------------------------------------
SECTION z80_acia_rxa_chk            ; ORG $00F0
RXA_CHK:
        ld a, (serRxBufUsed)
        cp $0
        ret

;------------------------------------------------------------------------------
SECTION z80_acia_rxa                ; ORG $0100
RXA:
        ld a, (serRxBufUsed)        ; get the number of bytes in the Rx buffer
        or a                        ; see if there are zero bytes available
        jr z, RXA                   ; wait, if there are no bytes available
        
        push hl                     ; Store HL so we don't clobber it

        ld hl, (serRxOutPtr)        ; get the pointer to place where we pop the Rx byte
        ld a, (hl)                  ; get the Rx byte
        ld i, a                     ; save the Rx byte in I

        inc l                       ; move the Rx pointer low byte along
        ld (serRxOutPtr), hl        ; write where the next byte should be popped

        ld hl,serRxBufUsed
        dec (hl)                    ; atomically decrement Rx count
        ld a,(hl)                   ; get the newly decremented Rx count

        cp SER_RX_EMPTYSIZE         ; compare the count with the preferred empty size
        jr nc, rxa_clean_up         ; if the buffer is too full, don't change the RTS

        di                          ; critical section begin
        ld a, (serControl)          ; get the ACIA control echo byte
        and ~SER_TEI_MASK           ; mask out the Tx interrupt bits
        or SER_TDI_RTS0             ; set RTS low.
        ld (serControl), a          ; write the ACIA control echo byte back
        out (SER_CTRL_ADDR), a      ; set the ACIA CTRL register
        ei                          ; critical section end

rxa_clean_up:
        ld a, i                     ; get the Rx byte from I
        pop hl                      ; recover HL
        ret                         ; char ready in A

;------------------------------------------------------------------------------
SECTION z80_acia_txa                ; ORG $0130
TXA:
        push hl                     ; store HL so we don't clobber it
        ld l, a                     ; store Tx character

        ld a, (serTxBufUsed)        ; Get the number of bytes in the Tx buffer
        or a                        ; check whether the buffer is empty
        jr nz, txa_buffer_out       ; buffer not empty, so abandon immediate Tx

        in a, (SER_STATUS_ADDR)     ; get the status of the ACIA
        and SER_TDRE                ; check whether a byte can be transmitted
        jr z, txa_buffer_out        ; if not, so abandon immediate Tx

        ld a, l                     ; Retrieve Tx character for immediate Tx
        out (SER_DATA_ADDR), a      ; immediately output the Tx byte to the ACIA

        pop hl                      ; recover HL
        ret                         ; and just complete

txa_buffer_out:
        ld a, (serTxBufUsed)        ; Get the number of bytes in the Tx buffer
        cp SER_TX_BUFSIZE-1         ; check whether there is space in the buffer
        jr nc, txa_buffer_out       ; buffer full, so wait till it has space

        ld a, l                     ; Retrieve Tx character
        ld hl, (serTxInPtr)         ; get the pointer to where we poke
        ld (hl), a                  ; write the Tx byte to the serTxInPtr

        inc l                       ; move the Tx pointer, just low byte along
        ld a, SER_TX_BUFSIZE-1      ; load the buffer size, (n^2)-1
        and l                       ; range check
        ld l, a                     ; return the low byte to l
        ld (serTxInPtr), hl         ; write where the next byte should be poked

        ld hl, serTxBufUsed
        inc (hl)                    ; atomic increment of Tx count

        pop hl                      ; recover HL

        ld a, (serControl)          ; get the ACIA control echo byte
        and SER_TEI_RTS0            ; test whether ACIA interrupt is set
        ret nz                      ; if so then just return

        di                          ; critical section begin
        ld a, (serControl)          ; get the ACIA control echo byte again
        and ~SER_TEI_MASK           ; mask out the Tx interrupt bits
        or SER_TEI_RTS0             ; set RTS low. if the TEI was not set, it will work again
        ld (serControl), a          ; write the ACIA control echo byte back
        out (SER_CTRL_ADDR), a      ; set the ACIA CTRL register
        ei                          ; critical section end
        ret

;------------------------------------------------------------------------------
SECTION z80_acia_print              ; ORG $0180
PRINT:
        LD        A,(HL)            ; Get character
        OR        A                 ; Is it $00 ?
        RET       Z                 ; Then RETurn on terminator
        CALL      TXA               ; Print it
        INC       HL                ; Next Character
        JR        PRINT             ; Continue until $00

;------------------------------------------------------------------------------
SECTION     z80_hexloadr            ; ORG $0190
HEX_START:
            ld hl, initString
            call PRINT
HEX_WAIT_COLON:
            call RXA        ; Rx byte
            cp ':'          ; wait for ':'
            jr nz, HEX_WAIT_COLON
            ld hl, 0        ; reset hl to compute checksum
            call HEX_READ_BYTE  ; read byte count
            ld b, a         ; store it in b
            call HEX_READ_BYTE  ; read upper byte of address
            ld d, a         ; store in d
            call HEX_READ_BYTE  ; read lower byte of address
            ld e, a         ; store in e
            call HEX_READ_BYTE  ; read record type
            cp 01           ; check if record type is 01 (end of file)
            jr z, HEX_END_LOAD
            cp 00           ; check if record type is 00 (data)
            jr nz, HEX_INVAL_TYPE ; if not, error
HEX_READ_DATA:
;            ld a, '*'       ; "*" per byte loaded  # DEBUG
;            call TXA        ; Print it             # DEBUG
            call HEX_READ_BYTE
            ld (de), a      ; write the byte at the RAM address
            inc de
            djnz HEX_READ_DATA  ; if b non zero, loop to get more data
HEX_READ_CHKSUM:
            call HEX_READ_BYTE  ; read checksum, but we don't need to keep it
            ld a, l         ; lower byte of hl checksum should be 0
            or a
            jr nz, HEX_BAD_CHK  ; non zero, we have an issue
            ld a, '#'       ; "#" per line loaded
            call TXA        ; Print it
;            ld a, CR        ; CR                   # DEBUG
;            call TXA        ; Print it             # DEBUG
;            ld a, LF        ; LF                   # DEBUG
;            call TXA        ; Print it             # DEBUG
            jr HEX_WAIT_COLON

HEX_END_LOAD:
            call HEX_READ_BYTE  ; read checksum, but we don't need to keep it
            ld a, l         ; lower byte of hl checksum should be 0
            or a
            jr nz, HEX_BAD_CHK  ; non zero, we have an issue
            ld hl, LoadOKStr
            call PRINT
            jp WARMSTART    ; ready to run our loaded program from Basic

HEX_INVAL_TYPE:
            ld hl, invalidTypeStr
            call PRINT
            jp START        ; go back to start

HEX_BAD_CHK:
            ld hl, badCheckSumStr
            call PRINT
            jp START        ; go back to start

HEX_READ_BYTE:              ; Returns byte in a, checksum in hl
            push bc
            call RXA        ; Rx byte
            sub '0'
            cp 10
            jr c, HEX_READ_NBL2 ; if a<10 read the second nibble
            sub 7           ; else subtract 'A'-'0' (17) and add 10
HEX_READ_NBL2:
            rlca            ; shift accumulator left by 4 bits
            rlca
            rlca
            rlca
            ld c, a         ; temporarily store the first nibble in c
            call RXA        ; Rx byte
            sub '0'
            cp 10
            jr c, HEX_READ_END  ; if a<10 finalize
            sub 7           ; else subtract 'A' (17) and add 10
HEX_READ_END:
            or c            ; assemble two nibbles into one byte in a
            ld b, 0         ; add the byte read to hl (for checksum)
            ld c, a
            add hl, bc
            pop bc
            ret             ; return the byte read in a

;------------------------------------------------------------------------------
SECTION        z80_init                  ; ORG $0240

PUBLIC         INIT

INIT:
               LD        SP,TEMPSTACK    ; Set up a temporary stack

               LD        HL,Z80_VECTOR_PROTO ; Establish Z80 RST Vector Table
               LD        DE,Z80_VECTOR_BASE
               LD        BC,Z80_VECTOR_SIZE
               LDIR

               LD        HL,serRxBuf     ; Initialise Rx Buffer
               LD        (serRxInPtr),HL
               LD        (serRxOutPtr),HL

               LD        HL,serTxBuf     ; Initialise Tx Buffer
               LD        (serTxInPtr),HL
               LD        (serTxOutPtr),HL              

               XOR       A               ; 0 the RXA & TXA Buffer Counts
               LD        (serRxBufUsed),A
               LD        (serTxBufUsed),A

               LD        A, SER_RESET    ; Master Reset the ACIA
               OUT       (SER_CTRL_ADDR),A

               LD        A, SER_REI|SER_TDI_RTS0|SER_8N1|SER_CLK_DIV_64
                                         ; load the default ACIA configuration
                                         ; 8n1 at 115200 baud
                                         ; receive interrupt enabled
                                         ; transmit interrupt disabled
                                    
               LD        (serControl),A     ; write the ACIA control byte echo
               OUT       (SER_CTRL_ADDR),A  ; output to the ACIA control byte

               IM        1               ; interrupt mode 1
               EI

START:
               LD        HL, SIGNON1     ; Sign-on message
               CALL      PRINT           ; Output string
               LD        A,(basicStarted); Check the BASIC STARTED flag
               CP        'Y'             ; to see if this is power-up
               JR        NZ, COLDSTART   ; If not BASIC started then always do cold start
               LD        HL, SIGNON2     ; Cold/warm message
               CALL      PRINT           ; Output string
CORW:
               RST       10H
               AND       11011111B       ; lower to uppercase
               CP        'H'             ; are we trying to load an Intel HEX program?
               JP        Z, HEX_START    ; then jump to HexLoadr
               CP        'C'
               JR        NZ, CHECKWARM
               RST       08H
               LD        A,CR
               RST       08H
               LD        A,LF
               RST       08H
COLDSTART:
               LD        A,'Y'           ; Set the BASIC STARTED flag
               LD        (basicStarted),A
               JP        $0390           ; <<<< Start Basic COLD:
CHECKWARM:
               CP        'W'
               JR        NZ, CORW
               RST       08H
               LD        A,CR
               RST       08H
               LD        A,LF
               RST       08H
WARMSTART:
               JP        $0393           ; <<<< Start Basic WARM:

;==============================================================================
;
; STRINGS
;
SECTION         z80_init_strings         ; ORG $02D0

SIGNON1:        DEFM    CR,LF
                DEFM    "SBC - Grant Searle",CR,LF
                DEFM    "ACIA - feilipu",CR,LF
                DEFM    "z88dk",CR,LF,0

SIGNON2:        DEFM    CR,LF
                DEFM    "Cold or Warm start, "
                DEFM    "or HexLoadr (C|W|H) ? ",0

initString:     DEFM    CR,LF,"HexLoadr: "
                DEFM    CR,LF,0

invalidTypeStr: DEFM    CR,LF,"Invalid Type",CR,LF,0
badCheckSumStr: DEFM    CR,LF,"Checksum Error",CR,LF,0
LoadOKStr:      DEFM    CR,LF,"Done",CR,LF,0

;==============================================================================
;
; Z80 INTERRUPT VECTOR PROTOTYPE ASSIGNMENTS
;

EXTERN  NULL_RET, NULL_INT, NULL_NMI

PUBLIC  Z180_TRAP
PUBLIC  RST_08, RST_10, RST_18, RST_20, RST_28, RST_30
PUBLIC  INT_INT0, INT_NMI

DEFC    Z180_TRAP   =       INIT            ; Initialise, should never get here
DEFC    RST_08      =       TXA             ; TX a character over ACIA
DEFC    RST_10      =       RXA             ; RX a character over ACIA, loop byte available
DEFC    RST_18      =       RXA_CHK         ; Check ACIA status, return # bytes available
DEFC    RST_20      =       NULL_RET        ; RET
DEFC    RST_28      =       NULL_RET        ; RET
DEFC    RST_30      =       NULL_RET        ; RET
DEFC    INT_INT0    =       serialInt       ; ACIA interrupt
DEFC    INT_NMI     =       NULL_NMI        ; RETN

;==============================================================================

