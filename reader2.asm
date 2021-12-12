.model small
.stack 100h

.data
apie DB "this program opens a file and swaps two strings in the file", 13, 10, "open program with params:", 13, 10, "[source file] [string 1] [string 2]", 13, 10, "*use empty spaces to seprate params0", 13, 10,"*max param lenght: 20$"

fileOpenError DB "File OPEN error.$"
fileReadError DB "File READ error.$"
fileCreateError DB "(temp) File CREATE error.$"
fileWriteError DB "(temp) File WRITE error.$" 

stringFound DB 13, 10, "string found: $"
stringSearchFail DB 13, 10, "string not found: $"

deeperStr DB " is deeper.$"

tempFileName DB "tempfile.txt", 0
tempFileHandle DW 0

readBuffer DB 100 dup (?)
writeBuffer DB 100 dup (?)
max_buffer_size DW 100          ;max value 2^16 && readBuffer >=
bufferCount DW 00h

currentString DW 0              ;ADDRESS of a string to find
stringStart DW 0                ;string start in readBuffer; string offset in file = bufferCount * max_buffer_size + stringStart
bufferPointer_LSW DW 0
bufferPointer_MSW DW 0

firstCharMatched db 0            ;1 if matched first char of string; else 0

max_param_size equ 20           ;MUST be at leat 1 byte less than size defined for str1/2 and srcFileName sizes
srcFileName DB 100 dup (0)
srcFileHandle DW ?

str1 DB 100 dup (0)
str2 DB 100 dup (0)

str1_offset_LSW DW 0
str1_offset_MSW DW 0
str2_offset_LSW DW 0
str2_offset_MSW DW 0

str1_buffer DW 0
str1_offset DW 0
str2_buffer DW 0
str2_offset DW 0

str_firstInFile DW 0
str_secondInFile DW 0

currentOffset_MSW DW 0
currentOffset_LSW DW 0

swapMode DB 0

 
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

lea si, str1
call getASCIIZLength

lea si, str2
call getASCIIZLength

call get_file_handle        ;open file and stores file handle in variable fileHandle

lea bx, str1
mov currentString, bx
call findString

mov bx, currentOffset_LSW
mov str1_offset_LSW, bx
mov bx, currentOffset_MSW
mov str1_offset_MSW, bx

call resetFilePointer

lea bx, str2
mov currentString, bx
call findString

mov bx, currentOffset_LSW
mov str2_offset_LSW, bx
mov bx, currentOffset_MSW
mov str2_offset_MSW, bx

call compareOffsets

call createTempFile

call resetFilePointer

xor cx, cx
call writeToFile

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
    call skip_spaces
    xor cx, cx              ;reset char counter

    save_param_loop:

        cmp byte ptr ds:[si], 13
        je save_param_end
        cmp byte ptr ds:[si], ' '
        jne save_param_next             ;if NOT /n and NOT ' ', save the char in ES:[di]

    save_param_end:
        cmp cx, 0            ;if empty param
        jz help
        ret
    
    save_param_next:
        mov ax, max_param_size
        cmp cx, ax  ;check that cx < max_param_size
        jz help
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
    mov al, 00h                     ;read/write attribute
    int 21h
    jc error_fileOpen
    mov srcFileHandle, ax

    ret

    get_file_handle ENDP

resetFilePointer PROC near

    mov ah, 42h                 ;move file pointer
    mov al, 0h                  ;offset start at the beginning
    mov bx, srcFileHandle
    xor cx, cx                  ;cx - MSW (most significant word)
    xor dx, dx                  ;dx - LSW (least significant word)
    int 21h

    jc error_fileRead
    
    ret
    resetFilePointer ENDP

;move filePointer to absoluteFileOffset
moveFilePointer PROC near

    mov ah, 42h                 ;move file pointer
    mov al, 0h                  ;to beginning
    mov bx, srcFileHandle
    mov cx, currentOffset_MSW                  ;cx - MSW (most significant word)
    mov dx, currentOffset_LSW                  ;dx - LSW (least significant word)
    int 21h

    jc error_fileRead

    ret
    moveFilePointer ENDP

;read bytes from file to readBuffer
;CX must be loaded
;returs AX == number of bytes read
readToBuffer PROC near

    mov bx, srcFileHandle       ;bx - file handle
    lea dx, readBuffer              ;dx - pointer to read readBuffer
    mov ah, 3Fh                 ;read from file
    int 21h

    jc error_fileRead

    ret
    readToBuffer ENDP

