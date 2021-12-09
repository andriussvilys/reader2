.model small
.stack 100h

.data
FileHandle DW 0 	                ; use this for saving the file handle
FileName DB 'labas.txt', 0
Buffer	DB 200 dup (?)
BufferDest DB 200 dup (?)
BufferSize DW 190

OpenError DB "An error has occured(opening)!$"
ReadError DB "An error has occured(reading)!$"
StringFound DB "StringFound!$"
onPointerMove DB 13, 10, "MATCH $"
onReloadPointer DB "reload", 0Dh, 0Ah, "$"
onBufferFull DB "onBufferFull", 0Dh, 0Ah, "$"
onFindStringSuccess DB 13, 10, "String found$", 13, 10
onFindStringFail DB 13, 10, "String NOT found$", 13, 10

string1 DB 'labas.txt'
string1_size DW 9
string1_counter DB 0    
substr_position DW 0

string2 DB "CHANGED_STRING"
string2_size DW 14

FileSize DW 0

.code 

start:

mov ax, @data 		    ; base address of data segment
mov ds, ax 		        ; put this in ds
mov es, ax

;//OPEN FILE
mov dx, OFFSET FileName 	; put address of filename in dx 
mov al, 2 		            ; access mode - read and write
mov ah, 3Dh 		        ; function 3Dh - open a file
int 21h 		            ; call DOS service

jc ErrorOpening 	        ; jump if carry flag set - error!
mov FileHandle, ax 		    ; save file handle for latered

;//READ FILE

mov si, offset Buffer 	            ; address of buffer in dx
;mov dx, offset Buffer 	            ; address of buffer in dx
mov dx, si
mov bx, FileHandle 		            ; handle in bx

ReadToBuffer:

    mov bx, BufferSize
    dec bx
    cmp bx, FileSize
    js FinishReading

    mov bx, FileHandle

    mov cx, 100 		; amount of bytes to be read
    mov ah, 3Fh 		; function 3Fh - read from file
    int 21h 		; call dos service

    jc ErrorReading 	; jump if carry flag set - error! 

    add FileSize, ax
    add dx, ax

    cmp ax, 0
    je FinishReading

    jmp ReadToBuffer


FinishReading:

    mov dx, offset onBufferFull
    mov ah, 09h
    int 21h

    mov bx, FileHandle 		; put file handle in bx 
    mov ah,3Eh 		        ; function 3Eh - close a file
    int 21h 		        ; call DOS service

    call printCharCount

    call printBuffer

    call FindString

    jmp endProgram


ErrorOpening:
    mov dx, offset OpenError ; display an error 
    mov bx, ax              ;move error code to bx     
    mov ah, 09h 		; using function 09h
    int 21h 		; call DOS service

    ;print error code
    mov dx, bx             
    add dx, '0'
    mov ah, 02
    int 21h

    mov ax, 04Ch 		; end program with an errorlevel =1 
    int 21h 

ErrorReading:
    mov dx, offset ReadError        ; display an error 
    mov bx, ax              ;move error code to bx     
    mov ah,09h 		                ; using function 09h
    int 21h 		                ; call DOS service

    ;print error code
    mov dx, bx             
    add dx, '0'
    mov ah, 02
    int 21h

    mov bx, FileHandle 		; put file handle in bx 
    mov ah,3Eh 		        ; function 3Eh - close a file
    int 21h 		        ; call DOS service

    mov ax, 04Ch 		            ; end program with an errorlevel =2 
    int 21h

printNewLine PROC near
    mov ah, 2

    mov dx, 13
    int 21h

    mov dx, 10
    int 21h

    ret
printNewLine ENDP

;////////////////////

FindString PROC near

mov cx, FileSize
mov si, offset Buffer	    ; SI - buffer address
mov di, offset string1      ; DI - string address


compareChars:

    mov dl, [si]                ;get current char from Buffer

    mov al, [di]                ;get char from string1

    inc si

    cmp al, dl
    je movePointer
    
    jmp reloadPointer


continue:

    mov al, string1_counter
    cmp ax, string1_size        ;// IF correct string char count == string length
    je findString_success

    loop compareChars;        ;Else loop again

    jmp findString_fail         ;if no match found


