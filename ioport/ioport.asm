;[cpu 286]
;[cpu 386]
[bits 16]
[org 0x7c00]
stack_ring0	equ	0x8000
stack				equ	0x8000
IOPLbits		equ 12
; the 8254 (programmable timer) operates at 1.19318 MHz
count440hz		equ (1193180 / 440)	; timer divisor to give me 440 Hz tone

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
		cli											; To avoid unintended interrupts. It is note that software intrrupt is not maskable. 

		mov ax, data_seg_ring0
		mov ss, ax							; I know the ED bit is not set but it does not have to be set for use in SS
		mov sp, stack_ring0
		pushf
		pop ax
		or ax, (3 << IOPLbits)	; set I/O prililege level to 3
		push ax
		popf

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

start_pm_ring3:
		mov al, 0xb6							; 0x43: 8254 mode register
		out 0x43, al							; select timer #2, Lo -> Hi order, square wave generation
		mov al, (count440hz & 0xff)	; 0x42: timer #2
		out 0x42, al							; write low byte first
		mov al, ((count440hz >> 8) & 0xff)
		out 0x42, al							; and then write high byte
.loop:
		call beep_on_ring3
		call delay_ring3
		call beep_off_ring3
		call delay_ring3
		jmp .loop

beep_on_ring3:
		in al, 0x61							; 0x61: system port
		or al, 3								; b1 speaker output enable (0: disable, 1: enable)
		out 0x61, al						; b0 timter Ch.2 output enable (0: disable, 1: enable)
		retn

beep_off_ring3:
		in al, 0x61
		and al, 0xfc
		out 0x61, al
		retn

delay_ring3:
		mov cx, 35							; vertical sync length is approx. 15 msec, 15 x 35 = 500 msec
delay_loop:
		mov dx, 0x3da						; 0x3da: vga status register
vset:
		in al, dx
		and al, 8								; b3: vertical retrace bit
		jnz vset								; wait for it to be clear
vclr:
		in al, dx
		and al, 8
		jz vclr									; wait for the retrace bit to be newly set
		loop delay_loop
		retn


		dw	0
		dw	0
		dw	0
		dw	0
stack_ring3:

		times 510-($-$$)  db 0  ; fill bytes from current location to 510 with zero
		dw 0xaa55               ; bootable sector marker
