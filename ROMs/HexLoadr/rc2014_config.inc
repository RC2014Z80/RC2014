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
; DEFINES SECTION
;

DEFC    ROMSTOP         =   $1FFF       ; Top of ROM

DEFC    RAM_56_START    =   $2000       ; Bottom of 56k RAM
DEFC    RAM_48_START    =   $4000       ; Bottom of 48k RAM
DEFC    RAM_32_START    =   $8000       ; Bottom of 32k RAM

DEFC    RAMSTART        =   RAM_32_START

; Top of BASIC line input buffer (CURPOS WRKSPC+0ABH)
; so it is "free ram" when BASIC resets
; set BASIC Work space WRKSPC $8000, in RAM

DEFC    WRKSPC      =   RAMSTART+$0200  ; set BASIC Work space WRKSPC
                                        ; beyond the end of ACIA stuff

DEFC    TEMPSTACK   =   WRKSPC+$0A2     ; Top of BASIC line input buffer
                                        ; (CURPOS = WRKSPC+0ABH)
                                        ; so it is "free ram" when BASIC resets

;==============================================================================

