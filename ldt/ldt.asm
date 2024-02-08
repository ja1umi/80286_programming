;[cpu 286]
;[cpu 386]
[bits 16]
[org 0x7c00]

jmp 0:boot                  ; CS = 0x0000 on start up

;
; Local Descriptor Table
;
ldt_start:
ldt_vram:                   ; VGA text color video memory (0x0b8000-0x0b8fff)
    dw  80 * 25 * 2 - 1     ; limit
    dw  0x8000              ; base lower 16 bits
    db  0x0b                ; base upper 8 bits
    db  10010010b           ; present, privilege level 0 (highest privilege), data, expand-up, writable
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

use_ldt     equ 100b        ; TI (table indicator) = 1, privilege level = 0

vram_seg    equ (ldt_vram - ldt_start) | use_ldt    ; set TI bit to use LDT
code_seg    equ gdt_code - gdt_start
data_seg    equ gdt_data - gdt_start
ldt_seg     equ gdt_ldtd - gdt_start

boot:
    xor ax, ax
    mov ds, ax              ; DS = ES = SS = 0 and remember that CS = 0
    mov es, ax
    mov ss, ax
    mov bp, 0x8000
    mov sp, bp

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
    mov ax, data_seg
    mov ds, ax              ; reload DS
    mov ax, ldt_seg
    lldt ax
    mov ax, vram_seg
    mov es, ax              ; reload ES to make it point to video memory
    xor di, di
    mov ah, textcolor       ; clear screen
    mov al, ' ' 
    mov cx, 80 * 25
    cld
rep stosw

    xor di, di              ; print a greeting message at the uppper left corner of the screen
    lea si, hello_msg
print:
    lodsb
    cmp al, 0
    jz loop
    stosw
    jmp print

loop:
jmp loop

hello_msg:
    db  "Hello, Protected World!", 0

    times 510-($-$$)  db 0  ; fill bytes from current location to 510 with zero
    dw 0xaa55               ; bootable sector marker
