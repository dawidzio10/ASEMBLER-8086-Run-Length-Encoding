	assume cs:code1, ds:data1, ss:stack1

	data1 segment
	argslength			db 16 dup(0)																			;OK Ograniczenie do 16 argumentow
	argscounter			dw 0																					;OK
	args 				db 128 dup('$')																			;OK Maksymalnie moze byc 127 bajtów argumentow
	usage				db "Uzycie rle.exe [-d] input output$"													;OK
	flag				db ?																					;OK 0 - kompresja 1 - dekompresja
	ifname				db 13 dup(0)																			;OK Nazwa pliku w dos to 8 znakow + 3 rozszerzenie + 0 na końcu
	ofname				db 13 dup(0)																			;OK Nazwa pliku w dos to 8 znakow + 3 rozszerzenie + 0 na końcu
	if_handler			dw	?																					;OK
	of_handler			dw	?																					;OK
	inopening_errors	db	"Blad otwarcia pliku do odczytu$"													;OK
	outopening_errors	db	"Blad otwarcia pliku do zapisu$"													;OK
	inclosing_errors	db	"Blad zamkniecia pliku do odczytu$"													;OK
	outclosing_errors	db	"Blad zamkniecia pliku do zapisu$"													;OK
	reading_errors		db	"Blad odczytu z pliku$"																;OK
	writing_errors		db	"Blad zapisu do pliku!$"															;OK
	inputbuffer			db 4096 dup(?)																			;OK
	outputbuffer		db 4096 dup(?)																			;OK
	inputbufferpointer 	dw 0																					;OK
	outputbufferpointer dw 0																					;OK
	data1 ends																									

	code1 segment

	start:
		mov ax, seg data1
		mov ds, ax
		mov ax, seg stack1
		mov ss, ax
		mov sp, offset wsk

		mov ah,62h
		int 21h
		mov es,bx

		xor di,di
		mov bl,81h; od znaku spacji szukamy niebiałych znakow
	petla:
		call findnotwhite ;zwraca w bl niebiały znak
		call copytowhite  ;pobiera z bl niebiały znak, zwraca w di - ostatnie miejsce w args do ktorego skopiowano
	cmp byte ptr es:[bx],13d ; jesli enter to koncyzmy
	jne petla

		call checkargs

		call openfiles


		cmp flag,1
		je deco

		call compress
		jmp finish

		deco:
		call decompress

	finish:

		call closefiles
	quit:
		mov ah,4ch
		int 21h
	;****************************************
	;******wyszukiwanie niebialego znaku*****
	;****************************************
	;input bl - adres od ktorego szuka 
	;output bl - adres pierwszego niebialego znaku

	findnotwhite proc
		push dx
		xor bh,bh
	comp1:
		mov dl,byte ptr es:[bx]
		cmp dl,32d ;znak spacji
		je white
		cmp dl,9d ;znak tabulatora
		je white
		jmp foundnotwhite

	white:
		inc bl
		jmp comp1

	foundnotwhite:
		pop dx
		ret
	findnotwhite endp
	;****************************************
	;******kopiowanie do białego znkau*******
	;****************************************
	;input bl - adres od ktorego kopiuje 
	;output bl - adres nastepnego bialego znaku, di do którego miejsca uzyte args

	copytowhite proc
		push dx
		push si
		
		xor bh,bh
		mov si,argscounter

	copy:
		mov dl,byte ptr es:[bx]

		cmp dl,32d ;znak spacji
		je brcopy
		cmp dl,9d ;znak tabulatora
		je brcopy
		cmp dl,13d ;znak entera
		je brcopy

		mov byte ptr ds:[args+di],dl
		inc argslength[si]
		inc di
		inc bl
		jmp copy

	brcopy:
		mov byte ptr ds:[args+di],'$'
		inc di
		inc argscounter
		pop si
		pop dx
		ret
	copytowhite endp

	;****************************************
	;******sprawdzanie poprawnosci arg*******
	;****************************************

	checkargs proc
		push ax
		push di
		push bp
		

		mov dl,byte ptr ds:[args]
		cmp dl,'-'
		je withflag

		cmp argscounter,2
		jne wrong
		mov flag,0
		xor bp,bp ; od tego miejsca jest input
		xor di,di ;czyszcze wskaznik 
		call copyinput
		xor di,di ;czyszcze wskaznik 
		inc bp ; przesuwam sie ze znaku dolara
		call copyoutput
		jmp zwroc

	withflag:
		cmp argscounter,3
		jne wrong
		mov dl,byte ptr ds:[args+1]
		cmp dl,'d'
		jne wrong
		mov flag,1
		mov bp,3 ; od tego miejsca jest input
		xor di,di ;czyszcze wskaznik 
		call copyinput
		xor di,di ;czyszcze wskaznik 
		inc bp ; przesuwam sie ze znaku dolara na output
		call copyoutput
		jmp zwroc

	copyinput:
		mov dl,byte ptr ds:[args+bp]
		mov ifname[di],dl
		inc di
		inc bp
		cmp byte ptr ds:[args+bp],'$'
		jne copyinput
		ret

	copyoutput:
		mov dl,byte ptr ds:[args+bp]
		mov ofname[di],dl
		inc di
		inc bp
		cmp byte ptr ds:[args+bp],'$'
		jne copyoutput
		ret

	wrong:
		mov dx,offset ds:[usage]
		mov ah,9
		int 21h
		pop bp
		pop di
		pop ax
		jmp quit

	zwroc:
		pop bp
		pop di
		pop ax
		ret
			
	checkargs endp
	;****************************************
	;******otwarcie plikow*******************
	;****************************************

	openfiles proc
		push ax
		push dx



	;otwarcie pliku input
		mov al,0  ; al=0 -> plik do odczytu
		mov	ah,3dh  ;otwarcie pliku
		lea	dx,[ifname]
		int	21h
		jc inopening_error
		mov	if_handler,ax
		
		;otwarcie pliku output
		;mov	ah,3dh  ;otwarcie pliku
		;mov al,1
		;lea	dx, [ofname]
		;int	21h
		;jc createfile ;jesli sie nie powiodlo to tworze plik
		;mov	of_handler,ax
		;jmp zwroc2

	;tworzenie pliku output
		createfile:
		lea dx, [ofname]
		mov ah,3ch
		mov cx,0 ; do zapisu
		int 21h
		jc outopening_error
		mov	of_handler,ax
		jmp zwroc2

		inopening_error:
		mov dx,offset ds:[inopening_errors]
		jmp wypiszblad

		outopening_error:
		mov dx,offset ds:[outopening_errors]

	wypiszblad:
		mov ah,9
		int 21h
		pop dx
		pop ax
		jmp quit

	zwroc2:
		pop dx
		pop ax
		ret

	openfiles endp
	;****************************************
	;******zamkniecie plikow*****************
	;****************************************

	closefiles proc
		push ax
		push bx
		push dx

		mov ah, 3eh
		mov bx, ds:[if_handler]
		int 21h 
		jc inclosing_error

		mov ah, 3eh
		mov bx, ds:[of_handler]
		int 21h
		jc outclosing_error

		pop dx
		pop bx
		pop ax
		ret

		inclosing_error:
		mov dx,offset ds:[inclosing_errors]
		jmp wypiszblad2

		outclosing_error:
		mov dx,offset ds:[outclosing_errors]

	wypiszblad2:
		mov ah,9
		int 21h
		pop dx	
		pop bx
		pop ax
		jmp quit		
	closefiles endp
	;****************************************
	;******zaladowanie do bufora*************
	;****************************************
	;zwraca w ax ilosc zaladowanych bajtow
	getchar proc
		push ax
		push bx
		push cx
		push dx
		
		lea	dx, inputbuffer
		mov	bx,ds:[if_handler]
		mov	cx,4096
		mov	ah,3fh		
		int	21h
		jc reading_error
		mov inputbufferpointer,ax
		pop dx
		pop cx
		pop bx
		pop ax
		ret

		reading_error:
		mov dx,offset ds:[reading_errors]
		mov ah,9
		int 21h	
		pop dx
		pop cx
		pop bx
		pop ax
		jmp quit
	getchar endp
	;****************************************
	;******zapisanie z bufora do pliku*******
	;****************************************
	putchar proc
		push ax
		push bx
		push cx
		push dx

		lea dx, outputbuffer
		mov bx, ds:[of_handler]
		mov cx,outputbufferpointer ; ile bitow zapisac
		mov ah,40h
		int 21h
		jc writing_error

		pop dx
		pop cx
		pop bx
		pop ax
		ret


		writing_error:
		mov dx,offset ds:[writing_errors]
		mov ah,9
		int 21h	
		pop dx
		pop cx
		pop bx
		pop ax
		jmp quit

	putchar endp
	;****************************************
	;******KOMPRESJA*************************
	;****************************************

	compress proc
	push ax
	push si
	push di


	xor di,di
	xor ah,ah
