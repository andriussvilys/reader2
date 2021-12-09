.model small
.stack 100h

.data

fileName DB "labas.txt", 0
errorMsg DB 13, 10, "ERROR$", 0
fileHandle DW 0

fileNameParam DB 100 dup (0)

buffer db 100 dup (?)
 
.code 

start:

mov ax, @data
mov es, ax                  ;parametrai rasomi es segmente nuo 81h

mov si, 81h                 ;si points to es 81h

xor ax, ax
call skipSpaces
call getParam

call printASCIIZ

lea dx, fileNameParam
;lea dx, fileName
mov ah, 3Dh
mov al, 02h
int 21h

jc endProgram

mov fileHandle, ax

mov bx, fileHandle
mov cx, 100
lea dx, buffer

xor ax, ax
mov ah, 3Fh
int 21h

jc endProgram

xor ax, ax
mov ah, 02h
mov si, offset buffer
printChar:
    lodsb
    mov dl, al
    int 21h
    loop printChar

mov bx, fileHandle
mov ah, 3Eh
int 21h

jc printError

printASCIIZ PROC near
    
    mov ah, 02h
    lea si, fileNameParam

    printASCIIZLoop:
        lodsb
        cmp al, 0
        je finishPrintASCIIZ
        mov dl, al
        int 21h
        jmp printASCIIZLoop


    finishPrintASCIIZ:
        ret
 
    printASCIIZ ENDP


endProgram:
    MOV AH, 04Ch	; Select exit function
    MOV AL, 00	    ; Return 0
    INT 21h	

printError:
    lea dx, errorMsg
    mov ah, 09h
    int 21h

skipSpaces PROC near

    skipSpacesLoop:
        cmp byte ptr ds:[si], ' '
        jnz finishSkipSpaces

        inc si
        jmp skipSpacesLoop

    finishSkipSpaces:
        ret

    skipSpaces ENDP

getParam PROC near

    xor ax, ax
    mov ah, 02h
    mov cx, 10

    lea di, fileNameParam

    copyParam:
        lodsb

        cmp al, 13
        je printParam
        cmp al, ' '
        je printParam

        mov byte ptr ds:[di], al
        inc di

        loop copyParam

    printParam:
        lea di, fileNameParam
        xor ax, ax
        mov ah, 02h

    printParamLoop:        
        mov dl, byte ptr ds:[di]
        cmp dl, 0
        je finish
        int 21h
        inc di
        jmp printParamLoop


    finish:
        ret

    ret
    getParam ENDP

end