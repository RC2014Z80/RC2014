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
;==================================================================================
;
; ACIA 68B50 interrupt driven serial I/O to run modified NASCOM Basic 4.7.
; Full input and output buffering with incoming data hardware handshaking.
; Handshake shows full before the buffer is totally filled to
; allow run-on from the sender. Transmit and receive are interrupt driven.
;
; https://github.com/feilipu/
; https://feilipu.me/
;
;==================================================================================
;
; HexLoadr option by @feilipu,
; derived from the work of @fbergama and @foxweb at RC2014
; https://github.com/RC2014Z80
;

;==============================================================================
;
; DEFINES SECTION
;

ROMSTART        .EQU    $0000   ; Bottom of ROM
ROMSTOP         .EQU    $1FFF   ; Top of ROM

RAMSTOP         .EQU    $FFFF   ; Top of RAM

SER_RX_BUFSIZE  .EQU    $FF  ; FIXED Rx buffer size, 256 Bytes, no range checking
SER_RX_FULLSIZE .EQU    SER_RX_BUFSIZE - $08
                              ; Fullness of the Rx Buffer, when not_RTS is signalled
SER_RX_EMPTYSIZE .EQU   $08  ; Fullness of the Rx Buffer, when RTS is signalled

SER_TX_BUFSIZE  .EQU    $0F  ; Size of the Tx Buffer, 15 Bytes

;==============================================================================
;
; Interrupt vectors (offsets) for Z80 RST, INT0, and NMI interrupts
;

Z80_VECTOR_BASE .EQU    RAMSTART    ; RAM vector address for Z80 RST Table
                                    ; <<< SET THIS AS DESIRED >>>

; Squeezed between INT0 0x0038 and NMI 0x0066
Z80_VECTOR_PROTO    .EQU    $0040
Z80_VECTOR_SIZE     .EQU    $20

;   Prototype Interrupt Service Routines - complete in main program
;
;   RST_08          .EQU    TX0         TX a character over ASCI0
;   RST_10          .EQU    RX0         RX a character over ASCI0, block no bytes available
;   RST_18          .EQU    RX0_CHK     Check ASCI0 status, return # bytes available
;   RST_20          .EQU    NULL_INT
;   RST_28          .EQU    NULL_INT
;   RST_30          .EQU    NULL_INT
;   INT_00          .EQU    NULL_INT
;   INT_NMI         .EQU    NULL_NMI

;==============================================================================
;
; Some definitions used with the RC2014 on-board peripherals:
;

; ACIA 68B50 Register Mnemonics

SER_CTRL_ADDR   .EQU   $80    ; Address of Control Register (write only)
SER_STATUS_ADDR .EQU   $80    ; Address of Status Register (read only)
SER_DATA_ADDR   .EQU   $81    ; Address of Data Register

SER_RESET       .EQU   $03    ; Master Reset (issue before any other Control word)
SER_CLK_DIV_64  .EQU   $02    ; Divide the Clock by 64 (default value)
SER_CLK_DIV_16  .EQU   $01    ; Divide the Clock by 16
SER_CLK_DIV_01  .EQU   $00    ; Divide the Clock by 1

SER_8O1         .EQU   $1C    ; 8 Bits  Odd Parity 1 Stop Bit
SER_8E1         .EQU   $18    ; 8 Bits Even Parity 1 Stop Bit
SER_8N1         .EQU   $14    ; 8 Bits   No Parity 1 Stop Bit
SER_8N2         .EQU   $10    ; 8 Bits   No Parity 2 Stop Bits
SER_7O1         .EQU   $0C    ; 7 Bits  Odd Parity 1 Stop Bit
SER_7E1         .EQU   $08    ; 7 Bits Even Parity 1 Stop Bit
SER_7O2         .EQU   $04    ; 7 Bits  Odd Parity 2 Stop Bits
SER_7E2         .EQU   $00    ; 7 Bits Even Parity 2 Stop Bits

SER_TDI_BRK     .EQU   $60    ; _RTS low,  Transmitting Interrupt Disabled, BRK on Tx
SER_TDI_RTS1    .EQU   $40    ; _RTS high, Transmitting Interrupt Disabled
SER_TEI_RTS0    .EQU   $20    ; _RTS low,  Transmitting Interrupt Enabled
SER_TDI_RTS0    .EQU   $00    ; _RTS low,  Transmitting Interrupt Disabled

SER_TEI_MASK    .EQU   $60    ; Mask for the Tx Interrupt & RTS bits   

SER_REI         .EQU   $80    ; Receive Interrupt Enabled

SER_IRQ         .EQU   $80    ; IRQ (Either Transmitted or Received Byte)
SER_PE          .EQU   $40    ; Parity Error (Received Byte)
SER_OVRN        .EQU   $20    ; Overrun (Received Byte
SER_FE          .EQU   $10    ; Framing Error (Received Byte)
SER_CTS         .EQU   $08    ; Clear To Send
SER_DCD         .EQU   $04    ; Data Carrier Detect
SER_TDRE        .EQU   $02    ; Transmit Data Register Empty
SER_RDRF        .EQU   $01    ; Receive Data Register Full

; General TTY

CTRLC           .EQU    03H     ; Control "C"
CTRLG           .EQU    07H     ; Control "G"
BKSP            .EQU    08H     ; Back space
LF              .EQU    0AH     ; Line feed
CS              .EQU    0CH     ; Clear screen
CR              .EQU    0DH     ; Carriage return
CTRLO           .EQU    0FH     ; Control "O"
CTRLQ	        .EQU	11H     ; Control "Q"
CTRLR           .EQU    12H     ; Control "R"
CTRLS           .EQU    13H     ; Control "S"
CTRLU           .EQU    15H     ; Control "U"
ESC             .EQU    1BH     ; Escape
DEL             .EQU    7FH     ; Delete

;==============================================================================
;
; GLOBAL VARIABLES SECTION
;

serRxInPtr      .EQU     Z80_VECTOR_BASE+Z80_VECTOR_SIZE
serRxOutPtr     .EQU     serRxInPtr+2
serTxInPtr      .EQU     serRxOutPtr+2
serTxOutPtr     .EQU     serTxInPtr+2
serRxBufUsed    .EQU     serTxOutPtr+2
serTxBufUsed    .EQU     serRxBufUsed+1
serControl      .EQU     serTxBufUsed+1

basicStarted    .EQU     serControl+1

; I/O Buffers must start on 0xnn00 because we increment low byte to roll-over
BUFSTART_IO     .EQU    (Z80_VECTOR_BASE-(Z80_VECTOR_BASE%$100) + $100
  
serRxBuf        .EQU     BUFSTART_IO
serTxBuf        .EQU     serRxBuf+SER_RX_BUFSIZE+1

;==============================================================================
;
                .END
;
;==============================================================================