;si - readBuffer pointer, di - string pointer
;if [si] == [di], then move str_ptr
;else reload str_start
;currentString needs to be the ADDRESS of a string we need to find
findString PROC near

    mov di, currentString                ;DI - string pointer
    mov currentOffset_LSW, 0h
    mov currentOffset_MSW, 0h
    mov bufferCount, 0h
    mov stringStart, 0h

    findStringLoop:
        mov cx, max_buffer_size
        call readToBuffer           ;read bytes from file to readBuffer
        cmp ax, 0                   ;if 0 bytes are read and string still not found - fail
        je fail

        mov bufferPointer_LSW, 0h       ;reset readBuffer pointer
        lea si, readBuffer	            ;SI - readBuffer pointer

    compareChars:
        lodsb                               ;load readBuffer char to AL from ds:[si]
        cmp al, byte ptr ds:[di]            ;AL - readBuffer char, [DI] - string char
        je checkIfFirstCharMatched
        jmp reloadPointer

    ;if string not found:
    fail:
        mov dx, offset stringSearchFail             
        mov ah, 09h
        int 21h
        mov si, currentString
        call printASCIIZ

        ret

    continue:
        inc bufferPointer_LSW
        loop compareChars                 ;if cx is 0 jmp to findStringLoop
        jmp finishLoop

    moveStringPointer:                    ;if readBuffer and str chars match
        inc di                            ;move string pointer forward
        cmp byte ptr ds:[di], 0h          ;if end of string using ASCIIZ format (0h marks ends of string)
        je success
        jmp continue

    reloadPointer:
        mov firstCharMatched, 0h
        mov di, currentString                               ;di - string pointer
        jmp continue

    checkIfFirstCharMatched:
        cmp firstCharMatched, 0h           ;if firstCharMatched == 1, then moveStringPointer
        jnz moveStringPointer

    ;set stringStart to current bufferPointer
    setfirstCharMatched:
        mov firstCharMatched, 1h

        mov bx, bufferPointer_LSW
        mov stringStart, bx

        jmp moveStringPointer

    finishLoop:
        inc bufferCount                     ;increment bufferCount at the end of each loop
        jmp findStringLoop


    success:
        call calcOffsetInFile
        mov ah, 09h
        lea dx, stringFound
        int 21h

        mov si, currentString       ;currentString is ADDRESS
        call printASCIIZ

        ret

    ret
    findString ENDP

