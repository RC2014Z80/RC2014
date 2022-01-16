;		UPLOAD.COM v0.3 for RC2014 with CP/M
;		This is very much based on 'Sample File Dump Utility'
;		from Digital Research CP/M Operating System Manual
;		http://www.gaby.de/cpm/manuals/archive/cpm22htm/
;		quote: "this manual is ... tutorial in nature. Thus, the reader is granted permission to include the example programs, either in whole or in part, in his own programs"
;
;		This file builds with zasm Z80 assembler, 
;		modification may be needed to compile using other assemblers
;
;		S Dixon, PeacockMedia
; 		https://peacockmedia.software



#target BIN
#code PAGE1,$100

BDOS    		equ  0005H		;DOS ENTRY POINT
CONS_IN			equ  1			;READ CONSOLE
CONS_OUT		equ  2			;TYPE FUNCTION
PRINT_STR		equ  9			;BUFFER PRINT ENTRY
CONS_STAT		equ  11			;(TRUE IF CHAR READY)
OPEN_FILE   	equ  15			;OPEN FILE
SEARCH_FIRST	equ  17		
SEARCH_NEXT		equ  18
READ_SEQ   		equ  20			;READ FUNCTION
USERNUM			equ	 32			;get user number

FCB     		equ  $5C		;SYSTEM FILE CONTROL BLOCK ADDRESS
BUFF    		equ  $80		;INPUT DISK BUFFER ADDRESS

CR      		equ  $0D		;CARRIAGE RETURN
LF      		equ  $0A		;LINE FEED
ESC				equ	 27			;ESCAPE

;   FILE CONTROL BLOCK DEFINITIONS

FCBDN		equ  FCB+0     ;DISK NAME
FCBFN		equ  FCB+1     ;FILE NAME
FCBFT		equ  FCB+9     ;DISK FILE TYPE (3 CHARACTERS)
FCBRL		equ  FCB+12    ;FILE'S CURRENT REEL NUMBER
FCBRC		equ  FCB+15    ;FILE'S RECORD COUNT (0 TO 128)
FCBCR		equ  FCB+32    ;CURRENT (NEXT) RECORD NUMBER (0 TO 127)
FCBLN		equ  FCB+33    ;FCB LENGTH

CPYFCBDN	equ  CPYFCB+0     ;DISK NAME
CPYFCBFN	equ  CPYFCB+1     ;FILE NAME
CPYFCBFT	equ  CPYFCB+9     ;DISK FILE TYPE (3 CHARACTERS)
CPYFCBRL	equ  CPYFCB+12    ;FILE'S CURRENT REEL NUMBER
CPYFCBRC	equ  CPYFCB+15    ;FILE'S RECORD COUNT (0 TO 128)
CPYFCBCR	equ  CPYFCB+32    ;CURRENT (NEXT) RECORD NUMBER (0 TO 127)
CPYFCBLN	equ  CPYFCB+33    ;FCB LENGTH






;   SET UP STACK
				ld hl,0000
				add hl,sp
				ld (OLDSP),hl 		;ENTRY STACK POINTER IN HL FROM THE CCP
				ld sp,STKTOP		;SET SP TO LOCAL STACK AREA (RESTORED AT FINIS)
				call CRLF			;READ AND PRINT SUCCESSIVE BUFFERS

; set up our copy FCBuffer here and set up multi file (outer) loop
				call COPYFCB
			
OUTERLP:					
				call GETNTHMATCH	;uses the copy CPYFCB we made. copy the result (if there is one) into default FCB
				cp $ff
				jp z,ERRGRACE		;graceful error handling

				call CPYMATCH		;into default buffer
				call SETUP     		;SET UP INPUT FILE
				cp  $ff       		;255 IF FILE NOT PRESENT

				jp nz,OPENOK    	;SKIP IF OPEN IS OK
			   
				jp  ERRGRACE     	;FILE NOT THERE, GIVE ERROR MESSAGE AND RETURN

;OPEN OPERATION OK, SET BUFFER INDEX TO END
OPENOK: 	
				ld a,$80
				ld (IBP),a			;SET BUFFER POINTER TO 80H
			                  		;HL CONTAINS NEXT ADDRESS TO PRINT

	  
				; here we go....		
				call CORE
				cp 0				;ok? returns non-zero if key pressed to break
				jr z, NOBRK		
			
				
BROKEN:
				call CRLF
				call CRLF
				ld de,BROKENMSG
				call ERR
				jp FINIS
				
				
; any more files?			
NOBRK:			call CRLF
				call CRLF
				ld hl,NTHFILE
				inc (hl)

				jp OUTERLP
				
			
				
				
			
