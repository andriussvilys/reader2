.model small
.stack 100h

.data
    buffer		db 100, "*", 100 dup ("*")

    _key     db  ?        ; "?" means un-initialized value
    _inputCounter dw 0h    ;use dw for integer value
    _cycleCounter dw 0h    ;use dw for integer value
    _maxInput dw 4h
    
    newLine db 0Ah, 0Dh, "$"
    pranesimas db 'Ivesk chara', 0Ah, 0Dh, "$"
    printCycle_alert db 'Print buffer in cycle', 0Ah, 0Dh, "$"
    get_input_alert db 'Get input:', 0Ah, 0Dh, "$"
    print_buffer_alert db 'Print buffer', 0Ah, 0Dh, "$"


.code

start:

    mov ax, @data
    mov ds, ax

    mov ah, 09
    mov dx, offset pranesimas
    int 21h

printCounter:

    mov bx, _inputCounter       ;put inputCounter to b register
    cmp bx, _maxInput              ;compare inputCounter with maxInput
    jz printBuffer              ;print outBuffer if maxInput reached

    jmp getInput

getInput:

    mov ah, 09
    mov dx, offset get_input_alert
    int 21h

    MOV ah, 08          ;08 - NO_ECHO_INPUT
    INT 21h

    mov di, _inputCounter
    lea bp, buffer[di]
    mov byte ptr [bp], al

    cmp di, _inputCounter

    ;mov ah, 02                  ;print input
    ;mov dl, byte ptr [bp]
    ;int 21h

    mov ah, 09                  ;print newLine
    mov dl, offset newLine
    int 21h

    inc _inputCounter           

    jmp printCounter

printBuffer:

    ;mov ah, 09
    ;mov dx, offset print_buffer_alert
    ;int 21h

    ;VEIKIANTIS KODAS
    ;mov ah, 02
    ;mov di, 0h
    ;lea bp, buffer[di]
    ;mov dx, [bp]
    ;int 21h

    ;mov di, 1h
    ;lea bp, buffer[di]
    ;mov dx, [bp]
    ;int 21h

cyclePrint:

    ;mov ah, 09
    ;mov dx, offset printCycle_alert
    ;int 21h

    mov di, _inputCounter
    mov si, _cycleCounter
    cmp di, si
    jz exit

    ;dec _inputCounter
    mov di, _inputCounter
    inc _cycleCounter
    lea bp, buffer[di]
    mov dx, [bp]

    mov ah, 02
    int 21h

    jmp cyclePrint



exit:
                    ; GO back to DOS 
    MOV AH, 04Ch	; Select exit function
    MOV AL, 00	    ; Return 0
    INT 21h		    ; Call the interrupt to exit'


end start