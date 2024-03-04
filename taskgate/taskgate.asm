[bits 16]
[org 0x7c00]
stack_ring0	equ	0x8000
stack_ring3	equ	0x8400
stack_task1	equ	stack_ring3 - 0x100
stack_task2	equ	stack_ring3 - 0x200
IOPLbits		equ	12
TIbit				equ	2
count3sec		equ	200					; note: vertical sync length is approx. 15 millisec. 15 millisec x 200 = 3000 millisec
RPL3				equ	3
TI 					equ (1 << TIbit)	; Table Indicator

jmp 0:boot                  ; CS = 0x0000 on start up

;
; Global Descriptor Table
;
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
		db  11110010b           ; present, privilege level 3 (least privilege), data, expand-up, writable
		dw  0                   ; (not used in 80286) D bit is cleaed then operand length and EA are assumed to be 16 bits long

gdt_tss0:										; TSS descriptor
		dw	tss_0_end - tss_0 - 1	; limit
		dw	tss_0								; base lower 16 bits
		db	0										; base upper 8 bits
		db	11100001b						; present, privilege level 3 (least privilege), system, available TSS
		dw	0										; (not used in 80286)

gdt_tss_dispatcher:					; TSS descriptor
		dw	tss_dispatcher_end - tss_dispatcher - 1	; limit
		dw	tss_dispatcher			; base lower 16 bits
		db	0										; base upper 8 bits
		db	11100001b						; present, privilege level 3 (least privilege), system, available TSS
		dw	0										; (not used in 80286)

gdt_tss_task1:							; TSS descriptor
		dw	tss_task1_end - tss_task1 - 1	; limit
		dw	tss_task1						; base lower 16 bits
		db	0										; base upper 8 bits
		db	11100001b						; present, privilege level 3 (least privilege), system, available TSS
		dw	0										; (not used in 80286)

gdt_tss_task2:							; TSS descriptor
		dw	tss_task2_end - tss_task2 - 1	; limit
		dw	tss_task2						; base lower 16 bits
		db	0										; base upper 8 bits
		db	11100001b						; present, privilege level 3 (least privilege), system, available TSS
		dw	0										; (not used in 80286)

gdt_ldtd_dispat:            ; system (LDT) descriptor
    dw  ldt_dispat_end - ldt_dispat -1  ; limit
    dw  ldt_dispat          ; base lower 16 bits
    db  0                   ; base upeer 8 bits
    db  11100010b           ; present privilege level 3 (least privilege), system segment, LDT descriptor
    dw  0

gdt_tg_dispat:							; task gate descriptor
		dw	0										; unused
		dw	dispatcher_tss			; TSS selector
		db	0										; unused
		db	11100101b						; present privilege level 3 (least privilege), system segment, gate descriptor
		dw	0

gdt_tg_task1:
		dw	0										; unused
		dw	task1_tss						; TSS selector
		db	0										; unused
		db	11100101b						; present privilege level 3 (least privilege), system segment, gate descriptor
		dw	0

gdt_tg_task2:
		dw	0										; unused
		dw	task2_tss						; TSS selector
		db	0										; unused
		db	11100101b						; present privilege level 3 (least privilege), system segment, gate descriptor
		dw	0
gdt_end:

gdt_descriptor:
		dw  gdt_end - gdt_start - 1 ; limit of the gdt
		dd  gdt_start           ; physical starting address of the gdt

code_seg_ring0	equ gdt_code_ring0 - gdt_start
data_seg_ring0	equ gdt_data_ring0 - gdt_start
code_seg_ring3	equ gdt_code_ring3 - gdt_start
data_seg_ring3	equ gdt_data_ring3 - gdt_start
vram_seg				equ gdt_vram - gdt_start
tg_dispat				equ gdt_tg_dispat - gdt_start
tg_task1				equ gdt_tg_task1 - gdt_start
tg_task2				equ gdt_tg_task2 - gdt_start

