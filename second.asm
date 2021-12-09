.model small
.stack 100h

.data
	request		db 'Programa isveda po 1 simboli visus ivestus simbolius', 0Dh, 0Ah, 'Iveskite simboliu eilute:', 0Dh, 0Ah, '$'
	error_len	db 'Ivesti galite ne daugiau 5 simboliu $'
	result    	db 0Dh, 0Ah, 'Rezultatas:', 0Dh, 0Ah, '$'
	buffer		db 100, ?, 100 dup (0)
    _inputCounter dw 0h    ;use dw for integer value
    _cycleCounter dw 0h    ;use dw for integer value
    newLine db ".", 0Ah, 0Dh, "$"
    SKIP db 0


.code

start:
	MOV ax, @data                   ; perkelti data i registra ax
	MOV ds, ax                      ; perkelti ax (data) i data segmenta
	 
	; Isvesti uzklausa
	MOV ah, 09h
	MOV dx, offset request
	int 21h

	; skaityti eilute
	MOV dx, offset buffer           ; skaityti i buffer offseta 
	MOV ah, 0Ah                     ; eilutes skaitymo subprograma
	INT 21h                         ; dos'o INTeruptas

	; kartoti
	MOV cl, buffer[1]             ; CL: buffer length // idedam i bh kiek simboliu is viso

	cmp cl, 0                    ; patikrina, ar eilute tuscia // idedam i bh kiek simboliu is viso
	je error
	 
	; isvesti: rezultatas
	MOV ah, 09h
	MOV dx, offset result
	int 21h
	
	MOV si, offset buffer + 2           ; priskirti source index'ui bufferio koordinates
	xor ch, ch
                                        ; lobsb uses si, loop uses cx

char:

	LODSB                        	; 1. loads [si] to al 2. increments si
	 
	MOV dl, al                    	; i dl padeti simboli is al

    cmp dl, 32                     ;compare current char with "SPACE"
        je printPrevChar

	MOV ah, 2                    	; isvedimui vieno simbolio
	INT 21h
    
    loop char
	JMP ending                      	; jei bh = 0 , programa baigia darba


printPrevChar:

    dec si
    dec si
    	
    LODSB                        	
	MOV dl, al 
    mov ah, 02
    int 21h

    inc si

    ;jmp char
    loop char


error:
	MOV ah, 09h
	MOV dx, offset error_len
	INT 21h
	JMP start
	 
ending:
    MOV AH, 04Ch	; Select exit function
    MOV AL, 00	    ; Return 0
    INT 21h		    ; Call the interrupt to exit'
	 
end start