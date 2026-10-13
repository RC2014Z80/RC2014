;
; Shell console. One module, linked by every product.
; The product BIOS publishes const_go, conin_go, and conout_go.
; _bios_conout already holds the character in L.
;

SECTION code_compiler

PUBLIC  _bios_const
PUBLIC  _bios_conin
PUBLIC  _bios_conout

EXTERN  const_go
EXTERN  conin_go
EXTERN  conout_go
EXTERN  _bios_iobyte

_bios_const:
    ld      a,(_bios_iobyte)        ;get bios iobyte from shell
    jp      const_go

_bios_conin:
    ld      a,(_bios_iobyte)        ;get bios iobyte from shell
    jp      conin_go

_bios_conout:
    ld      a,(_bios_iobyte)        ;get bios iobyte from shell
    jp      conout_go