pocz:
	call getchar
	
	cmp inputbufferpointer,0
	je zakoncz

	xor si,si

p0:
	mov al,inputbuffer[si]
p1:
	cmp di,4092
	jae putchart
	cmp si,inputbufferpointer
	jae pocz
	cmp al,0
	je zero
	cmp ah,255
	je zapisz
	cmp inputbuffer[si],al
	je powieksz

	cmp ah,3
	jb wpisznormalnie

zapisz:
	mov outputbuffer[di],0h
	inc di
	mov outputbuffer[di],ah
	inc di
	mov outputbuffer[di],al
	inc di
	xor ah,ah
	jmp p0



powieksz:
	inc si 
	inc ah
	jmp p1

wpisznormalnie:
	mov outputbuffer[di],al
	dec ah
	inc di
	cmp ah,0
	ja wpisznormalnie
	xor ah,ah
	jmp p0

zero:
	mov outputbuffer[di],0h
	inc di
	mov outputbuffer[di],0h
	inc di
	inc si
	xor ah,ah
	jmp p0

putchart:
	mov outputbufferpointer,di
	call putchar
	xor di,di
	mov outputbufferpointer,di
	jmp p0

zakoncz:
	cmp ah,0
	je endd
	cmp ah,3
	jb normalnie

	mov outputbuffer[di],0h
	inc di
	mov outputbuffer[di],ah
	inc di
	mov outputbuffer[di],al
	inc di
	jmp endd

	normalnie:
	mov outputbuffer[di],al
	dec ah
	inc di
	cmp ah,0
	ja normalnie