calcOffsetInFile PROC near

    mov ax, bufferCount
    mov bx, max_buffer_size
    mul bx                      ;multiply bufferCount(ax) * buffer_size(cx); result dx:ax (32-bit)

    add ax, stringStart         ;add stringStart (position of string's FIRST BYTE in readBuffer)     
    jc incMSW                   ;increment MSW (most significant word)

    storeResult:
        mov currentOffset_LSW, ax
        mov currentOffset_MSW, dx
        ret

    incMSW:
        inc dx
        jmp storeResult
    
    calcOffsetInFile ENDP

;num1: ax:bx
;num2: cx:dx
;ZF: both equal, NZF: num1 greater, CF: num2 greater
CMP_32BIT PROC near
    cmp ax, cx         ;compare MSW
    jz cmp_lsw         ;num1_msw == num2_msw
    ret                ;return if src or dest is strictly greater

    cmp_lsw:
        cmp bx, dx         
        ret

    CMP_32BIT ENDP

;find which string comes first in the file
;assigns str_firstInFile and str_secondInFile
compareOffsets PROC near

    ;str1 offset
    mov ax, str1_offset_MSW
    mov bx, str1_offset_LSW
    ;str2 offset
    mov cx, str2_offset_MSW         
    mov dx, str2_offset_LSW

    call CMP_32BIT

    jc str2_IsFurther
    jnz str1_IsFurther                                ;otherwise consider str1 to be deeper in file
        
    str1_IsFurther:
        lea bx, str2
        mov str_firstInFile, bx
        lea bx, str1
        mov str_secondInFile, bx

        mov bx, str1_offset_LSW
        xchg str2_offset_LSW, bx
        mov bx, str1_offset_MSW
        xchg str2_offset_MSW, bx

        jmp finishOffsetCompare

    str2_IsFurther:
        lea bx, str1
        mov str_firstInFile, bx
        lea bx, str2
        mov str_secondInFile, bx
        jmp finishOffsetCompare

    finishOffsetCompare:

        mov si, str_secondInFile
        call printASCIIZ
        lea dx, deeperStr
        mov ah, 09h
        int 21h
        ret

    compareOffsets ENDP

createFileError:
    lea dx, createFileError
    mov ah, 09h
    int 21h
    call endProgram

writeFileError:
    lea dx, writeFileError
    mov ah, 09h
    int 21h
    call endProgram

createTempFile PROC near
    
    mov ah, 3Ch
    xor cx, cx                  ;file attributes. In this case set to "normal"
    lea dx, tempFileName
    int 21h
    jc createFileError
    mov tempFileHandle, ax

    ret
    createTempFile ENDP

writeToFile PROC near

    writeLoop:

        push cx
        call createWriteBuffer
        cmp ax, 0h               ;loop until no more bytes are read from srcFile
        jz writeFinish

        mov cx, ax              ;move amount of bytes read to CX
        mov ah, 40h
        mov bx, tempFileHandle
        lea dx, writeBuffer
        int 21h

        jc writeFileError

        pop cx
        inc cx

        jmp writeLoop


    writeFinish:
        pop cx
        ret

    writeToFile ENDP

;si - readBuffer
;di - writeBuffer
createWriteBuffer PROC near
    
    lea di, writeBuffer         ;DI always points to writeBuffer

    cmp swapMode, 0h
    jnz swap_return           ;SI points to swap string

    lea si, readBuffer          ;or to readBuffer
    
    readLoop:
                 
        push cx                     ;save num of calls to this PROC

        mov cx, max_buffer_size     ;CX must be set before calling readToBuffer
        call readToBuffer           ;stores num of bytes read in AX

        cmp ax, 0h              ;if 0 bytes read
        jz finishCopy

        pop cx
        cmp cx, bufferCount         ;here CX stands for the number of createWriteBuffer calls
        jz replaceLoop_start        ;if string starts in this buffer

        mov dx, ax              ;save number of bytes read
        mov cx, ax              ;move number of bytes read to CX

    copyByte:
        movsb
        loop copyByte

    finishCopy:
        ret          

    replaceLoop_start:                 ;starts with new buffer
        mov cx, stringStart            ;stringStart < max_buffer_size

    replaceLoop_continue:              ;movsb until stringStart is reached
        movsb
        loop replaceLoop_continue

    swap_start:                     ;start swapping string
        mov cx, dx                  ;move number of read bytes to cx
        sub cx, stringStart
        mov bx, si                  ;save readBuffer position in BX
        mov si, str_secondInFile        
        mov swapMode, 1h            ;set swap mode in case string spans more than 1 buffer
    
    swap_continue:
        lodsb                       ;load byte from DS:[SI] to AL

        cmp al, 0h
        jz swap_finish              ;if string copied before buffer end

        stosb                       ;DI points to writeBuffer
        loop swap_continue          ;loop until writeBuffer is full

    swap_interrupted:               ;if writeBuffer is full before end of string
        mov ax, dx
        ret

    swap_finish:
        mov swapMode, 0h                ;swapMode == FALSE
        ;move SI (read buffer) forward by old string length
        push cx                         ;save current writeBuffer position
                                        ;getASCIIZLength uses CX
        mov si, str_firstInFile         ;reload string address
        call getASCIIZLength    
        mov ax, cx                      ;save string length to AX
        pop cx                          ;recover writeBuffer position
        mov si, bx                      ;recover previous readBuffer position
        add si, ax                      ;move SI forward by [stringLength] bytes               
        loop copyByte
        ret

    swap_return:
        mov cx, max_buffer_size
        jmp swap_continue

    ret

    createWriteBuffer ENDP

;si - string address
getASCIIZLength PROC near
    
    xor cx, cx

    incLenght:
        lodsb
        cmp al, 0h
        jz finishGetASCIIZLength
        inc cx
        jmp incLenght

    finishGetASCIIZLength:
        ret
    
    getASCIIZLength ENDP

printBuffer PROC near   ;assumes CX and SI are loaded
    mov ah, 02h
    printBufferLoop:
        lodsb
        mov dl, al
        int 21h
        loop printBufferLoop

    ret

    printBuffer ENDP

printASCIIZ PROC near   ;assumes si is loaded with address of the string
    mov ah, 02h

    printASCIIZ_loop:
        lodsb
        cmp al, 0h
        je printASCIIZ_finish
        mov dl, al
        int 21h
        jmp printASCIIZ_loop

    printASCIIZ_finish:
        ret

    printASCIIZ ENDP

endProgram PROC near
    MOV AH, 04Ch	; Select exit function
    MOV AL, 00	    ; Return 0
    INT 21h		    ; Call the interrupt to exit
    
    endProgram ENDP

MOV AH, 04Ch	; Select exit function
MOV AL, 00	    ; Return 0
INT 21h		    ; Call the interrupt to exit

end