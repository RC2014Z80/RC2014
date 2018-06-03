
IF (__crt_org_code = 0)

EXTERN _acia0_init
EXTERN qboot

EXTERN _rodata_cpm_ccp_head
EXTERN _cpm_ccp_head
EXTERN _cpm_bdos_data_tail
EXTERN _cpm_bdos_bss_head
EXTERN _cpm_bdos_bss_tail

EXTERN _rodata_cpm_bios_head
EXTERN _cpm_bios_head
EXTERN _cpm_bios_rodata_tail
EXTERN _cpm_bios_bss_head
EXTERN _cpm_bios_bss_tail

EXTERN _cpm_bios_canary     ; if it matches $AA55, BIOS has been loaded, and is likely whole

SECTION code_crt_init

PUBLIC _code_preamble_head
_code_preamble_head:

PUBLIC pboot

    ; set up COMMON_AREA CCP/BDOS

pboot:                      ; preamble code also used by wboot
    ld hl,_rodata_cpm_ccp_head
    ld de,_cpm_ccp_head
    ld bc,_cpm_bdos_data_tail-_cpm_ccp_head
    ldir

    xor a
    ld hl,_cpm_bdos_bss_head
    ld (hl),a
    ld d,h
    ld e,l
    inc de
    ld bc,_cpm_bdos_bss_tail-_cpm_bdos_bss_head-1
    ldir

    ld hl,_cpm_bios_canary  ; check that the CP/M BIOS is active
    ld a, (hl)              ; grab first byte $AA
    rrca                    ; rotate it to $55
    inc hl                  ; point to second byte $55
    xor (hl)                ; if correct, zero result
    call Z, qboot           ; so continue to reboot CP/M as normal
                            ; but ret if there is no disk configured

    ; set up COMMON_AREA BIOS

    ld hl,_rodata_cpm_bios_head
    ld de,_cpm_bios_head
    ld bc,_cpm_bios_rodata_tail-_cpm_bios_head
    ldir

    xor a
    ld hl,_cpm_bios_bss_head
    ld (hl),a
    ld d,h
    ld e,l
    inc de
    ld bc,_cpm_bios_bss_tail-_cpm_bios_bss_head-1
    ldir

    ; now fall through to normal _main() function and get set up for CP/M

ENDIF

