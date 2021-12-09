.model small
.stack 64

.data
	msg1 db "Use enter key to quit $"
	msg2 db 10,13,"Enter your string $"
	msg3 db 10,13,"ERROR, enter again", 0Dh, 0Ah,  "$"
	msg4 db 10,13,"Your lowercase string: $"
	msg5 db 10,13,"Its uppercase: $"
	buffer db 100 dup(?)

	max_size dw 100;

.code

main: ;proc far
	mov ax, @data
	mov ds, ax
	
	lea dx, msg1		;display msg1
	mov ah, 9
	int 21h
	
	lea dx, msg2		;display msg2
	mov ah, 9
	int 21h
	
	;mov cx, 0			;initialize cx for counting
	
	;lea si, buffer		;load offset of buffer on si

RESTART:

	mov cx, 0			;initialize cx for counting
	lea si, buffer		;load offset of buffer on si
	
YY: 

	cmp max_size, cx
	je XX

	mov ah, 1			;input from keyboard
	int 21h
	
	cmp al, 13			;cmp al, with enter
	je XX				;jump to XX if al is enter key
	
	;cmp al, 'a'			;cmp al with 'a'
	;jb ERROR				;jump to ERROR if al is below 'a'
	;
	;cmp al,'z'			;cmp al with 'z'
	;ja ERROR				;jump to ERROR if al is above 'z', non lowercase

	mov [si], al		;load al, on [si], storing in buffer
	
	inc si				;increament si
	inc cx				;increament cx, number of chars
	
	jmp YY				;go to YY to enter strings until you press enter
	
ERROR: 
	lea dx, msg3		;display msg3
	mov ah, 9
	int 21h
	
	jmp RESTART				;go to YY to enter again
	
XX: 
	;mov dx, cx     ;prints cx size
	;add dx, '0'
	;mov ah, 02
	;int 21h

	cmp cx, 0
	je ERROR

	lea dx, msg4		;display msg4
	mov ah, 9
	int 21h
	
	;mov cx, cx			;load cx, on cx, number of chars on cx
	mov bx, cx			;load cx, on bx, 
	
	lea si, buffer		;load offset of buffer on si
	
PrintOGInput: 
	mov al, [si]		;load [si] on al, to display on screen
	
	mov ah, 2
	mov dl, al			;display al on screen
	int 21h
	
	inc si
	
	loop PrintOGInput			;go to PrintOGInput until cx = 0
	
	mov cx, bx			;load bx, on cx, number of chars in buffer
	
	lea si, buffer		;load offset of buffer on si
	
	lea dx, msg5		;display msg5
	mov ah, 9
	int 21h

TOP2: 
	mov al, [si]		;load chars from buffer on al

	call PrintChar
	
	inc si
	
	loop TOP2			;go to TOP2 until cx = 0
	
	mov ah, 4CH			;return to os
	int 21h


PrintChar PROC near

	cmp al, 'Z'			;if al <= Z
	jbe printNormal		

						; if above Z
	cmp al,'a'			; chars between Z and a are non-alphabet symbols 
	jb printNormal		

						; if above or equal a
	cmp al,'z'			; chars between a and z are lowercase letters
	jbe printUppercase	
	jmp printNormal		; chars above z are non-alphabet symbols

	printNormal:
		mov ah,2
		mov dl, al			
		int 21h
		ret

	printUppercase:
		sub al, 20h			;convert uppercase to lowercase
		mov ah, 2
		mov dl, al			;display each chars on screen
		int 21h
		ret

ret
PrintChar ENDP

ending:
    MOV AH, 04Ch	; Select exit function
    MOV AL, 00	    ; Return 0
    INT 21h		    ; Call the interrupt to exit'

end