
IF (__crt_org_code = 0)

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
EXTERN _cpm_bios_bss_initialised_tail

EXTERN _cpm_bios_canary     ; if it matches $AA55, BIOS has been loaded, and is likely whole

SECTION code_crt_init

PUBLIC _code_preamble_head
_code_preamble_head:

PUBLIC pboot

    ; set up COMMON_AREA CCP/BDOS

pboot:                      ; preamble code also used by wboot
    ld hl,_rodata_cpm_ccp_head
    ld de,_cpm_ccp_head
    ld bc,_cpm_bdos_data_tail-_cpm_ccp_head-1

loop_copy_ccp:
    ld a,(hl+)
    ld (de+),a
    dec bc
    jp NK,loop_copy_ccp

    xor a
    ld hl,_cpm_bdos_bss_head
    ld bc,_cpm_bdos_bss_tail-_cpm_bdos_bss_head-1

loop_set_bdos:
    ld (hl+),a
    dec bc
    jp NK,loop_set_bdos

    ld hl,_cpm_bios_canary  ; check that the CP/M BIOS is active
    ld a,(hl)               ; grab first byte $AA
    rrca                    ; rotate it to $55
    inc hl                  ; point to second byte $55
    xor (hl)                ; if correct, zero result
    call Z,qboot            ; so continue to reboot CP/M as normal
                            ; but ret if there is no disk configured

    ; set up COMMON_AREA BIOS

    ld hl,_rodata_cpm_bios_head
    ld de,_cpm_bios_head
    ld bc,_cpm_bios_rodata_tail-_cpm_bios_head-1

loop_copy_bios:
    ld a,(hl+)
    ld (de+),a
    dec bc
    jp NK,loop_copy_bios

    xor a
    ld hl,_cpm_bios_bss_head
    ld bc,_cpm_bios_bss_initialised_tail-_cpm_bios_bss_head-1

loop_set_bios:
    ld (hl+),a
    dec bc
    jp NK,loop_set_bios

    ; now fall through to normal _main() function and get set up for CP/M

ENDIF