ERRGRACE:
				ld a,(NTHFILE)
				cp $00
				jp nz,FINIS			; error on the matching file
				ld de,OPNMSG
				call ERR

FINIS:
;END, RETURN TO CCP
;(NOTE THAT A JMP TO 0000H REBOOTS)

				ld hl,(OLDSP) 
				ld sp,hl			;STACK POINTER CONTAINS CCP'S STACK LOCATION
				ret       			;TO THE CCP
				 
		
			
				
;
;
;   SUBROUTINES
;
;							  
							  
							  
							  
BREAK:
;CHECK ESCAPE KEY 
				push hl
				push de 
				push bc				; ENVIRONMENT SAVED
				ld  c,CONS_STAT
				call BDOS
				
				cp 0
				jr z,BRRET
				
; we have a key, which key?
				ld  C,CONS_IN
				CALL BDOS
				cp ESC
				jr z,BRRET
				; else
				ld a,0				; ignore the non-escape key
BRRET:		
				pop bc 
				pop de 
				pop hl				; ENVIRONMENT RESTORED
				ret

PCHAR:  
;PRINT A CHARACTER
				push hl
				push de 
				push bc				; ENVIRONMENT SAVED
				ld  C,CONS_OUT
				ld  E,A
				call BDOS
				pop bc 
				pop de 
				pop hl				; ENVIRONMENT RESTORED
				ret

CRLF:
				ld a,CR
				call PCHAR
				ld a,LF
				call PCHAR
				ret

PNIB:    
;PRINT NIBBLE IN REG A
				and $0f				;LOW 4 BITS
				cp 10
				jp nc,P10			;LESS THAN OR EQUAL TO 9
			             
				add a,$30			; '0'
				jp  PRN				;GREATER OR EQUAL TO 10
			                  
P10:			add a,$37  			; 'A'-10
PRN:			call PCHAR
				ret

PHEX:			
;PRINT HEX CHAR IN REG A
				push af
				rrca
				rrca
				rrca
				rrca
				call PNIB			;PRINT NIBBLE
				pop af
				call PNIB
				ret

ERR:
;PRINT ERROR MESSAGE
PRTSTR:
;PRINT STRING	;D,E ADDRESSES OF MESSAGE ENDING WITH "$"
				ld c,PRINT_STR 
				call BDOS
				ret

GNB:     
;GET NEXT BYTE
				ld a,(IBP)  
				cp $80
				jp nz,G0			;READ ANOTHER BUFFER

				call DISKR
				or a         		;ZERO VALUE IF READ OK
				jp z,G0        		;FOR ANOTHER BYTE
				              		;END OF DATA, RETURN WITH CARRY SET FOR EOF
				scf
				ret

G0:      
;READ THE BYTE AT BUFF+REG A
                 ld e,a				;LS BYTE OF BUFFER INDEX
                 ld d,0				;DOUBLE PRECISION INDEX TO DE
                 inc a				;INDEX=INDEX+1
                 ld (IBP),a         ;BACK TO MEMORY
				 					;POINTER IS INCREMENTED
									;SAVE THE CURRENT FILE ADDRESS
				 ld hl,BUFF
                 add hl,de			;ABSOLUTE CHARACTER ADDRESS IS IN HL
                 ld a,(hl)
			                  		;BYTE IS IN THE ACCUMULATOR
                 or a         		;RESET CARRY BIT
                 ret

SETUP:   
;SET UP FILE
;OPEN THE FILE FOR INPUT
				xor a         		;ZERO TO ACCUM
				ld (FCBCR),a		;CLEAR CURRENT RECORD
				ld de,FCB
				ld  C,OPEN_FILE
				call BDOS			;255 IN ACCUM IF OPEN ERROR        		
				ret

DISKR:   
;READ DISK FILE RECORD
				push hl
				push de 
				push bc				; ENVIRONMENT SAVED
				ld de,FCB
				ld c,READ_SEQ
				call BDOS
				pop bc 
				pop de 
				pop hl				; ENVIRONMENT RESTORED
				ret

						  
PRTFN:
; Print filename							
				ld hl,FCBFN			; file name
				ld b,8
PFNLP3:			ld a,(hl)
				cp ' '
				jr z,PFNSKC3
				call PCHAR
PFNSKC3:		inc hl
				djnz PFNLP3
				
				ld a,'.'			; separator
				call PCHAR
				
				ld hl,FCBFT			; file type	
				ld b,3
PFNLP4:			ld a,(hl)
				cp ' '
				jr z,PFNSKC4
				call PCHAR
PFNSKC4			inc hl
				djnz PFNLP4					

				ret
			
				
				