tss0						equ	gdt_tss0 - gdt_start
dispatcher_tss	equ gdt_tss_dispatcher - gdt_start
task1_tss				equ gdt_tss_task1 - gdt_start
task2_tss				equ gdt_tss_task2 - gdt_start

dispatcher_ldt	equ gdt_ldtd_dispat - gdt_start
ldt_vram_seg		equ	(ldt_vram - ldt_dispat) | TI	; it refers to the LDT, not the GDT

;
; Task State Segment
;
tss_0:
		dw	0									; previous TSS
		dw	stack_ring0				; sp for CPL 0
		dw	data_seg_ring0		; ss for CPL 0
		; everything below here is unused
		times	19	dw	0
tss_0_end:

tss_dispatcher:
		dw	0									; previous TSS
		dw	stack_ring0				; (never altered) sp for CPL 0
		dw	data_seg_ring0		; (never altered) ss for CPL 0
		times	4		dw	0				; (never altered, not used) sp for CPL 1, ss for CPL 1, sp for CPL 2, ss for CPL 2
		dw	dispatcher_ring3	; ip (entry point)
		dw	(3 << IOPLbits)		; flag: set I/O prililege level to 3
		times 4		dw	0				; ax, cx, dx, bx
		dw	stack_ring3				; initial sp
		times	3		dw	0				; bp, si, di
;		dw	vram_seg | RPL3		; es selector 
		dw	ldt_vram_seg			; es selector, which is located in the LDT (not in the GDT)
		dw	code_seg_ring3 | RPL3		; cs selector
		dw	data_seg_ring3 | RPL3		; ss selector
		dw	data_seg_ring3 | RPL3		; (unused) ds selector
		dw	dispatcher_ldt		; task ldt selector
tss_dispatcher_end:

tss_task1:
		dw	0									; previous TSS
		dw	stack_ring0				; (never altered) sp for CPL 0
		dw	data_seg_ring0		; (never altered) ss for CPL 0
		times	4		dw	0				; (never altered, not used) sp for CPL 1, ss for CPL 1, sp for CPL 2, ss for CPL 2
		dw	task1_ring3				; ip (entry point)
		times 5		dw	0				; flag, ax, cx, dx, bx
		dw	stack_task1				; initial sp
		times	3		dw	0				; bp, si, di
		dw	vram_seg | RPL3		; es selector 
		dw	code_seg_ring3 | RPL3		; cs selector
		dw	data_seg_ring3 | RPL3		; ss selector
		dw	data_seg_ring3 | RPL3		; (unused) ds selector
		dw	0									; (unused) task ldt selector
tss_task1_end:

tss_task2:
		dw	0									; previous TSS
		dw	stack_ring0				; (never altered) sp for CPL 0
		dw	data_seg_ring0		; (never altered) ss for CPL 0
		times	4		dw	0				; (never altered, not used) sp for CPL 1, ss for CPL 1, sp for CPL 2, ss for CPL 2
		dw	task2_ring3				; ip (entry point)
		times 5		dw	0				; flag, ax, cx, dx, bx
		dw	stack_task2				; initial sp
		times	3		dw	0				; bp, si, di
		dw	vram_seg | RPL3		; es selector 
		dw	code_seg_ring3 | RPL3		; cs selector
		dw	data_seg_ring3 | RPL3		; ss selector
		dw	data_seg_ring3 | RPL3		; (unused) ds selector
		dw	0									; (unused) task ldt selector
tss_task2_end:

;
; Local Descriptor Tables
;
ldt_dispat:
;
; Note: I tried to put the task gate(s) into the LDT in vain. I could not have shed light on this issue.
; The task gate(s) in the GDT works as I expected, though.
;
;ldt_tg_dispat:						; task gate descriptor
;		dw	0									; unused
;		dw	dispatcher_tss		; TSS selector
;		db	0									; unused
;		db	11100101b					; present privilege level 3 (least privilege), system segment, gate descriptor
;		dw	0
ldt_vram:
		dw  80 * 25 * 2 - 1   ; limit
		dw  0x8000            ; base lower 16 bits
		db  0x0b              ; base upper 8 bits
		db  11110010b         ; present, privilege level 3 (least privilege), data, expand-up, writable
		dw  0                 ; (not used in 80286) D bit is cleaed then operand length and EA are assumed to be 16 bits long
ldt_dispat_end:

boot:
		cli
		lgdt    [gdt_descriptor]

; codes for 80286         ; MSW register is a 16-bit register but only the lower 4 bits are used
		smsw ax               ; and it is a part of CR0 register in 80386 (or later).
		or ax, 1              ; set PE bit (bit 0)
		lmsw ax

; for 80386 and upwards     PG (Paging, bit 31) and ET (Extention Type, bit 4) are added to CR0.
;mov eax, cr0
;or  eax, 1
;mov cr0, eax
;
		jmp code_seg_ring0:start_pm_ring0

;[bits 32]  This directive should be removed. As the descriptors say, operands and effective address are 16 bits in size
textcolor1	equ 0x1b        ; BG color : blue, FG color : bright cyan, no blink
textcolor2	equ 0x14 + 0x00	; BG color : blue, FG color : red, no blink
textcolor3	equ 0x12 + 0x00	; BG color : blue, FG color : green, no blink

start_pm_ring0:							; now entered into the 16 bit-protected mode ring 0 from the real mode
		cli											; disable interrupt for least securiy as IDT is not set up yet

		mov ax, data_seg_ring0
		mov ss, ax							; I know the ED bit is not set but it does not have to be set for use in SS
		mov sp, stack_ring0

		mov ax, tss0						; only operable at prililege level 0
		ltr ax

; set up the stack frame iret expects
		push (data_seg_ring3) | RPL3	; data selector (ring 3 stack with bottom 2 bits set for ring 3)
		push stack_ring3							; sp (ring 3)
		pushf
		push (code_seg_ring3) | RPL3	; code selector (ring 3 code with bottom 2 bits set for ring 3)
		push start_pm_ring3
		iret													; make it get to ring 3

start_pm_ring3:
;		jmp (dispatcher_tss | RPL3):0
		jmp tg_dispat:0

;
; task dispatcher
;
dispatcher_ring3:
		xor di, di
		mov ah, textcolor1			; clear screen
		mov al, ' ' 
		mov cx, 80 * 25
		cld
rep stosw

		xor ax, ax
dispat_loop:
		push ax
		mov dl, al
		and dl, 1
		jnz next_task						; round robin dispatch
;		call task1_seg:0
		call tg_task1:0
		jmp skip
next_task:
;		call task2_seg:0
		call tg_task2:0
skip:
		call delay_3sec
		pop ax
		inc ax
		jmp dispat_loop

delay_3sec:
		mov cx, count3sec				; note: vertical sync length is approx. 15 millisec
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

;
; task 1
;
task1_ring3:
		cld
		mov di, 80 * 2
		mov ah, textcolor1
		mov al, ' ' 
		stosw
		stosw
		stosw
		xor di, di
		mov ah, textcolor2
		mov al, 0xdb						; ALT-2588 '𒖈'
		stosw
		stosw
		stosw
		iret
		jmp task1_ring3

;
; task 2
;
task2_ring3:
		cld
		xor di, di
		mov ah, textcolor1
		mov al, ' ' 
		stosw
		stosw
		stosw
		mov di, 80 * 2
		mov ah, textcolor3
		mov al, 0xdb						; ALT-2588 '𒖈' (CP437)
		stosw
		stosw
		stosw
		iret
		jmp task2_ring3

		times 510-($-$$)  db 0  ; fill bytes from current location to 510 with zero	
		dw 0xaa55               ; bootable sector marker
