.model small
.stack 100h

.data
	request		db 'Programa isveda po 1 simboli visus ivestus simbolius', 0Dh, 0Ah, 'Iveskite simboliu eilute:', 0Dh, 0Ah, '$'
	error_len	db 'Iveskite bent viena simboli $'
	result    	db 0Dh, 0Ah, 'Rezultatas:', 0Dh, 0Ah, '$'
	buffer		db 200, ?, 200 dup (?)

    ;_inputCounter dw 0h    ;use dw for integer value
    ;_cycleCounter dw 0h    ;use dw for integer value
    ;newLine db ".", 0Ah, 0Dh, "$"

    ;SKIP db 0


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

	MOV cl, buffer[1]             ; CL: buffer length // idedam i bh kiek simboliu is viso

	cmp cl, 0                    ; patikrina, ar eilute tuscia // idedam i bh kiek simboliu is viso
	je error
	 
	; isvesti: rezultatas
	MOV ah, 09h
	MOV dx, offset result
	int 21h
	
	MOV si, offset buffer + 2           ; priskirti source index'ui bufferio koordinates
	xor ch, ch							; lobsb uses si, loop uses cx
                                        

printChar:

    mov dl, [si]				   ;move char pointed to by si to dl
    cmp dl, 32                     ;compare current char with "SPACE"
	je incSi				   ;IF space, then jump to incSi

testi:
	MOV ah, 2                      ; isvedimui vieno simbolio
	INT 21h

    inc si						   ;increment buffer index

    loop printChar					;LOOP decrements cx, cl is set to buffer[1]
    jmp ending

incSi:

	cmp si, offset buffer + 2
	jnz movChar

	jmp testi

movChar:
    mov dl, [si-1]    		;move char to dl 
    mov [si], dl    		;write onto buffer
	jmp testi

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