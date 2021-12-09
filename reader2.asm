.model small
.stack 100h

.data
apie DB "this program opens a file and swaps two strings in the file", 13, 10, "open program with params:", 13, 10, "[source file] [string 1] [string 2]", 13, 10, "*use empty spaces to seprate params0", 13, 10,"*max param lenght: 20$"
stringSearchFail DB "Strings not found$"
fileOpenError DB "File OPEN error.$"
fileReadError DB "File READ error.$"
stringFound DB 13, 10, "string found.$"

buffer db 100 dup (?)
max_buffer_size DW 100          ;max value 2^16 && buffer >=
bufferCount dw 00h

currentString dw 0
stringStart dw 0
bufferPointer dw 0
absoluteFileOffset_MSW dw 0
absoluteFileOffset_LSW dw 0

firstCharMatched db 0            ;1 if matched first char of string; else 0

srcFileName db 100 dup (0)
srcFileHandle dw ?
file_ptr dw 0

str1 db 100 dup (0)
str1_start dw 0

str2 db 100 dup (0)
str2_start dw 0

max_param_size DW 14h

 
.code 

start:

mov ax, @data
mov es, ax            ;copy ds to es, es used for stosb

mov si, 81h           ;programos paleidimo parametru adresas

call skip_spaces

mov al, byte ptr ds:[si]    ;si now points to first non-space char in params
cmp al, 13
je help

mov ax, word ptr ds:[si]
cmp ax, 3F2Fh                  ;3F='?', 2F='/' 3F2F='/?'
je help

lea di, srcFileName         ;load srcFileName address to di
call save_param

lea di, str1
call save_param

lea di, str2
call save_param

mov ax, @data                ;load ds segment
mov ds, ax

call get_file_handle

call findString1

call endProgram

;------- READ PARAMS

skip_spaces PROC near

    skip_spaces_loop:
        cmp byte ptr ds:[si], ' '
        jne skip_spaces_end
        inc si
        jmp skip_spaces_loop

    skip_spaces_end:
        ret
    
    skip_spaces ENDP

help:
    mov ax, @data
    mov ds, ax

    mov dx, offset apie
    mov ah, 9
    int 21h
    call endProgram

save_param PROC near
    ;push ax
    call skip_spaces
    xor cx, cx              ;reset char counter

    save_param_loop:

        cmp byte ptr ds:[si], 13
        je save_param_end
        cmp byte ptr ds:[si], ' '
        jne save_param_next             ;if NOT /n and NOT ' ', save the char in ES:[di]

    save_param_end:
        cmp cx, 0            ;if empty param
        je help
        mov al, 0
        stosb                  ;store al content in es:di
        ;pop ax
        ret
    
    save_param_next:
        cmp cx, max_param_size  ;check that cx <= max_param_size
        je help
        lodsb                   ;load char from ds:si to al, then inc si
        stosb                   ;store char from al in es:di, then inc di
        inc cx
        jmp save_param_loop

        save_param ENDP

;------- END READ PARAMS

;------- HANDLE FILE

error_fileOpen:
    mov dx, offset fileOpenError
    mov ah, 09h
    int 21h
    call endProgram

error_fileRead:
    mov dx, offset fileReadError
    mov ah, 09h
    int 21h
    call endProgram

get_file_handle PROC near

    lea dx, srcFileName

    mov ah, 3Dh                     ;open file 
    mov al, 02h                     ;read/write attribute
    int 21h
    jc error_fileOpen
    mov srcFileHandle, ax

    ret

    get_file_handle ENDP

;read bytes from file to buffer
readToBuffer PROC near

    mov bx, srcFileHandle       ;bx - file handle
    xor cx, cx                      
    mov cx, max_buffer_size                 ;cx - buffer size
    lea dx, buffer              ;dx - pointer to read buffer
    xor ax, ax
    mov ah, 3Fh                 ;read from file
    int 21h

    jc error_fileRead

    ret
    readToBuffer ENDP


;si - buffer pointer, di - string pointer
;if [si] == [di], then move str_ptr
;else reload str_start
findString1 PROC near

    lea di, str1                ;DI - string pointer

    findStringLoop:
        call readToBuffer           ;reads bytes from file to buffer
        cmp ax, 0                   ;if 0 bytes are read and string still not found - fail
        je fail
        mov bufferPointer, 0h
        mov cx, ax                  ;move amount of bytes read to CX
        lea si, buffer	            ;SI - buffer pointer

    compareChars:
        lodsb                               ;load buffer char to AL from ds:[si]
        cmp al, byte ptr ds:[di]            ;AL - buffer char, [DI] - string char
        je checkIffirstCharMatcheded
        jmp reloadPointer

    fail:
        mov dx, offset stringSearchFail
        mov ah, 09h
        int 21h
        ret

    continue:
        inc bufferPointer
        loop compareChars                 ;if cx is 0 jmp to findStringLoop
        jmp finishLoop

    moveStringPointer:                    ;if buffer and str chars match
        inc di                            ;move string pointer forward
        cmp byte ptr ds:[di], 0h          ;if end of string using ASCIIZ format (0h marks ends of string)
        je success
        jmp continue

    reloadPointer:
        mov firstCharMatched, 0h
        lea di, str1                               ;di - string pointer
        jmp continue

    checkIffirstCharMatcheded:
        cmp firstCharMatched, 0h           ;if firstCharMatched == 1, then moveStringPointer
        jnz moveStringPointer

    setfirstCharMatched:
        mov firstCharMatched, 1h
        mov bx, bufferPointer
        mov stringStart, bx
        jmp moveStringPointer

    finishLoop:
        inc bufferCount
        jmp findStringLoop


    success:
        call calcOffsetInFile
        lea dx, stringFound
        mov ah, 09h
        int 21h
        ret

    ret
    findString1 ENDP

calcOffsetInFile PROC near

    mov ax, bufferCount
    mov bx, max_buffer_size
    mul bx                      ;multiply bufferCount(ax) * buffer_size(cx); result dx:ax (32-bit)

    add ax, stringStart         
    jc incMSW

    storeResult:
        mov absoluteFileOffset_LSW, ax
        mov absoluteFileOffset_MSW, dx
        ret

    incMSW:
        inc dx
        jmp storeResult
    
    calcOffsetInFile ENDP


printBuffer PROC near   ;assumes CX and SI are loaded
    mov ah, 02h
    printBufferLoop:
        lodsb
        mov dl, al
        int 21h
        loop printBufferLoop

    ret

    printBuffer ENDP

endProgram PROC near
    MOV AH, 04Ch	; Select exit function
    MOV AL, 00	    ; Return 0
    INT 21h		    ; Call the interrupt to exit
    
    endProgram ENDP

MOV AH, 04Ch	; Select exit function
MOV AL, 00	    ; Return 0
INT 21h		    ; Call the interrupt to exit

end