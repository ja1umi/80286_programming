;[cpu 286]
;[cpu 386]
[bits 16]
[org 0x7c00]
TIbit		equ	2								; table indicator bit	position
stack		equ	0x7fff

start:
jmp 0:boot                  ; CS = 0x0000 on start up

;
; Local Descriptor Table
;
ldt_start:
ldt_code:                   ; code segment descriptor (0x000000 - 0x00ffff)
		dw	ldt_code_end - ldt_code_start - 1	; limit
		dw	ldt_code_start			; base lower 16 bits
    db  0                   ; base upper 8 bits
    db  10011010b           ; present, privilege level 0 (highest privilege), code, non-conforming, readable
    dw  0                   ; (not used in 80286) D bit is cleaed then operand length and EA are assumed to be 16 bits long

ldt_data:                   ; data segment descriptor
    dw  ldt_data_end - ldt_data_start - 1	; limit
    dw  ldt_data_start			; base lower 16 bits
    db  0                   ; base upper 8 bits
    db  10010000b           ; present, privilege level 0 (highest privilege), data, expand-up, read-only
    dw  0                   ; (not used in 80286) D bit is cleaed then operand length and EA are assumed to be 16 bits long
ldt_end:

;
; Global Descriptor Table
;
gdt_start:
gdt_null:                   ; null descriptor (required)
    dq  0

gdt_code:                   ; code segment descriptor (0x000000 - 0x00ffff)
    dw  0xffff              ; limit
    dw  0                   ; base lower 16 bits
    db  0                   ; base upper 8 bits
    db  10011010b           ; present, privilege level 0 (highest privilege), code, non-conforming, readable
    dw  0                   ; (not used in 80286) D bit is cleaed then operand length and EA are assumed to be 16 bits long

gdt_data:                   ; data segment descriptor (0x000000 - 0x00ffff)
    dw  0xffff              ; limit
    dw  0                   ; base lower 16 bits
    db  0                   ; base upper 8 bits
    db  10010010b           ; present, privilege level 0 (highest privilege), data, expand-up, writable
    dw  0                   ; (not used in 80286) D bit is cleaed then operand length and EA are assumed to be 16 bits long

gdt_vram:                   ; VGA text color video memory (0x0b8000-0x0b8fff)
    dw  80 * 25 * 2 - 1     ; limit
    dw  0x8000              ; base lower 16 bits
    db  0x0b                ; base upper 8 bits
    db  10010010b           ; present, privilege level 0 (highest privilege), data, expand-up, writable
    dw  0                   ; (not used in 80286) D bit is cleaed then operand length and EA are assumed to be 16 bits long

gdt_ldtd:                   ; system (LDT) descriptor
    dw  ldt_end - ldt_start -1  ; limit
    dw  ldt_start           ; base lower 16 bits
    db  0                   ; base upeer 8 bits
    db  10000010b           ; present privilege level 0 (highest privilege), system segment, LDT descriptor
    dw  0
gdt_end:

gdt_descriptor:
    dw  gdt_end - gdt_start - 1 ; limit of the gdt
    dd  gdt_start           ; physical starting address of the gdt

use_ldt     equ (1 << TIbit)	; set TI (table indicator) bit to 1 (privilege level 0)

code_seg_ldt	equ (ldt_code - ldt_start) | use_ldt		; set TI bit to use LDT	
data_seg_ldt	equ (ldt_data - ldt_start) | use_ldt    ; ditto
msg_out_ldt		equ msg_out - ldt_code_start
hello_msg_ldt	equ hello_msg - ldt_data_start
code_seg    	equ gdt_code - gdt_start
data_seg    	equ gdt_data - gdt_start
vram_seg			equ	gdt_vram - gdt_start
ldt_seg     	equ gdt_ldtd - gdt_start

boot:
    cli
    lgdt    [gdt_descriptor]

; codes for 80286           ; MSW register is a 16-bit register but only the lower 4 bits are used
    smsw ax                 ; and it is a part of CR0 register in 80386 (or later).
    or ax, 1                ; set PE bit (bit 0)
    lmsw ax

; for 80386 and upwards     PG (Paging, bit 31) and ET (Extention Type, bit 4) are added to CR0.
;mov eax, cr0
;or  eax, 1
;mov cr0, eax
;
    jmp code_seg:start_pm

;[bits 32]  This directive should be removed. As the descriptors say, operands and effective address are 16 bits in size
textcolor   equ 0x1b        ; blue on bright cyan, no blink

start_pm:                   ; now entered into the 16 bit-protected mode from the real mode
		cli											; To avoid unintended interrupts. It is note that software intrrupt is not maskable. 
		mov ax, data_seg
		mov ss, ax							; I know the ED bit is not set but it does not have to be set for use in SS
		mov sp, stack
    mov ax, vram_seg
    mov es, ax              ; reload ES to make it point to video memory

    xor di, di
    mov ah, textcolor       ; clear screen
    mov al, ' ' 
    mov cx, 80 * 25
    cld
rep stosw

    mov ax, ldt_seg
    lldt ax
    mov ax, data_seg_ldt		; string literal is stored on the LDT
    mov ds, ax              ; reload DS
		call code_seg_ldt:msg_out_ldt	; "local" procedure call
.loop:
		jmp .loop

;
; local procedure definition starts here
;
ldt_code_start:
msg_out:
    xor di, di              ; print the greeting message at the uppper left corner of the screen
		mov si, hello_msg_ldt
		mov ah, textcolor
.print:
    lodsb
    cmp al, 0
    jz .skip
    stosw
    jmp .print
.skip:
		retf
ldt_code_end:

;
; local string literal starts here
;
ldt_data_start:
hello_msg:
    db  "Hello, Local Descriptor Table!", 0
ldt_data_end:

    times 510-($-$$)  db 0  ; fill bytes from current location to 510 with zero
    dw 0xaa55               ; bootable sector marker
