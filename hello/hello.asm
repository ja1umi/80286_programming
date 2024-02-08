org 0H
bits 16

    JMP 0x07C0:start ; far jmp, update CS to 0x07C0

videoseg equ 0xB800
cols equ 80
rows equ 25
;
; VGA text mode
;
;     Attribute    Character 
; ==========================
; 7 6 5 4 3 2 1 0    7 .. 0
; L r g b i r g b
;   ~~~~~ ~~~~~~~~
;     bg     fg
;
; L: Blink (0 = no blink), i: foreground intensity
; r: Red, g: Green, b: Blue
;
bgcolor equ 01110000B ; no blink, bg = light gray, fg = black
bgtext equ 0x20 ; space char

start:
    ; copy CS(0x07C0) to DS, ES
    MOV AX, CS
    MOV DS, AX

    MOV AX, videoseg
    MOV ES, AX
    MOV DI, 0

    ; clear background color and texts
    MOV AL, bgtext
    MOV AH, bgcolor

    mov cx, cols * rows
    cld
rep stosw
;    ; for (i = 0; i < rows; i++) {
;    MOV CX, rows
;.bg_fill_rows:
;    PUSH CX
;    ;     for (j = 0; j < cols; j++) {
;    MOV CX, cols
;.bg_fill_cols:
;    MOV [ES:DI], AX
;    ADD DI, 2
;    LOOP .bg_fill_cols
;    ;     }
;    POP CX
;    LOOP .bg_fill_rows
;    ; }

;    XOR AX, AX
    XOR DI, DI
;    MOV SI, hellomsg
    lea si, hellomsg
    mov ah, bgcolor
.print:
    lodsb
    cmp al, 0
    jz .print_end
    stosw
    jmp .print
;    MOV BYTE AL, [DS:SI]
;    CMP AX, 0
;    JZ .print_end
;    MOV BYTE [ES:DI], AL
;    INC SI
;    ADD DI, 2
;    JMP .print
.print_end:

    JMP $


hellomsg: db "Hello, World!", 0

times 510-($-$$) db 0
    dw 0xAA55