endd:
	mov outputbufferpointer,di
	call putchar

	pop di
	pop si
	pop ax
	ret
compress endp
	;****************************************
	;******DEKOMPRESJA***********************
	;****************************************

decompress proc
	push ax
	push cx
	push si
	push di


	xor di,di

pocz:
	call getchar
	cmp inputbufferpointer,0
	je zakoncz

	xor si,si

p0:
	cmp si,inputbufferpointer
	jae pocz
	cmp di,3800
	jae putchart

	mov ah,inputbuffer[si]
	cmp ah,0
	je zero

	mov outputbuffer[di],ah
	inc si
	inc di
	jmp p0


zero:
	inc si
	cmp inputbuffer[si],0
	je zerozero

	mov cl,inputbuffer[si]
	inc si
	mov ah,inputbuffer[si]

copy:
	mov outputbuffer[di],ah
	inc di
	dec cl
	cmp cl,0
	ja copy
	inc si
	jmp p0

zerozero:
	mov outputbuffer[di],0h
	inc di
	inc si
	jmp p0

putchart:
	mov outputbufferpointer,di
	call putchar
	xor di,di
	jmp p0

	zakoncz:
	mov outputbufferpointer,di
	call putchar
	pop di
	pop si
	pop cx
	pop ax
	ret
decompress endp
	code1 ends

	stack1 segment stack
			dw 200 dup(?)
		wsk dw ?
	stack1 ends
	end start