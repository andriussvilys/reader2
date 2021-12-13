.model small
	
.code
org    100H	
begin:
	jmp    main

main    proc    far        ; <=== Entry point (main function)

    mov    ax,4c00H
    int    21H

main    endp                ;<=== End function
	
end begin                ;<=== End program


	;; tasm mk_com
	;; tlink /t mk_com