GETUSERNUM: 	 
				push hl
				push de 
				push bc				; ENVIRONMENT SAVED
				ld c,USERNUM
				ld e,$ff			; indicate get
				call BDOS
				 
				add $30				; ascii 0
				 
				pop bc 
				pop de 
				pop hl				; ENVIRONMENT RESTORED
				ret

		
COPYFCB:		
; make a copy of the user's query, which may contain * or ?
; if there are multiple matches, we'll return to our copy 
; and put the results in the default FCB
				ld hl,FCB		
				ld de,CPYFCB
				ld b,36
CFBLP:			ld a,(hl)
				ld (de),a
				inc hl
				inc de
				djnz CFBLP	
				ret
		
		
GETNTHMATCH:
; returns ff in a if can't make nth match.
; otherwise returns a=0-3, pointing to place in buf
; doesn't change nth file
; doesn't preserve registers
			   
; Entered with C=11h, DE=address of FCB. Returns error codes in BA and HL.
				ld c,SEARCH_FIRST
				ld de,CPYFCB
 			   
				call BDOS 			; Returns A=0FFh if error  or A=0-3 if successful.
				
				cp $ff
				ret z
			   	
				ld b,a
				ld a,(NTHFILE)
				cp 0
				ld a,b
				ret z
				
				ld a,(NTHFILE)
				ld b,a
SNEXTLP:				
; Entered with C=12h, (DE=address of FCB)?. Returns error codes in BA and HL.
				push bc
				ld c,SEARCH_NEXT
				ld de,CPYFCB
 			   
				call BDOS			; Returns A=0FFh if error  or A=0-3 if successful.
				pop bc
				
				cp $ff
				ret z
				
				djnz SNEXTLP
				ret
				

CPYMATCH:		
; A*32
; add to BUF
; copy 8 chars to FCBFN
; copy 3 chars to FCBFT
; blank  FCBRL &  FCBRC   
		
				sla A
				sla A
				sla A
				sla A
				sla A
				
				ld c,a
				ld b,0
				ld hl,BUFF
				add hl,bc
				ld de,FCBFN
				
				ld b,11
				inc hl 				; think the first byte is the drive
CPMFNLP:				
				ld a,(hl)
				ld (de),a
		
				inc hl
				inc de
		
				djnz CPMFNLP
				
				ld a,0
				ld(FCBRL),a
				ld(FCBRC),a
				
				ret
		
		
		
			
;
;
;   Core functionality. One file is set up
;
;				
			
			
			
CORE:

							  
							  
HEAD:			ld de,ADOWNLOAD							  
				call PRTSTR
				; print filename
				call PRTFN
				call CRLF
				
				ld a,'U'
				call PCHAR
				call GETUSERNUM
				call PCHAR
				call CRLF
				
				
				ld a,':'
				call PCHAR

				ld hl,0				;START WITH 0000
				ld c,0				; our checksum
						  
GLOOP:
				push HL				;SAVE LINE POSITION
            	call GNB			;GET NEXT BYTE
                pop  HL				;RECALL LINE POSITION
				jp c,FOOTER			;CARRY SET BY GNB IF END FILE
                ld b,a

			                  
            	CALL BREAK			;CHECK FOR BREAK KEY
			    cp 0          		;non-zero value if so
				ret nz
				

NONUM:
                 inc hl        		;TO NEXT LINE NUMBER
                 ld a,b
				 call PHEX
				 ld a,b
				 add c 
				 ld c,a				; add to checksum
				 
	             jp  GLOOP

FOOTER:
				ld a,'>'
				call PCHAR
				ld a,l				; hl is our character counter. l will be the low byte
				call PHEX
				ld a,c				; hl is our checksum. 8 bit
				call PHEX
				call CRLF
				
				ld a,0				; A-OK
				ret			
			
			
			
			
;
;
;        FIXED MESSAGE AREA					  
;
;
							  
; SIGNON:  dm   "UPLOAD.COM VERSION 0.3$"
OPNMSG:			dm	CR,LF,"Can't find input file$"
BROKENMSG:		dm	"Break key pressed$"
ADOWNLOAD:		dm	"A:DOWNLOAD $"



;
;
;        VARIABLE AREA
;
;

CPYFCB:			ds 36				; OUR COPY OF THE ORIGINAL QUERY
NTHFILE:		defb 00				; keeping track of which filename match we're currently on

IBP:			ds   2				;INPUT BUFFER POINTER
OLDSP:			ds   2				;ENTRY SP VALUE FROM CCP

;
;
;        STACK AREA
;
;
				ds   32				;RESERVE 16 LEVEL STACK
STKTOP:

