.model small
.stack 100h

.data
apie DB 13, 10, "this program opens a file and swaps two strings in the file", 13, 10, "open program with params:", 13, 10, "[source file] [string 1] [string 2]", 13, 10, "*use empty spaces to seprate params0", 13, 10,"*max param lenght: 20$"

fileOpenError DB "File OPEN error.$"
fileReadError DB "File READ error.$"
fileCreateError DB "(temp) File CREATE error.$"
fileWriteError DB "(temp) File WRITE error.$" 
fileMovePointerError DB "(temp) File MOVE POINTER error.$" 

stringFound DB 13, 10, "string found: $"
stringSearchFail DB 13, 10, "string not found: $"

deeperStr DB " is deeper.$"

tempFileName DB "tempfile.txt", 0
tempFileHandle DW 0

readBuffer DB 100 dup (0)
writeBuffer DB 100 dup (0)
max_buffer_size DW 100          ;max value 2^16 && readBuffer >=

bufferCount DW 00h
currentString DW 0              ;ADDRESS of a string to find
nextString DW 0
stringStart DW 0                ;string start in readBuffer; string offset in file = bufferCount * max_buffer_size + stringStart
bufferPointer_LSW DW 0
bufferPointer_MSW DW 0

firstCharMatched db 0            ;1 if matched first char of string; else 0

max_param_size equ 20           ;MUST be at leat 1 byte less than size defined for str1/2 and srcFileName sizes
srcFileName DB 100 dup (0)
srcFileHandle DW ?

str1 DB 100 dup (0)
str2 DB 100 dup (0)

str1_buffer DW 0
str1_offset DW 0
str2_buffer DW 0
str2_offset DW 0

str_firstInFile DW 0
str_secondInFile DW 0

current_buffer DW 0
current_offset DW 0

swapMode DB 0

 
.code 

start:

mov ax, @data
mov es, ax            ;copy ds to es, es used for stosb

mov si, 81h           ;programos paleidimo parametru adresas

call skip_spaces

mov al, byte ptr ds:[si]    ;si now points to first non-space char in params
cmp al, 13
je callHelp

mov ax, word ptr ds:[si]
cmp ax, 3F2Fh                  ;3F='?', 2F='/' 3F2F='/?'
je callHelp

lea di, srcFileName         ;load srcFileName address to di
call save_param

lea di, str1
call save_param

lea di, str2
call save_param

jmp next

callHelp:
    jmp help


next:

mov ax, @data                ;load ds segment
mov ds, ax

call get_file_handle        ;open file and stores file handle in variable fileHandle

lea bx, str1
mov currentString, bx
call findString

mov bx, bufferCount
mov str1_buffer, bx
mov bx, stringStart
mov str1_offset, bx

call resetFilePointer

lea bx, str2
mov currentString, bx
call findString

mov bx, bufferCount
mov str2_buffer, bx
mov bx, stringStart
mov str2_offset, bx

;determine which string comes first in file and will be swapped first
call compareOffsets

call updateFile

call endProgram

help:
    mov ax, @data
    mov ds, ax

    mov dx, offset apie
    mov ah, 9
    int 21h
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
        mov ah, 09h
        lea dx, stringFound
        int 21h

        mov si, currentString       ;currentString is ADDRESS
        call printASCIIZ

        ret

    ret
    findString ENDP

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

    ;First compare buffer indexes
    mov ax, str1_buffer
    mov cx, str2_buffer         

    ;dst == stc : ZF
    ;dst < src  : CF
    ;dst > src  : NZF
    cmp ax, cx

    jc str2_IsFurther
    jnz str1_IsFurther   
                    
    ;if on the same buffer, compare offset in buffer
    mov bx, str1_offset
    mov dx, str2_offset

    cmp bx, dx
    jc str2_IsFurther
    jnz str1_IsFurther   

    ;str2 is first in file
    str1_IsFurther:
        lea bx, str2
        mov str_firstInFile, bx
        lea bx, str1
        mov str_secondInFile, bx

        mov bx, str1_offset
        xchg str2_offset, bx
        mov str1_offset, bx

        mov bx, str1_buffer
        xchg str2_buffer, bx
        mov str1_buffer, bx

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
    lea dx, fileMovePointerError
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

;SI MUST be set to sourceBuffer address
;AX MUST have num of bytes to write
writeToTempFile PROC near

    mov cx, ax              ;move amount of bytes read to CX
    mov ah, 40h
    mov bx, tempFileHandle
    mov dx, si
    int 21h

    jc writeFileError

    ret
    writeToTempFile ENDP

;currentString, nextString, bufferCount MUST be loaded
updateBlock PROC near

    mov cx, bufferCount
    cmp cx, 0h              ;if string is in buffer 0
    jz stringBuffer
    
    copyLoop:               ;copy until target buffer needs to be read
        push cx             ;save loop CX
        mov cx, max_buffer_size
        call readToBuffer         ;stores num of bytes read in AX
        lea si, readBuffer
        call writeToTempFile
        pop cx              ;restore loop CX
        loop copyLoop

    ;when buffer with string will be read
    ;copy to writeBuffer from readBuffer until stringStart
    ;then copy from nextString
    stringBuffer:        
        mov cx, stringStart         ;load max num of bytes to read
        call readToBuffer               ;stores num of bytes read in AX
        
        lea si, readBuffer
        call writeToTempFile  

        ;start copying from the other string
        call swapStringInWriteBuffer

    ret
    updateBlock ENDP

copyToEOF PROC near
    


    copyToEOFLoop:               ;copy until target buffer needs to be read
        mov cx, max_buffer_size
        
        call readToBuffer         ;stores num of bytes read in AX
        cmp ax, 00h
        jz copyToEOFFinish

        lea si, readBuffer
        call writeToTempFile
        jmp copyToEOFLoop

    copyToEOFFinish:
        ret
    

    ret
    copyToEOF ENDP


swapStringInWriteBuffer PROC near
    
    mov si, nextString       ;copy bytes from nextString (nextString is ADDRESS of current string)
    lea di, writeBuffer
    mov cx, max_buffer_size
    xor bx, bx

    copyString:
        lodsb

        cmp al, 00h             ;if end of string
        jz finishSwap

        stosb                   ;DI points to writeBuffer
        inc bx                  ;track how many bytes copied to writeBuffer
        
        loop copyString

    ;control here if buffer is full before end of string
    ;for cases when string spans multiple buffers
    copyToFile:

        push si                         ;save string pointer
                               
        mov ax, bx                      ;how many bytes to write
        lea si, writeBuffer             ;SI must be loaded for writeToTempFile
        call writeToTempFile  
        
        pop si                          ;recover string pointer

        mov cx, max_buffer_size         ;reset CX
        xor bx, bx                      ;reset writeBuffer
        lea di, writeBuffer             ;reset writeBuffer pointer
        
        loop copyString 

    ;this is called when string ends before buffer is full
    finishSwap:

        mov ax, bx                  ;BX keeps track of how many bytes are copied to buffer
        ;push bx                     ;save num of bytes recorded

        lea si, writeBuffer                  
        call writeToTempFile        ;AX - num of bytes to write, SI - source

        ;pop bx

        ;move file pointer
        mov si, currentString
        call getASCIIZLength
        mov dx, cx
        mov cx, 0h                  
        mov bx, srcFileHandle
        mov al, 01h                 ;move pointer forward from current position
        mov ah, 42h
        int 21h
        jc movePointerError

        ret

    swapStringInWriteBuffer ENDP

movePointerError:
    lea dx, writeFileError
    mov ah, 09h
    int 21h
    call endProgram

updateFile PROC near

    call createTempFile
    call resetFilePointer

    mov bx, str_firstInFile
    mov currentString, bx
    mov bx, str_secondInFile
    mov nextString, bx

    mov bx, str1_buffer
    mov bufferCount, bx
    mov bx, str1_offset
    mov stringStart, bx

    call updateBlock

    ;stringStart and bufferCount now point to end of str1 (in OG file)
    ;switch string pointers

    mov bx, str_secondInFile
    mov currentString, bx
    mov bx, str_firstInFile
    mov nextString, bx

    ;this works for file size < 64kB !!
    ;ax : bufferCount
    ;bx : buffer_size
    ;cx : stringStart (offset in buffer)
    ;dx : MSW
    ;ax : LSW
    ;1) get absolute address of str1 END

        ;1.1) get of string position
            mov si, str_firstInFile
            call getASCIIZLength        ;CX == string length
            add str1_offset, cx             ;BX == end of str1 position

        ;1.2) get absolute address of end of string
            mov ax, str1_buffer
            mov bx, max_buffer_size
            mov cx, str1_offset

            call calcAbsoluteOffset
            mov str1_offset, ax

    ;2) get absolute address of str2
            mov ax, str2_buffer
            mov bx, max_buffer_size
            mov cx, str2_offset
            call calcAbsoluteOffset
            mov str2_offset, ax
    
    ;3) get str2 position relative to str1 position
    mov ax, str1_offset
    sub str2_offset, ax

    ;4)convert absolute addrees into bufferCount / stringStart expression
    mov ax, str2_offset
    div max_buffer_size
    mov bufferCount, ax
    mov stringStart, dx

    call updateBlock

    call copyToEOF

    ret
    updateFile ENDP

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

;ax : bufferCount
;bx : buffer_size
;cx : stringStart (offset in buffer)
;dx : MSW
;ax : LSW
calcAbsoluteOffset PROC near

    mul bx                      ;multiply bufferCount(ax) * buffer_size(cx); result dx:ax (32-bit)

    add ax, cx         ;add stringStart (position of string's FIRST BYTE in readBuffer)     
    jc incMSW                   ;increment MSW (most significant word)

    ret

    incMSW:
        inc dx
        ret
    
    calcAbsoluteOffset ENDP

;DEST : AX:DX, SRC BX:CX
ADD_32BIT PROC near

    add dx, cx
    jc incMSW_add
    jmp addMSW

    incMSW_add:
        inc ax

    addMSW:
        add ax, bx

    ret
    ADD_32BIT ENDP

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