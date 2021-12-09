.model small
.stack 100h

.data
	msg    db      "Hello, World!", 0Dh,0Ah, 24h

.code

start:
	MOV dx, @data                   ; perkelti data i registra ax
	MOV ds, dx                      ; perkelti ax (data) i data segmenta

	mov     dx, offset msg
        mov     ah, 09h 
        int     21h 
        
	MOV ah, 4ch 		        ; griztame i dos'a
	MOV al, 0 		        ; be klaidu
	INT 21h                        	; dos'o INTeruptas
end start
