;[cpu 286]
;[cpu 386]
[bits 16]
[org 0x7c00]
stack_ring0	equ	0x8000
stack				equ	0x8000

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

gdt_vram:                   ; data segment descriptor (VGA text color video memory: 0x0b8000-0x0b8fff)
		dw  80 * 25 * 2 - 1     ; limit
		dw  0x8000              ; base lower 16 bits
		db  0x0b                ; base upper 8 bits
		db  10010010b           ; present, privilege level 0 (highest privilege), data, expand-up, writable
		dw  0                   ; (not used in 80286) D bit is cleaed then operand length and EA are assumed to be 16 bits long

gdt_tss:										; TSS descriptor
		dw	tss_end - tss  - 1	; limit
		dw	tss									; base lower 16 bits
		db	0										; base upper 8 bits
		db	10000001b						; present, privilege level 0 (highest privilege), system, available TSS
		dw	0										; (not used in 80286)
gdt_end:

idt_start:									; bare minimum IDT
trap_div0:									; divide error exception
		dw	print								; offset
		dw	gdt_code_ring0 - gdt_start	; destination selector
		db	0										; unused
		db	11100111b						; present, privilege level 3 (least privilege), system, trap gate
		dw	0										; (not used in 80286)

		times	31 dq 0
idt_end:

gdt_descriptor:
		dw  gdt_end - gdt_start - 1 ; limit of the gdt
		dd  gdt_start           ; physical starting address of the gdt

idt_descriptor:
		dw	idt_end - idt_start - 1	; limit of the idt
		dd	idt_start						; physical starting address of the idt

code_seg_ring0	equ gdt_code_ring0 - gdt_start
data_seg_ring0	equ gdt_data_ring0 - gdt_start
code_seg_ring3	equ gdt_code_ring3 - gdt_start
data_seg_ring3	equ gdt_data_ring3 - gdt_start
vram_seg				equ gdt_vram - gdt_start
tss_seg					equ	gdt_tss - gdt_start

; Interrupts also cause stack change. The new stack pointer value (for ring 0, in this program) is
; loaded from TSS and therefore, TSS is set up.
tss:
		dw	0					; previous TSS
		dw	stack_ring0				; sp for CPL 0
		dw	data_seg_ring0		; ss for CPL 0
		; everything below here is unused
		times	19	dw	0
tss_end:

boot:
		cli
		lgdt    [gdt_descriptor]
		lidt		[idt_descriptor]

; codes for 80286           ; MSW register is a 16-bit register but only the lower 4 bits are used
		smsw ax                 ; and it is a part of CR0 register in 80386 (or later).
		or ax, 1                ; set PE bit (bit 0)
		lmsw ax

; for 80386 and upwards     PG (Paging, bit 31) and ET (Extention Type, bit 4) are added to CR0.
;mov eax, cr0
;or  eax, 1
;mov cr0, eax
;
		jmp code_seg_ring0:start_pm_ring0

;[bits 32]  This directive should be removed. As the descriptors say, operands and effective address are 16 bits in size
textcolor1	equ 0x1b        ; BG color : blue, FG color : bright cyan, no blink
textcolor2	equ 0x1e + 0x80	; BG color : blue, FG color : yellow, with blink

start_pm_ring0:							; now entered into the 16 bit-protected mode ring 0 from the real mode
		cli											; To avoid unintended interrupts. It is note that exceptions cannot be masked. 

		mov ax, data_seg_ring0
		mov ss, ax							; I know the ED bit is not set but it does not have to be set for use in SS
		mov sp, stack_ring0
		mov ax, (tss_seg) | 0
		ltr ax

		mov ax, vram_seg
		mov es, ax							; reload ES to make it point to video memory
		xor di, di
		mov ah, textcolor1			; clear screen
		mov al, ' ' 
		mov cx, 80 * 25
		cld
rep stosw

; set up the stack frame iret expects
		push (data_seg_ring3) | 3	; data selector (ring 3 stack with bottom 2 bits set for ring 3)
		push stack_ring3					; sp (ring 3)
		pushf
		push (code_seg_ring3) | 3	; code selector (ring 3 code with bottom 2 bits set for ring 3)
		push start_pm_ring3
		iret											; make it get to ring 3

; sample exception handler, which just prints the message
print:
		mov ax, data_seg_ring0
		mov ds, ax								; reload DS
		mov ax, vram_seg
		mov es, ax								; reload ES to make it point to video memory
		lea si, err_msg						; print a greeting message
		mov ah, textcolor2
.loop:
		lodsb
		cmp al, 0
		jz print_end
		stosw
		jmp .loop

print_end:
		cmp di, (80 * 25) * 2 - 6 * 2
		jle	skip
		xor di, di
skip:
		iret

start_pm_ring3:
		xor di, di
.loop:
		xor dl, dl
		div dl									; try to divide AX by dl and divide error exception occurs because divisor is zero
		jmp .loop								; exceptions cannot be masked and entry via trap gate leaves the interrupt/exception
														; status unchanged.

err_msg:
		db  "DIV/0 ", 0

		dw	0
		dw	0
		dw	0
		dw	0
stack_ring3:

		times 510-($-$$)  db 0  ; fill bytes from current location to 510 with zero
		dw 0xaa55               ; bootable sector marker