movePointer:
    mov al, string1_counter
    cmp al, 0
    jz setSubstrPtr

    inc di                  ;move string pointer
    inc string1_counter     ;increment correct char count

    jmp continue

setSubstrPtr:
    mov ax, FileSize
    sub ax, cx
    mov substr_position, ax 

    inc di                  ;move string pointer
    inc string1_counter     ;increment correct char count
    
    jmp continue

reloadPointer:
    mov string1_counter, 0      ;reset correct char count
    mov di, offset string1      ;move string pointer to start

    jmp continue;
    
findString_success:
    mov dx, offset onFindStringSuccess
    mov ah, 09h
    int 21h

    call ReplaceString

    call PrintBufferDest    


    ret

findString_fail:
    mov dx, offset onFindStringFail
    mov ah, 09h
    int 21h        
    
    ret

FindString ENDP

ReplaceString PROC near

    mov di, offset BufferDest

    copyBuffer_half1:
        mov si, offset Buffer	                ; SI - buffer address

        mov cx, substr_position

        call copyBuffer

        jmp replace


    replace:
        ;xor ch, ch
        mov cx, string2_size
        mov si, offset string2
        jmp replace_loop
    
    
        replace_loop:
            mov di, si

            mov dl, [di]
            mov ah, 2
            int 21h

            inc si
            inc di
            loop replace_loop

            jmp copyBuffer_half2


    copyBuffer_half2:

        xor ah, ah
        mov ax, substr_position
        add ax, string1_size

        mov si, offset Buffer        
        add si, ax

        mov cx, FileSize
        sub cx, substr_position

        call copyBuffer

        jmp endReplaceString


    endReplaceString:
    ret

ReplaceString ENDP

CopyBuffer PROC near ;needs si (source index), di (dest index) and cx (loopsize)

    ;movsb di, si
    ;mov dl, [di]
    ;mov ah, 02
    ;int 21h
    ;inc si
    ;inc di

    rep movsb

    ;copyBuffer_loop:
    ;    movsb di, si
    ;    mov dl, [di]
    ;    mov ah, 02
    ;    int 21h
    ;    inc si
    ;    inc di
    ;    loop copyBuffer_loop

ret

CopyBuffer ENDP


printCharCount PROC near

mov cx, 0
mov ax, FileSize    ;get fileSize
mov bx, 10          ;set divisor

    makeDecimal:

        ;divide ax by 10
        ;store remainder (push) on stack
        ;repeat until ax == 0
        ;eg: 159 / 10 = (ax: 15, dx: 9) ... 15 / 10 = (ax: 1, dx: 5) ... 1 / 10 = (ax: 0, dx: 1)
        ;printing off stack (pop) results in 159

        mov dx, 0   ;reset remainder
        div bx      ; instruction: DIV SRC / result: AX - quotient , DX - remainder

        push dx     ;put dx on stack
        inc cx      
        cmp ax, 0   
        jnz makeDecimal

        mov ah, 2

    printInteger: 
        pop dx                  ;put top stack value into address (dx)
        add dl, '0'             ;make ASCII
        int 21h         
        loop printInteger      ;loop while cx > 0

    ret
	
printCharCount ENDP


printBuffer PROC near

    call printNewLine

    mov si, offset Buffer
    mov cx, FileSize

    mov ah, 2

    printbuff:
        mov dl, [si]
        int 21h
        inc si
        loop printbuff

    call printNewLine
    
    ret 

printBuffer ENDP

PrintBufferDest PROC near

    call printNewLine

    ;mov si, offset BufferDest
    mov dx, offset BufferDest
    mov cx, FileSize
    ;sub cx, string1_size
    ;add cx, string2_size

    mov bx, 1
    mov ah, 40h
    int 21h
    ;printBufferDest_loop:
    ;    mov dl, [si]
    ;    int 21h
    ;    inc si
    ;    loop printBufferDest_loop
    
    ret 

    call printNewLine

PrintBufferDest ENDP


endProgram:
    MOV AH, 04Ch	; Select exit function
    MOV AL, 00	    ; Return 0
    INT 21h		    ; Call the interrupt to exit'

end start