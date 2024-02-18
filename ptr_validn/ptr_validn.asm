;[cpu 286]
;[cpu 386]
[bits 16]
[org 0x7c00]
stack_ring0	equ	0x8000
;stack				equ	0x8000
PEbit				equ 0
RPL3				equ 3


jmp 0:boot                  ; CS = 0x0000 on start up

gdt_start:
gdt_null:                   ; null descriptor (required)
		dq  0

gdt_code_ring0:							; code segment descriptor (0x000000 - 0x00ffff)
		dw  0xffff              ; limit
		dw  0                   ; base lower 16 bits
		db  0                   ; base upper 8 bits
		db  10011010b           ; present, privilege level 0 (highest privilege), code, non-conforming, readable
		dw  0                   ; (not used in 80286) D bit is cleaed then operand length and EA are assumed to be 16 bits long

gdt_data_ring0:							; data segment descriptor (0x000000 - 0x00ffff)
		dw  0xffff              ; limit
		dw  0                   ; base lower 16 bits
		db  0                   ; base upper 8 bits
		db  10010010b           ; present, privilege level 0 (highest privilege), data, expand-up, writable
		dw  0                   ; (not used in 80286) D bit is cleaed then operand length and EA are assumed to be 16 bits long

gdt_code_ring3:							; code segment descriptor (0x000000 - 0x00ffff)
		dw  0xffff              ; limit
		dw  0                   ; base lower 16 bits
		db  0                   ; base upper 8 bits
		db  11111010b           ; present, privilege level 3 (least privilege), code, non-conforming, readable
		dw  0                   ; (not used in 80286) D bit is cleaed then operand length and EA are assumed to be 16 bits long

gdt_data_ring3:							; data segment descriptor (0x000000 - 0x00ffff)
		dw  0xffff              ; limit
		dw  0                   ; base lower 16 bits
		db  0                   ; base upper 8 bits
		db  11110010b           ; present, privilege level 3 (least privilege), data, expand-up, writable
		dw  0                   ; (not used in 80286) D bit is cleaed then operand length and EA are assumed to be 16 bits long

gdt_vram:                   ; VGA text color video memory (0x0b8000-0x0b8fff)
		dw  80 * 25 * 2 - 1     ; limit
		dw  0x8000              ; base lower 16 bits
		db  0x0b                ; base upper 8 bits
		db  11110010b           ; present, privilege level 3 (least privilege), data, expand-up, writable
		dw  0                   ; (not used in 80286) D bit is cleaed then operand length and EA are assumed to be 16 bits long
gdt_end:

gdt_descriptor:
		dw  gdt_end - gdt_start - 1 ; limit of the gdt
		dd  gdt_start           ; physical starting address of the gdt

code_seg_ring0	equ gdt_code_ring0 - gdt_start
data_seg_ring0	equ gdt_data_ring0 - gdt_start
code_seg_ring3	equ gdt_code_ring3 - gdt_start
data_seg_ring3	equ gdt_data_ring3 - gdt_start
vram_seg				equ gdt_vram - gdt_start

boot:
		cli
		lgdt    [gdt_descriptor]

; codes for 80286           ; MSW register is a 16-bit register but only the lower 4 bits are used
		smsw ax                 ; and it is a part of CR0 register in 80386 (or later).
		or ax, (1 << PEbit)			; set PE bit (bit 0)
		lmsw ax

; for 80386 and upwards     note: PG (Paging, bit 31) and ET (Extention Type, bit 4) are added to CR0.
;mov eax, cr0
;or  eax, 1
;mov cr0, eax
;
		jmp code_seg_ring0:start_pm_ring0

;[bits 32]  This directive should be removed. As the descriptors say, operands and effective address are 16 bits in size
textcolor1	equ 0x1b        ; BG color : blue, FG color : bright cyan, no blink
textcolor2	equ 0x1e + 0x80	; BG color : blue, FG color : yellow, with blink

start_pm_ring0:							; now entered into the 16 bit-protected mode ring 0 from the real mode
		cli

		mov ax, data_seg_ring0
		mov ss, ax							; I know the ED bit is not set but it does not have to be set for use in SS
		mov sp, stack_ring0

		mov ax, vram_seg				; The DPL of vram_seg (3) is numerically greater than the current CPL (0)
		verw ax									; so it is fine
		jnz skip
		mov es, ax							; reload ES to make it point to video memory
		xor di, di
		mov ah, textcolor1			; clear screen
		mov al, ' ' 
		mov cx, 80 * 25
		cld
rep stosw

; set up the stack frame iret expects
		push (data_seg_ring3) | RPL3	; data selector (ring 3 stack with lower 2 bits (RPL) set for ring 3)
		push stack_ring3							; sp (ring 3)
		pushf
		push (code_seg_ring3) | RPL3	; code selector (ring 3 code with RPL set for ring 3)
		push start_pm_ring3
		iret										; make it get to ring 3

skip:
		jmp skip								; should not happen

start_pm_ring3:
		mov ax, vram_seg				; ax contains the selector value whose RPL field is zero (i.e. RPL = 0)
		push cs
		pop dx									; dx now contains the CS selector value whose lower 2 bits represent CPL
		arpl ax, dx							; RPL field of the vram_seg is increased to match CPL
		verw ax									; assure that vram_seg is reachable from the current priv. level and writable
		jnz loop								; if not reachable and/or writable, abort loading
		mov es, ax							; the selector (pointer) validation completed. The value can be safely loaded into the ES

		mov ax, data_seg_ring3	; the same as above
		push cs
		pop dx
		arpl ax, dx
		verr ax									; assure that vram_seg is reachable from the current priv. level and readable
		jnz loop
		mov ds, ax							; The value can be safely loaded into into DS

		xor di, di		
		mov ah, textcolor1
		lea si, print_msg				; print the message at the uppper left corner of the screen
print:
		lodsb
		cmp al, 0
		jz print_end
		stosw
		jmp print

print_end:
		push es
		pop ax
		and al, 3
		or al, '0'
		mov ah, textcolor2
		mov es:(16 * 2), ax			; row 0, column 16

loop:
		jmp loop

print_msg:
		db  "RPL adjusted to  .", 0

		dw	0
		dw	0
		dw	0
		dw	0
stack_ring3:

		times 510-($-$$)  db 0  ; fill bytes from current location to 510 with zero
		dw 0xaa55               ; bootable sector marker
