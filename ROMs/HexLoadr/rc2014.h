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
; ACIA 68B50 interrupt driven serial I/O to run modified NASCOM Basic 4.7.
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

INCLUDE "rc2014_config.h"

;==============================================================================
;
; DEFINES SECTION
;

DEFC    ROMSTART        =   $0000   ; Bottom of ROM

DEFC    RAMSTOP         =   $FFFF   ; Top of RAM

DEFC    SER_RX_BUFSIZE  =   $100    ; FIXED Rx buffer size, 256 Bytes, no range checking
DEFC    SER_RX_FULLSIZE =   SER_RX_BUFSIZE - $08
                                    ; Fullness of the Rx Buffer, when not_RTS is signalled
DEFC    SER_RX_EMPTYSIZE =  $08     ; Fullness of the Rx Buffer, when RTS is signalled

DEFC    SER_TX_BUFSIZE  =   $10     ; Size of the Tx Buffer, 2^n Bytes, n = 4 here

;==============================================================================
;
; Interrupt vectors (offsets) for Z80 RST, INT0, and NMI interrupts
;

DEFC    Z80_VECTOR_BASE =   RAMSTART   ; RAM vector address for Z80 RST Table

; Squeezed between INT0 0x0038 and NMI 0x0066

DEFC    Z80_VECTOR_PROTO    =   $003C
DEFC    Z80_VECTOR_SIZE     =   $24

;   Prototype Interrupt Service Routines - complete in main program
;
;DEFC       Z180_TRAP       =    Z180_INIT   Reboot
;DEFC       RST_08          =    TX0         TX a character over ASCI0
;DEFC       RST_10          =    RX0         RX a character over ASCI0, block no bytes available
;DEFC       RST_18          =    RX0_CHK     Check ASCI0 status, return # bytes available
;DEFC       RST_20          =    NULL_INT
;DEFC       RST_28          =    NULL_INT
;DEFC       RST_30          =    NULL_INT
;DEFC       INT_INT0        =    NULL_INT
;DEFC       INT_NMI         =    NULL_NMI

;   Z80 Interrupt Service Routine Addresses - rewrite as needed

DEFC    Z180_TRAP_ADDR      =   Z80_VECTOR_BASE+$01
DEFC    RST_08_ADDR         =   Z80_VECTOR_BASE+$05
DEFC    RST_10_ADDR         =   Z80_VECTOR_BASE+$09
DEFC    RST_18_ADDR         =   Z80_VECTOR_BASE+$0D
DEFC    RST_20_ADDR         =   Z80_VECTOR_BASE+$11
DEFC    RST_28_ADDR         =   Z80_VECTOR_BASE+$15
DEFC    RST_30_ADDR         =   Z80_VECTOR_BASE+$19
DEFC    INT_INT0_ADDR       =   Z80_VECTOR_BASE+$1D
DEFC    INT_NMI_ADDR        =   Z80_VECTOR_BASE+$21

;==============================================================================
;
; Some definitions used with the RC2014 on-board peripherals:
;

; ACIA 68B50 Register Mnemonics

DEFC    SER_CTRL_ADDR   =   $80    ; Address of Control Register (write only)
DEFC    SER_STATUS_ADDR =   $80    ; Address of Status Register (read only)
DEFC    SER_DATA_ADDR   =   $81    ; Address of Data Register

DEFC    SER_RESET       =   $03    ; Master Reset (issue before any other Control word)
DEFC    SER_CLK_DIV_64  =   $02    ; Divide the Clock by 64 (default value)
DEFC    SER_CLK_DIV_16  =   $01    ; Divide the Clock by 16
DEFC    SER_CLK_DIV_01  =   $00    ; Divide the Clock by 1

DEFC    SER_8O1         =   $1C    ; 8 Bits  Odd Parity 1 Stop Bit
DEFC    SER_8E1         =   $18    ; 8 Bits Even Parity 1 Stop Bit
DEFC    SER_8N1         =   $14    ; 8 Bits   No Parity 1 Stop Bit
DEFC    SER_8N2         =   $10    ; 8 Bits   No Parity 2 Stop Bits
DEFC    SER_7O1         =   $0C    ; 7 Bits  Odd Parity 1 Stop Bit
DEFC    SER_7E1         =   $08    ; 7 Bits Even Parity 1 Stop Bit
DEFC    SER_7O2         =   $04    ; 7 Bits  Odd Parity 2 Stop Bits
DEFC    SER_7E2         =   $00    ; 7 Bits Even Parity 2 Stop Bits

DEFC    SER_TDI_BRK     =   $60    ; _RTS low,  Transmitting Interrupt Disabled, BRK on Tx
DEFC    SER_TDI_RTS1    =   $40    ; _RTS high, Transmitting Interrupt Disabled
DEFC    SER_TEI_RTS0    =   $20    ; _RTS low,  Transmitting Interrupt Enabled
DEFC    SER_TDI_RTS0    =   $00    ; _RTS low,  Transmitting Interrupt Disabled

DEFC    SER_TEI_MASK    =   $60    ; Mask for the Tx Interrupt & RTS bits   

DEFC    SER_REI         =   $80    ; Receive Interrupt Enabled

DEFC    SER_IRQ         =   $80    ; IRQ (Either Transmitted or Received Byte)
DEFC    SER_PE          =   $40    ; Parity Error (Received Byte)
DEFC    SER_OVRN        =   $20    ; Overrun (Received Byte
DEFC    SER_FE          =   $10    ; Framing Error (Received Byte)
DEFC    SER_CTS         =   $08    ; Clear To Send
DEFC    SER_DCD         =   $04    ; Data Carrier Detect
DEFC    SER_TDRE        =   $02    ; Transmit Data Register Empty
DEFC    SER_RDRF        =   $01    ; Receive Data Register Full

; General TTY

DEFC    CTRLC           =    03H     ; Control "C"
DEFC    CTRLG           =    07H     ; Control "G"
DEFC    BKSP            =    08H     ; Back space
DEFC    LF              =    0AH     ; Line feed
DEFC    CS              =    0CH     ; Clear screen
DEFC    CR              =    0DH     ; Carriage return
DEFC    CTRLO           =    0FH     ; Control "O"
DEFC    CTRLQ	        =	 11H     ; Control "Q"
DEFC    CTRLR           =    12H     ; Control "R"
DEFC    CTRLS           =    13H     ; Control "S"
DEFC    CTRLU           =    15H     ; Control "U"
DEFC    ESC             =    1BH     ; Escape
DEFC    DEL             =    7FH     ; Delete

;==============================================================================
;
; VARIABLES
;

DEFC    serRxInPtr      =     Z80_VECTOR_BASE+Z80_VECTOR_SIZE
DEFC    serRxOutPtr     =     serRxInPtr+2
DEFC    serTxInPtr      =     serRxOutPtr+2
DEFC    serTxOutPtr     =     serTxInPtr+2
DEFC    serRxBufUsed    =     serTxOutPtr+2
DEFC    serTxBufUsed    =     serRxBufUsed+1
DEFC    serControl      =     serTxBufUsed+1

DEFC    basicStarted    =     serControl+1

; I/O Buffers must start on 0xnn00 because we increment low byte to roll-over
DEFC    BUFSTART_IO     =     Z80_VECTOR_BASE-(Z80_VECTOR_BASE%$100) + $100

DEFC    serRxBuf        =     BUFSTART_IO
DEFC    serTxBuf        =     serRxBuf+SER_RX_BUFSIZE

;==============================================================================

