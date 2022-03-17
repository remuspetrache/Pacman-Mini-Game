;PACMAN 
;Petrahce Remus-Mircea; grupa 302110

;In prezent, versiunea de Pacman poate fi jucata prin folosirea sagetilor afisate pe ecran. 
;Astfel, daca vom apasa click pe una dintre sagetile de miscare, atunci Pacman se va deplasa pe directia respectiva.
;Fantomele vor alege din 8 in 8 secunde daca se vor deplasa pseudo-random, sau ghidat (incercand sa il prinda pe Pacman). 
;Sansa de a alege oricare dintre aceste doua miscari, este de 50%, alegandu-se random un numar si in functie de paritatea sa, decidandu-se modul de deplasare.
;In joc exista 3 bonusuri care vor aparea la momente prestabilite de timp, pentru o durata de timp ce poate fi modificata dupa preferinte.
;Ciresele rosii adauga un bonus de 50 de puncte la scorul actual, iar cireasa albastra "ingheata" fantomele pentru 6 secunde.
;Daca Pacman este "mancat" de 3 ori de fantome, atunci jocul este incheiat, afisandu-se mesajul "You lost".
;In schimb, daca Pacman reuseste sa manance toate punctele din labirint, jocul se va considera finalizat si se va afisa mesajul "You won".
;La final, utilizatorul poate alege sa reia jocul, prin apasarea butonului aflat imediat sub mesajul de final de joc corespunzator.
;De asemenea, in cazul terminarii primului nivel, am implementat si un al doilea nivel, insa este foarte asemanator. Cu toate acestea, matricea
;nivelului 2, aflata in matrice.inc poate fi modificata
.586
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc

includelib canvas.lib
extern BeginDrawing: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date
window_title DB "Pacman",0
area_width EQU 600
area_height EQU 480
area DD 0

begin_game DD 0
nivel DD 0

;coordonatele caracterului Pacman salvate de 2 ori, pentru a ne putea intoarce la inceput cand murim
i DD 11
j DD 11
i_initial DD 11
j_initial DD 11
;move_i si move_j sunt folosite pentru deplasarea pe linii, respectiv coloane
move_i DD 0
move_j DD 0

vieti DD 3
finish DD 0 ;finish=0, indica faptul ca jocul nu este gata

;coordonatele si momentul de aparitie al fiecarui bonus
i_visine1 DD 20
j_visine1 DD 4
visina_mancata1 DD 0
spawn_visina1 EQU 40
despawn_visina1 EQU 60


i_visine2 DD 4
j_visine2 DD 17
visina_mancata2 DD 0
spawn_visina2 EQU 70
despawn_visina2 EQU 90

freeze DD 0
freezetime DD 0

i_visine3 DD 11
j_visine3 DD 15
visina_mancata3 DD 0
spawn_visina3 EQU 100
despawn_visina3 EQU 120

;coordonatele fantomelor, impreuna cu modul lor de miscare initial
i_roz DD 6
j_roz DD 6
i_roz_initial DD 6
j_roz_initial DD 6
h_roz DD 1
v_roz DD 0
random_roz DD 0

i_portocaliu DD 8
j_portocaliu DD 10
i_portocaliu_initial DD 8
j_portocaliu_initial DD 10
h_portocaliu DD 1
v_portocaliu DD 0
random_portocaliu DD 0

i_rosu DD 6
j_rosu DD 13
i_rosu_initial DD 6
j_rosu_initial DD 13
h_rosu DD 1
v_rosu DD 0
random_rosu DD 0

i_albastru DD 17 
j_albastru DD 13
i_albastru_initial DD 17 
j_albastru_initial DD 13
h_albastru DD 1
v_albastru DD 0
random_albastru DD 0

cnt_random DD 0 ; vom folosi acest counter, pentru a genera random, dupa 2 secunde, miscarea fantomelor
;fiecare fantoma va alege random daca se va deplasa ghidat, sau dupa varianta pseudo-random implementata 

counter DD 0 ; numara evenimentele de tip timer
counterStart DD 0 ; folosit pentru a astepta un interval de timp inainte de a incepe jocul
counterPoints DD 0 ; folosit pentru a numara punctele
counterPuncte DD 0 ; folosit pentru a manca bilele albe
counterBonus DD 0 ; folosit pentru a numara timpul de aparitie al bonusului
pointsNivel1 EQU 203 ; toate bilele albe din matrice
pointsNivel2 EQU 219
DOI DD 2
ZECE DD 10

arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20

symbol_width EQU 10
symbol_height EQU 20
sageti_width EQU 20
sageti_height EQU 20

include digits.inc
include letters.inc
include sageti.inc
include symbol.inc
include harta.inc

;chenarul matricei de joc
chenar_width EQU 285
chenar_height EQU 285
;chenarul in care gasim sagetile de deplasare
deplasare_width EQU 200
deplasare_height EQU 140
;chenarul cu informatii despre joc
informatii_width EQU 200
informatii_height EQU 100

nr_linii EQU 21
nr_coloane EQU 21
numar_efectiv_de_coloane EQU 22 ; intrucat coloanele sunt contorizate de la 0 la n-1, aici am salvat "n", numarul total de coloane
dimensiune_simbol EQU 13

harta DD 2*(nr_linii+1)*(nr_coloane+1) DUP(0)

.code
; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
make_text proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	cmp eax, 'A'
	jl make_digit
	cmp eax, 'Z'
	jg make_digit
	sub eax, 'A'
	lea esi, letters
	jmp draw_text
make_digit:
	cmp eax, '0'
	jl make_space
	cmp eax, '9'
	jg make_space
	sub eax, '0'
	lea esi, digits
	jmp draw_text
make_space:	
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	lea esi, letters
	
draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_negru
	mov dword ptr [edi], 0FFFF00h
	jmp simbol_pixel_next
simbol_pixel_negru:
	mov dword ptr [edi], 0
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_text endp

; procedura make_sageti afiseaza o anumita sageata la coordonatele date
; arg1 - simbolul de afisat -> A= UP; B=RIGHT; C=DOWN; D=LEFT
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
make_sageti proc
	push ebp
	mov ebp, esp
	pusha
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	sub eax,'A'
	lea esi, sageti
	mov ebx, sageti_width
	mul ebx
	mov ebx, sageti_height
	mul ebx
	add esi, eax
	mov ecx, sageti_height
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, sageti_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx	
	mov ecx, sageti_width
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_negru
	mov dword ptr [edi], 0FFFF00h
	jmp simbol_pixel_next
simbol_pixel_negru:
	mov dword ptr [edi], 0
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_sageti endp

; procedura make_symbol afiseaza un anumit simbol la coordonatele date
; arg1 - simbolul de afisat -> A se vedea fisierul cu simboluri
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
make_symbol proc
	push ebp
	mov ebp, esp
	pusha
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	lea esi, symbol
	mov ebx, dimensiune_simbol
	mul ebx
	mov ebx, dimensiune_simbol
	mul ebx
	add esi, eax
	mov ecx, dimensiune_simbol
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, dimensiune_simbol
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, dimensiune_simbol
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_negru
	cmp byte ptr [esi], 2
	je simbol_pixel_albastru
	cmp byte ptr [esi], 3
	je simbol_pixel_alb
	cmp byte ptr [esi], 4
	je simbol_pixel_roz
	cmp byte ptr [esi], 5
	je simbol_pixel_portocaliu
	cmp byte ptr [esi], 6
	je simbol_pixel_rosu
	mov dword ptr [edi], 0FFFF00h
	jmp simbol_pixel_next
simbol_pixel_negru:
	mov dword ptr [edi], 0
	jmp simbol_pixel_next
simbol_pixel_alb:
	mov dword ptr [edi], 0FFFFFFh
	jmp simbol_pixel_next
simbol_pixel_roz:
	mov dword ptr [edi],0FF1493h
	jmp simbol_pixel_next
simbol_pixel_rosu:
	mov dword ptr [edi], 0FF0000h
	jmp simbol_pixel_next
simbol_pixel_portocaliu:
	mov dword ptr [edi], 0FF8C00h
	jmp simbol_pixel_next
simbol_pixel_albastru:
	mov dword ptr [edi], 00000FFh
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_symbol endp

; macro-uri ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm

make_sageti_macro macro symbol, drawArea, x,y
	push y
	push x
	push drawArea
	push symbol
	call make_sageti
	add esp,16
endm
	
make_symbol_macro macro symbol, drawArea, x,y
	push y
	push x
	push drawArea
	push symbol
	call make_symbol
	add esp,16
endm

;macro-uri pentru liniile orizonalte si verticale
line_horizontal macro x,y,len,color
local bucla_linie
	mov eax,y   ; eax=y
	mov ebx,area_width
	mul ebx		;eax =y*area width
	add eax,x		;eax=y*area_width +x
	shl eax,2		;eax=(y*area_width+x)*4
	add eax,area
	mov ecx, len
bucla_linie:
	mov dword ptr[eax],color
	add eax,4
	loop bucla_linie
endm

line_vertical macro x,y,len,color
local bucla_linie
	mov eax,y   ; eax=y
	mov ebx,area_width
	mul ebx		;eax =y*area width
	add eax,x		;eax=y*area_width +x
	shl eax,2		;eax=(y*area_width+x)*4
	add eax,area
	mov ecx,len
bucla_linie:
	mov dword ptr[eax],color
	add eax,area_width*4
	loop bucla_linie
endm

;macro pentru crearea hartii jocului
creare_harta macro x0,y0
local parcurgere_rand,rand_nou,final
; voi avea nevoie de registre care sa imi memoreze pozitiile din matrice si sa ma ajute sa ma deplasez
; nu pot folosi in mod direct eax si edx, intrucat aceste registre se vor folosi pentru inmultirile necesare parcurgerii matricei

; am incercat sa folosesc registrii pe care ii cunosc, si ca sa ma asigur ca nu o sa am date in plus, am golit registrii folositi la inceput
; si la sfarsit 
	xor ecx,ecx ; va fi folosit pentru parcurgere de linii
	xor ebp,ebp ; va fi folosit pentru parcurgere de coloane
	xor edi,edi ; va reprezenta coordonata X la care se va desena simbolul
	xor esi,esi ; va reprezenta coordonata Y la care se va desena simbolul
	xor eax,eax
	xor edx,edx
	xor ebx,ebx
	parcurgere_rand:
		cmp ecx,nr_linii
		jg final
		cmp ebp,nr_coloane
		jg rand_nou    ; cand ajung la capatul unei coloane, sar la randul nou
		mov eax,ecx
		mov ebx,numar_efectiv_de_coloane    ; este diferit de numarul de coloane, deoarecele coloanele sunt marcate de la 0 la n-1. Astfel nr efectiv va fi n-1+1
		mul ebx    ; aceasta operatie va avea rol atunci cand se trece la randul nou, pentru a stii ce dimensiune trebuie sarita pana acolo
		add eax,ebp
		shl eax,2   ;matrice de DWORD
		mov ebx,eax   ; salvez pozitia la care ma aflu acum, pentru a stii al catelea element trebuie prelucrat
		mov eax,ebp
		mov esi,dimensiune_simbol
		mul esi   ; j*Latime_simbol
		add eax,x0   ; xi,j= x0+ j*latime_simbol
		mov esi,eax  ; esi=xi,j
		mov eax,ecx
		mov edi,dimensiune_simbol
		mul edi   ; i*inaltime_simbol 
		add eax,y0 ; yi,j=y0+i*inaltime simbol
		mov edi,eax ; edi=yi,j
		make_symbol_macro harta[ebx], area, esi, edi
		inc ebp
		jmp parcurgere_rand
		
	rand_nou:
		xor ebp,ebp
		inc ecx
		jmp parcurgere_rand
	final:
		xor eax,eax
		xor ebx,ebx
		xor ecx,ecx
		xor edx,edx
		xor ebp,ebp
		xor esi,esi
		xor edi,edi
endm
;macro folosit la inceperea jocului si la resetarea acestuia
initializare_joc macro
local eticheta_init,am_ales_nivelul,alegere_nivel
	mov begin_game,1
	mov finish,0
	mov vieti,3
	mov counterStart, 0 ; folosit pentru a astepta un interval de timp inainte de a incepe jocul
	mov counterPoints, 0 ; folosit pentru a numara punctele
	mov counterPuncte, 0 ; folosit pentru a manca bilele albe
	mov counterBonus, 0 ; folosit pentru a numara timpul de aparitie al bonusului
	mov counter,0
	mov visina_mancata1,0
	mov visina_mancata2,0
	mov visina_mancata3,0
	resetare
	lea esi, harta_orig
	lea edi, harta
	mov ecx,nivel
	alegere_nivel:
	cmp ecx, 0
	je am_ales_nivelul
	add esi,(nr_linii+1)*(nr_coloane+1)*4
	dec ecx
	jmp alegere_nivel
	am_ales_nivelul:
	mov ecx, (nr_linii+1)*(nr_coloane+1)
eticheta_init:
	mov eax,[esi]
	mov [edi],eax
	add edi,4
	add esi,4
	loop eticheta_init
endm 
resetare macro 
	mov eax,i_initial
	mov edx,j_initial
	mov i,eax
	mov j,edx
	mov move_i,0
	mov move_j,0
	mov eax,i_albastru_initial
	mov edx,j_albastru_initial
	mov i_albastru,eax
	mov j_albastru,edx
	mov eax,i_rosu_initial
	mov edx,j_rosu_initial
	mov i_rosu,eax
	mov j_rosu,edx
	mov eax,i_portocaliu_initial
	mov edx,j_portocaliu_initial
	mov i_portocaliu,eax
	mov j_portocaliu,edx
	mov eax,i_roz_initial
	mov edx,j_roz_initial
	mov i_roz,eax
	mov j_roz,edx
endm
deplasare_ghidata_fantoma macro i_fantoma, j_fantoma, v_fantoma, h_fantoma
local dreapta_fantoma,compara_i_fantoma,jos_fantoma,move_fantoma_right,move_fantoma_up,move_fantoma_left,move_fantoma_down,final, conditie_stop_fantoma_r,conditie_stop_fantoma_u,conditie_stop_fantoma_l,conditie_stop_fantoma_d
;comparam pozitia actuala a fantomei, cu pozitia lui Pacman
	;si in functie de rezultat, alegem pe ce directie sa ne deplasam
	mov ecx,i
	mov edx,j
	cmp j_fantoma,edx
	jle dreapta_fantoma
	mov h_fantoma,-1
	jmp compara_i_fantoma
	dreapta_fantoma:
	mov h_fantoma,1
	compara_i_fantoma:
	cmp i_fantoma,ecx
	jle jos_fantoma
	mov v_fantoma,1
	jmp move_fantoma_right
	jos_fantoma:
	mov v_fantoma,-1
	
	;aici sunt functiile care deplaseaza fantomele, sunt la fel pentru fiecare fantoma
	;difera doar coordonatele pe care le deplaseaza
	;respectiv: daca ma misc in dreapta, voi creste j
	;daca ma misc in stanga, voi descreste j
	;daca ma misc in sus, voi descreste i
	;daca ma misc in jos, voi creste i
	move_fantoma_right:
	cmp h_fantoma,1
	jl move_fantoma_up
	inc j_fantoma
	mov eax,i_fantoma
	mov ebx,numar_efectiv_de_coloane
	mul ebx
	add eax,j_fantoma
	shl eax,2
	mov ebx,eax
	mov edx,j
	inc edx
	cmp j_fantoma,edx
	je conditie_stop_fantoma_r
	cmp harta[ebx],1
	jne final
	conditie_stop_fantoma_r:
	dec j_fantoma
	;eliminam necesitatea de a ne mai deplasa in aceasta directie
	mov ebx,0
	mov h_fantoma,ebx
	
	move_fantoma_up:
	cmp v_fantoma,1
	jl move_fantoma_left
	dec i_fantoma
	mov eax,i_fantoma
	mov ebx,numar_efectiv_de_coloane
	mul ebx
	add eax,j_fantoma
	shl eax,2
	mov ebx,eax
	mov edx,i
	dec edx
	cmp i_fantoma,edx
	je conditie_stop_fantoma_u
	cmp harta[ebx],1
	jne final
	conditie_stop_fantoma_u:
	inc i_fantoma
	mov ebx,0
	mov v_fantoma,ebx
	
	move_fantoma_left:
	cmp h_fantoma,-1
	jg move_fantoma_down
	dec j_fantoma
	mov eax,i_fantoma
	mov ebx,numar_efectiv_de_coloane
	mul ebx
	add eax,j_fantoma
	shl eax,2
	mov ebx,eax
	mov edx,j
	dec edx
	cmp j_fantoma,edx
	je conditie_stop_fantoma_l
	cmp harta[ebx],1
	jne final
	conditie_stop_fantoma_l:
	inc j_fantoma
	mov ebx,0
	mov h_fantoma,ebx
	
	
	move_fantoma_down:
	cmp v_fantoma,-1
	jg final
	inc i_fantoma
	mov eax,i_fantoma
	mov ebx,numar_efectiv_de_coloane
	mul ebx
	add eax,j_fantoma
	shl eax,2
	mov ebx,eax
	mov edx,i
	inc edx
	cmp i_fantoma,edx
	je conditie_stop_fantoma_d
	cmp harta[ebx],1
	jne final
	conditie_stop_fantoma_d:
	dec i_fantoma
	mov ebx,0
	mov v_fantoma,ebx

	final:
endm
	
deplasare_random_fantoma macro i_fantoma, j_fantoma, v_fantoma,h_fantoma
local move_fantoma_right,move_fantoma_left,move_fantoma_down,move_fantoma_up,final

	
	move_fantoma_right:
	cmp h_fantoma,1
	jl move_fantoma_up
	inc j_fantoma
	mov eax,i_fantoma
	mov ebx,numar_efectiv_de_coloane
	mul ebx
	add eax,j_fantoma
	shl eax,2
	mov ebx,eax
	cmp harta[ebx],1
	jne final
	dec j_fantoma
	mov ebx,0
	mov h_fantoma,ebx
	mov ebx,1
	mov v_fantoma,ebx
	
	move_fantoma_up:
	cmp v_fantoma,1
	jl move_fantoma_left
	dec i_fantoma
	mov eax,i_fantoma
	mov ebx,numar_efectiv_de_coloane
	mul ebx
	add eax,j_fantoma
	shl eax,2
	mov ebx,eax
	cmp harta[ebx],1
	jne final
	inc i_fantoma
	mov ebx,-1
	mov h_fantoma,ebx
	mov ebx,0
	mov v_fantoma,ebx
	
	move_fantoma_left:
	cmp h_fantoma,-1
	jg move_fantoma_down
	dec j_fantoma
	mov eax,i_fantoma
	mov ebx,numar_efectiv_de_coloane
	mul ebx
	add eax,j_fantoma
	shl eax,2
	mov ebx,eax
	cmp harta[ebx],1
	jne final
	inc j_fantoma
	mov ebx,0
	mov h_fantoma,ebx
	mov ebx,-1
	mov v_fantoma,ebx
	
	move_fantoma_down:
	cmp v_fantoma,-1
	jg move_fantoma_right
	inc i_fantoma
	mov eax,i_fantoma
	mov ebx,numar_efectiv_de_coloane
	mul ebx
	add eax,j_fantoma
	shl eax,2
	mov ebx,eax
	cmp harta[ebx],1
	jne final
	dec i_fantoma
	mov ebx,1
	mov h_fantoma,ebx
	mov ebx,0
	mov v_fantoma,ebx
	final:
endm
; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click)
; arg2 - x
; arg3 - y
draw proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1]
	cmp eax, 1
	jz evt_click
	cmp eax, 2
	jz evt_timer ; nu s-a efectuat click pe nimic
	;mai jos e codul care intializeaza fereastra cu pixeli albi
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 0 ; fundal negru
	push area
	call memset
	add esp, 12
	jmp afisare_litere
	
evt_click:
	mov eax, [ebp+arg2]
	cmp eax,area_width/2+15
	jl fara_restart
	cmp eax,area_width/2+15+dimensiune_simbol
	jg fara_restart
	mov eax, [ebp+arg3]
	cmp eax,area_height/30+60
	jl fara_restart
	cmp eax,area_height/30+60+dimensiune_simbol
	jg fara_restart
	cmp begin_game,2
	jne fara_restart
	initializare_joc
	make_symbol_macro 7, area, area_width/2+15,area_height/30+60
	fara_restart:
		;verificam daca am dat click intr-unul din patratele cu sageti si verificam ce fel de miscare este nevoie sa executam
		mov eax, [ebp+arg2]
		cmp eax, area_width/25+chenar_width+chenar_width/8+deplasare_width/2
		jl verificare_left
		cmp eax, area_width/25+chenar_width+chenar_width/8+deplasare_width/2+sageti_width+1
		jg verificare_right
		mov eax, [ebp+arg3]
		cmp eax, area_height/4+chenar_height/2+deplasare_height/3
		jl click_fail
		cmp eax, area_height/4+chenar_height/2+deplasare_height/3+sageti_height+1
		jg verificare_down
		
		;punem conditiile necesare pentru a misca Pacman in sus
		mov ebx,1
		mov ecx,0
		mov move_i,ebx
		mov move_j,ecx
		jmp afisare_litere
		
		verificare_left:
		mov eax,[ebp+arg2]
		cmp eax, area_width/25+chenar_width+chenar_width/8+deplasare_width/2-sageti_width-1
		jl click_fail
		cmp eax, area_width/25+chenar_width+chenar_width/8+deplasare_width/2-sageti_width+sageti_width
		jg click_fail
		mov eax,[ebp+arg3]
		cmp eax,area_height/4+chenar_height/2+deplasare_height/3+sageti_height+1
		jl click_fail
		cmp eax,area_height/4+chenar_height/2+deplasare_height/3+2*(sageti_height+1)
		jg click_fail
		
		;punem conditiile necesare pentru a misca Pacman la stanga
		mov ebx,0
		mov ecx,-1
		mov move_i,ebx
		mov move_j,ecx
		jmp afisare_litere
		
		verificare_right:
		mov eax,[ebp+arg2]
		cmp eax, area_width/25+chenar_width+chenar_width/8+deplasare_width/2+sageti_width+1
		jl click_fail
		cmp eax, area_width/25+chenar_width+chenar_width/8+deplasare_width/2+2*(sageti_width+1)
		jg click_fail
		mov eax,[ebp+arg3]
		cmp eax,area_height/4+chenar_height/2+deplasare_height/3+sageti_height+1
		jl click_fail
		cmp eax,area_height/4+chenar_height/2+deplasare_height/3+2*(sageti_height+1)
		jg click_fail
		
		;punem conditiile necesare pentru a misca Pacman la dreapta
		mov ebx,0
		mov ecx,1
		mov move_i,ebx
		mov move_j,ecx
		jmp afisare_litere
		
		verificare_down:
		mov eax,[ebp+arg3]
		cmp eax,area_height/4+chenar_height/2+deplasare_height/3+2*(sageti_height+1)
		jl click_fail
		cmp eax, area_height/4+chenar_height/2+deplasare_height/3+3*(sageti_height+1)
		jg click_fail
		
		;punem conditiile necesare pentru a misca Pacman in jos
		mov ebx,-1
		mov ecx,0
		mov move_i,ebx
		mov move_j,ecx
	
	jmp afisare_litere
click_fail:

		jmp afisare_litere
	
evt_timer:
	cmp begin_game,0
	jne jocul_a_inceput
	initializare_joc
	inc begin_game
	jocul_a_inceput:
;vom verifica daca a fost mancat bonusul de inghetare a timpului
;iar daca da, atunci vom incepe incrementarea timpului de inghetare pana la 6 secunde 
	cmp freeze,0
	je fara_inghetare
	inc freezetime
	cmp freezetime,30
	jne fara_inghetare
	mov freeze,0
	mov freezetime,0
	
	fara_inghetare:
	inc counter
	cmp finish,0 ; daca finish e inca 0, jocul continua
	je joaca
	mov counterStart,0
	jmp afisare_litere
	joaca:
	inc cnt_random
	inc counterStart     ;daca nu s-a atins timpul necesar, se va afisa Get Ready; altfel se pun spatii
	cmp counterStart,10
	
	jge sterge
	make_text_macro 'G', area, area_width/2-20, area_height/30+40
	make_text_macro 'E', area, area_width/2-10, area_height/30+40
	make_text_macro 'T', area, area_width/2, area_height/30+40
	make_text_macro ' ', area, area_width/2+10, area_height/30+40
	make_text_macro ' ', area, area_width/2+20, area_height/30+40
	make_text_macro 'R', area, area_width/2+30, area_height/30+40
	make_text_macro 'E', area, area_width/2+40, area_height/30+40
	make_text_macro 'A', area, area_width/2+50, area_height/30+40
	make_text_macro 'D', area, area_width/2+60, area_height/30+40
	make_text_macro 'Y', area, area_width/2+70, area_height/30+40
	jmp afisare_litere
	
	sterge:
	inc counterBonus
	make_text_macro ' ', area, area_width/2-20, area_height/30+40
	make_text_macro ' ', area, area_width/2-10, area_height/30+40
	make_text_macro ' ', area, area_width/2, area_height/30+40
	make_text_macro ' ', area, area_width/2+10, area_height/30+40
	make_text_macro ' ', area, area_width/2+20, area_height/30+40
	make_text_macro ' ', area, area_width/2+30, area_height/30+40
	make_text_macro ' ', area, area_width/2+40, area_height/30+40
	make_text_macro ' ', area, area_width/2+50, area_height/30+40
	make_text_macro ' ', area, area_width/2+60, area_height/30+40
	make_text_macro ' ', area, area_width/2+70, area_height/30+40
	;verificam daca a fost mancat bonusul de inghetare a fantomelor
	cmp freezetime,0
	jne deplasare_pacman

	;pentru fiecare fantoma se va genera un numar random. Daca acesta este par, atunci fantoma se va deplasa ghidat
	;daca este impar, atunci se va deplasa pseudo-random
	cmp cnt_random,10
	jne fara_modificare_albastru
	rdtsc
	xor edx,edx
	div ZECE
	mov random_albastru,edx
	mov h_albastru,1 ;se reinitializeaza vectorii de deplasare la fiecare noua decizie
	mov v_albastru,0
	
	fara_modificare_albastru:
	cmp cnt_random,20
	jne fara_modificare_rosu
	rdtsc
	xor edx, edx
	div ZECE
	mov random_rosu,edx
	mov h_rosu,1
	mov v_rosu,0
	
	fara_modificare_rosu:
	cmp cnt_random,30
	jne fara_modificare_portocaliu
	rdtsc
	xor edx, edx
	div ZECE
	mov random_portocaliu,edx
	mov h_portocaliu,1
	mov v_portocaliu,0
	
	fara_modificare_portocaliu:
	cmp cnt_random,40
	jne fara_modificare
	mov cnt_random,0
	rdtsc
	xor edx, edx
	div ZECE
	mov random_roz,edx
	mov h_roz,1
	mov v_roz,0
	
	fara_modificare:
	cmp random_albastru,4
	jl deplasare_random_albastru
	deplasare_ghidata_fantoma i_albastru,j_albastru,v_albastru,h_albastru
	jmp deplasare_fantoma_rosu
	deplasare_random_albastru:
	deplasare_random_fantoma i_albastru,j_albastru,v_albastru,h_albastru
	
	
	deplasare_fantoma_rosu:
	cmp random_rosu,4
	jl deplasare_random_rosu
	deplasare_ghidata_fantoma i_rosu,j_rosu,v_rosu,h_rosu
	jmp deplasare_fantoma_portocaliu
	deplasare_random_rosu:
	deplasare_random_fantoma i_rosu,j_rosu,v_rosu,h_rosu
	
	
	deplasare_fantoma_portocaliu:
	cmp random_portocaliu,4
	jl deplasare_random_portocaliu
	deplasare_ghidata_fantoma i_portocaliu,j_portocaliu,v_portocaliu,h_portocaliu
	jmp deplasare_fantoma_roz
	deplasare_random_portocaliu:
	deplasare_random_fantoma i_portocaliu,j_portocaliu,v_portocaliu,h_portocaliu
	
	deplasare_fantoma_roz:
	cmp random_roz,4
	jl deplasare_random_roz
	deplasare_ghidata_fantoma i_roz,j_roz,v_roz,h_roz
	jmp deplasare_pacman
	deplasare_random_roz:
	deplasare_random_fantoma i_roz,j_roz,v_roz,h_roz
	deplasare_pacman:
	; fara_modificare:
	;vom compara prima data daca pozitia pacmanului este aceeasi cu cea a bonusului
	;si in caz afirmativ, vom creste punctajul cu 50
	;daca ajungem pe aceeasi pozitie cu una dintre fantome, atunci vom reseta timer-ul de inceput de joc
	;si vom muta pacman pe pozitia initiala
	mov ebx,i
	mov ecx,j
	
	cmp counterBonus,spawn_visina1
	jl bonus2
	cmp counterBonus,despawn_visina1
	jg bonus2
	cmp visina_mancata1,0
	jg bonus2
	cmp i_visine1,ebx
	jne bonus2
	cmp j_visine1,ecx
	jne bonus2
	mov eax,counterPoints
	add eax,50
	mov counterPoints,eax
	inc visina_mancata1
	
	bonus2:
	cmp counterBonus,spawn_visina2
	jl bonus3
	cmp counterBonus,despawn_visina2
	jg bonus3
	cmp visina_mancata2,0
	jg bonus3
	cmp i_visine2,ebx
	jne bonus3
	cmp j_visine2,ecx
	jne bonus3
	inc freeze
	mov counterPoints,eax
	inc visina_mancata2
	
	bonus3:
	cmp counterBonus,spawn_visina3
	jl compara_roz
	cmp counterBonus,despawn_visina3
	jg compara_roz
	cmp visina_mancata3,0
	jg compara_roz
	cmp i_visine3,ebx
	jne compara_roz
	cmp j_visine3,ecx
	jne compara_roz
	mov eax,counterPoints
	add eax,50
	mov counterPoints,eax
	inc visina_mancata3
	
	compara_roz:
	cmp counterStart,0
	je continua
	cmp i_roz,ebx
	jne compara_portocaliu
	cmp j_roz,ecx
	jne compara_portocaliu
	resetare
	mov move_i,0
	mov move_j,0
	mov counterStart,0
	dec vieti
	
	compara_portocaliu:
	cmp counterStart,0
	je continua
	cmp i_portocaliu,ebx
	jne compara_rosu
	cmp j_portocaliu,ecx
	jne compara_rosu
	resetare
	mov move_i,0
	mov move_j,0
	mov counterStart,0
	dec vieti
	
	compara_rosu:
	cmp counterStart,0
	je continua
	cmp i_rosu,ebx
	jne compara_albastru
	cmp j_rosu,ecx
	jne compara_albastru
	resetare
	mov move_i,0
	mov move_j,0
	mov counterStart,0
	dec vieti
	
	compara_albastru:
	cmp counterStart,0
	je continua
	cmp i_albastru,ebx
	jne continua
	cmp j_albastru,ecx
	jne continua
	resetare
	mov move_i,0
	mov move_j,0
	mov counterStart,0
	dec vieti
	
	continua:
	cmp move_j,1
	jl move_left
	inc j
	mov eax,i
	mov ebx,numar_efectiv_de_coloane    
	mul ebx   
	add eax,j
	shl eax,2   
	mov ebx,eax  
	;verificam daca dam de puncte sau de perete pentru a putea stii 
	;daca e nevoie sa calculam noul punctaj, sau daca ne putem opri din deplasare
	cmp harta[ebx],0
	jne nu_e_punct_r
	mov harta[ebx],7
	inc counterPoints
	inc counterPuncte
	nu_e_punct_r:
	cmp harta[ebx],1
	jne comparare_dupa_miscare
	dec j	
	jmp afisare_litere
	
	move_left:
	cmp move_j,-1
	jg testare_i
	dec j
	mov eax,i
	mov ebx,numar_efectiv_de_coloane
	mul ebx
	add eax,j
	shl eax,2
	mov ebx,eax
	cmp harta[ebx],0
	jne nu_e_punct_l
	mov harta[ebx],7
	inc counterPoints
	inc counterPuncte
	nu_e_punct_l:
	cmp harta[ebx],1
	jne comparare_dupa_miscare
	inc j
	jmp afisare_litere
	testare_i:
	;daca nu avem miscari pe orizontala, verificam daca ne putem misca pe verticala
		cmp move_i,1
		jl move_down
		dec i
		mov eax,i
		mov ebx,numar_efectiv_de_coloane
		mul ebx
		add eax,j
		shl eax,2
		mov ebx,eax
		cmp harta[ebx],0
		jne nu_e_punct_u
		mov harta[ebx],7
		inc counterPoints
		inc counterPuncte
		nu_e_punct_u:
		cmp harta[ebx],1
		jne comparare_dupa_miscare
		inc i
		jmp afisare_litere
	move_down:
		cmp move_i,-1
		jg afisare_litere
		inc i
		mov eax,i
		mov ebx,numar_efectiv_de_coloane
		mul ebx
		add eax,j
		shl eax,2
		mov ebx,eax
		cmp harta[ebx],0
		jne nu_e_punct_d
		mov harta[ebx],7
		inc counterPoints
		inc counterPuncte
		nu_e_punct_d:
		cmp harta[ebx],1
		jne comparare_dupa_miscare
		dec i
		jmp afisare_litere
	;exista cazul in care dupa miscarea pacman-ului, acesta sa fie pe pozitia fantomei, caz in care trebuie facuta o noua verificare!
	comparare_dupa_miscare:
	mov ebx,i
	mov ecx,j
	mov eax,i_initial
	mov edx,j_initial
	
	compara_roz_prim:
	cmp counterStart,0
	je afisare_litere
	cmp i_roz,ebx
	jne compara_portocaliu_prim
	cmp j_roz,ecx
	jne compara_portocaliu_prim
	resetare
	mov move_i,0
	mov move_j,0
	mov counterStart,0
	dec vieti
	
	compara_portocaliu_prim:
	cmp counterStart,0
	je afisare_litere
	cmp i_portocaliu,ebx
	jne compara_rosu_prim
	cmp j_portocaliu,ecx
	jne compara_rosu_prim
	resetare
	mov move_i,0
	mov move_j,0
	mov counterStart,0
	dec vieti
	
	compara_rosu_prim:
	cmp counterStart,0
	je afisare_litere
	cmp i_rosu,ebx
	jne compara_albastru_prim
	cmp j_rosu,ecx
	jne compara_albastru_prim
	resetare
	mov move_i,0
	mov move_j,0
	mov counterStart,0
	dec vieti
	
	compara_albastru_prim:
	cmp counterStart,0
	je afisare_litere
	cmp i_albastru,ebx
	jne afisare_litere
	cmp j_albastru,ecx
	jne afisare_litere
	resetare
	mov move_i,0
	mov move_j,0
	mov counterStart,0
	dec vieti
	
	
afisare_litere:
	;afisam valoarea counter-ului curent (sute, zeci si unitati)
	mov ebx, 10
	mov eax, counter
	;cifra unitatilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 30, 10
	;cifra zecilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 20, 10
	;cifra sutelor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 10, 10
		
	;afisam harta,impreuna cu bonusuri daca am ajuns la momentul potrivit de timp
	;si cu fantome+Pacman
		creare_harta area_width/25,area_height/4
		
		cmp visina_mancata1,0
		jg fara_bonus1
		cmp counterBonus,spawn_visina1
		jl fara_bonus1
		cmp counterBonus,despawn_visina1
		jg fara_bonus1
		mov eax,j_visine1
		mov esi,dimensiune_simbol
		mul esi   ; j*Latime_simbol
		add eax,area_width/25   ; xi,j= x0+ j*latime_simbol
		mov esi,eax  ; esi=xi,j
		mov eax,i_visine1
		mov edi,dimensiune_simbol
		mul edi   ; i*inaltime_simbol 
		add eax,area_height/4 ; yi,j=y0+i*inaltime simbol
		mov edi,eax ; edi=yi,j
		make_symbol_macro 8, area, esi,edi
		
		fara_bonus1:
		
		cmp visina_mancata2,0
		jg fara_bonus2
		cmp counterBonus,spawn_visina2
		jl fara_bonus2
		cmp counterBonus,despawn_visina2
		jg fara_bonus2
		mov eax,j_visine2
		mov esi,dimensiune_simbol
		mul esi   ; j*Latime_simbol
		add eax,area_width/25   ; xi,j= x0+ j*latime_simbol
		mov esi,eax  ; esi=xi,j
		mov eax,i_visine2
		mov edi,dimensiune_simbol
		mul edi   ; i*inaltime_simbol 
		add eax,area_height/4 ; yi,j=y0+i*inaltime simbol
		mov edi,eax ; edi=yi,j
		make_symbol_macro 9, area, esi,edi
		
		fara_bonus2:
		
		cmp visina_mancata3,0
		jg fara_bonus3
		cmp counterBonus,spawn_visina3
		jl fara_bonus3
		cmp counterBonus,despawn_visina3
		jg fara_bonus3
		mov eax,j_visine3
		mov esi,dimensiune_simbol
		mul esi   ; j*Latime_simbol
		add eax,area_width/25   ; xi,j= x0+ j*latime_simbol
		mov esi,eax  ; esi=xi,j
		mov eax,i_visine3
		mov edi,dimensiune_simbol
		mul edi   ; i*inaltime_simbol 
		add eax,area_height/4 ; yi,j=y0+i*inaltime simbol
		mov edi,eax ; edi=yi,j
		make_symbol_macro 8, area, esi,edi
		
		fara_bonus3:
		;afisare pacman
		mov eax,j
		mov esi,dimensiune_simbol
		mul esi   ; j*Latime_simbol
		add eax,area_width/25   ; xi,j= x0+ j*latime_simbol
		mov esi,eax  ; esi=xi,j
		mov eax,i
		mov edi,dimensiune_simbol
		mul edi   ; i*inaltime_simbol 
		add eax,area_height/4 ; yi,j=y0+i*inaltime simbol
		mov edi,eax ; edi=yi,j
		make_symbol_macro 2, area, esi,edi
		;afisare fantoma 1
		mov eax,j_roz
		mov esi,dimensiune_simbol
		mul esi   ; j*Latime_simbol
		add eax,area_width/25   ; xi,j= x0+ j*latime_simbol
		mov esi,eax  ; esi=xi,j
		mov eax,i_roz
		mov edi,dimensiune_simbol
		mul edi   ; i*inaltime_simbol 
		add eax,area_height/4 ; yi,j=y0+i*inaltime simbol
		mov edi,eax ; edi=yi,j
		make_symbol_macro 3, area, esi,edi
		;afisare fantoma 2
		mov eax,j_portocaliu
		mov esi,dimensiune_simbol
		mul esi   ; j*Latime_simbol
		add eax,area_width/25   ; xi,j= x0+ j*latime_simbol
		mov esi,eax  ; esi=xi,j
		mov eax,i_portocaliu
		mov edi,dimensiune_simbol
		mul edi   ; i*inaltime_simbol 
		add eax,area_height/4 ; yi,j=y0+i*inaltime simbol
		mov edi,eax ; edi=yi,j
		make_symbol_macro 4, area, esi,edi
		;afisare fantoma 3
		mov eax,j_rosu
		mov esi,dimensiune_simbol
		mul esi   ; j*Latime_simbol
		add eax,area_width/25   ; xi,j= x0+ j*latime_simbol
		mov esi,eax  ; esi=xi,j
		mov eax,i_rosu
		mov edi,dimensiune_simbol
		mul edi   ; i*inaltime_simbol 
		add eax,area_height/4 ; yi,j=y0+i*inaltime simbol
		mov edi,eax ; edi=yi,j
		make_symbol_macro 5, area, esi,edi
	
		;afisare fantoma 4
		mov eax,j_albastru
		mov esi,dimensiune_simbol
		mul esi   ; j*Latime_simbol
		add eax,area_width/25   ; xi,j= x0+ j*latime_simbol
		mov esi,eax  ; esi=xi,j
		mov eax,i_albastru
		mov edi,dimensiune_simbol
		mul edi   ; i*inaltime_simbol 
		add eax,area_height/4 ; yi,j=y0+i*inaltime simbol
		mov edi,eax ; edi=yi,j
		make_symbol_macro 6, area, esi,edi
		
		
		
	;Afisam titlul jocului 
	make_text_macro 'P', area, area_width/2, area_height/30
	make_text_macro 'A', area, area_width/2+10, area_height/30
	make_text_macro 'C', area, area_width/2+20, area_height/30
	make_text_macro 'M', area, area_width/2+30, area_height/30
	make_text_macro 'A', area, area_width/2+40, area_height/30
	make_text_macro 'N', area, area_width/2+50, area_height/30
	
		;cream chenarul pentru matricea de joc
	line_horizontal area_width/25,area_height/4,chenar_width,0FFFFFFh
	line_horizontal area_width/25,area_height/4 + chenar_height,chenar_width,0FFFFFFh
	line_vertical area_width/25,area_height/4,chenar_height,0FFFFFFh
	line_vertical area_width/25 + chenar_width,area_height/4,chenar_height,0FFFFFFh

		;cream chenarul pentru deplasarea Pacman-ului
	line_horizontal area_width/25+ chenar_width+chenar_width/8, area_height/4+chenar_height/2,deplasare_width,0FFFFFFh
	line_horizontal area_width/25+ chenar_width+chenar_width/8, area_height/4+chenar_height/2+deplasare_height,deplasare_width,0FFFFFFh
	line_vertical area_width/25+chenar_width+chenar_width/8, area_height/4+chenar_height/2, deplasare_height, 0FFFFFFh
	line_vertical area_width/25+chenar_width+chenar_width/8+deplasare_width, area_height/4+chenar_height/2, deplasare_height,0FFFFFFh
	
	make_text_macro 'D', area, area_width/25+chenar_width+chenar_width/8+5,area_height/4+chenar_height/2+5
	make_text_macro 'E', area, area_width/25+chenar_width+chenar_width/8+15,area_height/4+chenar_height/2+5
	make_text_macro 'P', area, area_width/25+chenar_width+chenar_width/8+25,area_height/4+chenar_height/2+5
	make_text_macro 'L', area, area_width/25+chenar_width+chenar_width/8+35,area_height/4+chenar_height/2+5
	make_text_macro 'A', area, area_width/25+chenar_width+chenar_width/8+45,area_height/4+chenar_height/2+5
	make_text_macro 'S', area, area_width/25+chenar_width+chenar_width/8+55,area_height/4+chenar_height/2+5
	make_text_macro 'A', area, area_width/25+chenar_width+chenar_width/8+65,area_height/4+chenar_height/2+5
	make_text_macro 'R', area, area_width/25+chenar_width+chenar_width/8+75,area_height/4+chenar_height/2+5
	make_text_macro 'E', area, area_width/25+chenar_width+chenar_width/8+85,area_height/4+chenar_height/2+5
	
		;cream 4 patrate in care sa punem cate o sageata de deplasare
	line_horizontal area_width/25+ chenar_width+chenar_width/8+deplasare_width/2, area_height/4+chenar_height/2+deplasare_height/3,sageti_width+1,0FFFFFFh
	line_horizontal area_width/25+ chenar_width+chenar_width/8+deplasare_width/2, area_height/4+chenar_height/2+deplasare_height/3+sageti_height+1,sageti_width+1,0FFFFFFh
	line_vertical area_width/25+ chenar_width+chenar_width/8+deplasare_width/2, area_height/4+chenar_height/2+deplasare_height/3,sageti_width+1,0FFFFFFh
	line_vertical area_width/25+ chenar_width+chenar_width/8+deplasare_width/2+sageti_width+1, area_height/4+chenar_height/2+deplasare_height/3,sageti_width+1,0FFFFFFh
	
	 make_sageti_macro 'A', area, area_width/25+chenar_width+chenar_width/8+deplasare_width/2+1,area_height/4+chenar_height/2+deplasare_height/3+1
	 
	line_horizontal area_width/25+ chenar_width+chenar_width/8+deplasare_width/2-sageti_width-1, area_height/4+chenar_height/2+deplasare_height/3+sageti_height+1,sageti_width+1,0FFFFFFh
	line_horizontal area_width/25+ chenar_width+chenar_width/8+deplasare_width/2-sageti_width-1, area_height/4+chenar_height/2+deplasare_height/3+2*(sageti_height+1),sageti_width+1,0FFFFFFh
	line_vertical area_width/25+ chenar_width+chenar_width/8+deplasare_width/2-sageti_width-1, area_height/4+chenar_height/2+deplasare_height/3+sageti_height+1,sageti_width+1,0FFFFFFh
	line_vertical area_width/25+ chenar_width+chenar_width/8+deplasare_width/2, area_height/4+chenar_height/2+deplasare_height/3+sageti_width+1,sageti_height+1,0FFFFFFh
	
	 make_sageti_macro 'C', area, area_width/25+chenar_width+chenar_width/8+deplasare_width/2-sageti_width,area_height/4+chenar_height/2+deplasare_height/3+sageti_height+2
	
	line_horizontal area_width/25+ chenar_width+chenar_width/8+deplasare_width/2+sageti_width+1, area_height/4+chenar_height/2+deplasare_height/3+sageti_height+1,sageti_width+1,0FFFFFFh
	line_horizontal area_width/25+ chenar_width+chenar_width/8+deplasare_width/2+sageti_width+1, area_height/4+chenar_height/2+deplasare_height/3+2*(sageti_height+1),sageti_width+1,0FFFFFFh
	line_vertical area_width/25+ chenar_width+chenar_width/8+deplasare_width/2+sageti_width+1, area_height/4+chenar_height/2+deplasare_height/3+sageti_height+1,sageti_width+1,0FFFFFFh
	line_vertical area_width/25+ chenar_width+chenar_width/8+deplasare_width/2+2*(sageti_width+1), area_height/4+chenar_height/2+deplasare_height/3+sageti_width+1,sageti_height+1,0FFFFFFh
	
	 make_sageti_macro 'B', area, area_width/25+chenar_width+chenar_width/8+deplasare_width/2+sageti_width+2,area_height/4+chenar_height/2+deplasare_height/3+sageti_height+2
	 
	line_horizontal area_width/25+ chenar_width+chenar_width/8+deplasare_width/2, area_height/4+chenar_height/2+deplasare_height/3+2*(sageti_height+1),sageti_width+1,0FFFFFFh
	line_horizontal area_width/25+ chenar_width+chenar_width/8+deplasare_width/2, area_height/4+chenar_height/2+deplasare_height/3+3*(sageti_height+1),sageti_width+1,0FFFFFFh
	line_vertical area_width/25+ chenar_width+chenar_width/8+deplasare_width/2, area_height/4+chenar_height/2+deplasare_height/3+2*(sageti_height+1),sageti_width+1,0FFFFFFh
	line_vertical area_width/25+ chenar_width+chenar_width/8+deplasare_width/2+sageti_width+1, area_height/4+chenar_height/2+deplasare_height/3+2*(sageti_height+1),sageti_width+1,0FFFFFFh
	
	 make_sageti_macro 'D', area, area_width/25+chenar_width+chenar_width/8+deplasare_width/2+1,area_height/4+chenar_height/2+deplasare_height/3+2*(sageti_height+1)+1

		;cream chenarul cu informatii legate de joc
	line_horizontal area_width/25+ chenar_width+chenar_width/8, area_height/4,informatii_width,0FFFFFFh
	line_horizontal area_width/25+ chenar_width+chenar_width/8, area_height/4+informatii_height,informatii_width,0FFFFFFh
	line_vertical area_width/25+chenar_width+chenar_width/8, area_height/4, informatii_height, 0FFFFFFh
	line_vertical area_width/25+chenar_width+chenar_width/8+informatii_width, area_height/4, informatii_height,0FFFFFFh

	make_text_macro 'I', area, area_width/25+chenar_width+chenar_width/8+5,area_height/4+5
	make_text_macro 'N', area, area_width/25+chenar_width+chenar_width/8+15,area_height/4+5
	make_text_macro 'F', area, area_width/25+chenar_width+chenar_width/8+25,area_height/4+5
	make_text_macro 'O', area, area_width/25+chenar_width+chenar_width/8+35,area_height/4+5
	make_text_macro 'R', area, area_width/25+chenar_width+chenar_width/8+45,area_height/4+5
	make_text_macro 'M', area, area_width/25+chenar_width+chenar_width/8+55,area_height/4+5
	make_text_macro 'A', area, area_width/25+chenar_width+chenar_width/8+65,area_height/4+5
	make_text_macro 'T', area, area_width/25+chenar_width+chenar_width/8+75,area_height/4+5
	make_text_macro 'I', area, area_width/25+chenar_width+chenar_width/8+85,area_height/4+5
	make_text_macro 'I', area, area_width/25+chenar_width+chenar_width/8+95,area_height/4+5
	
	make_text_macro 'S', area, area_width/25+chenar_width+chenar_width/8+5,area_height/4+35
	make_text_macro 'C', area, area_width/25+chenar_width+chenar_width/8+15,area_height/4+35
	make_text_macro 'O', area, area_width/25+chenar_width+chenar_width/8+25,area_height/4+35
	make_text_macro 'R', area, area_width/25+chenar_width+chenar_width/8+35,area_height/4+35
	
	;afisam scorul, in mod asemanator cu Counter-ul de timp
	mov ebx, 10
	mov eax, counterPoints
	;cifra unitatilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, area_width/25+chenar_width+chenar_width/8+75,area_height/4+35
	;cifra zecilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, area_width/25+chenar_width+chenar_width/8+65,area_height/4+35
	;cifra sutelor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, area_width/25+chenar_width+chenar_width/8+55,area_height/4+35
	cmp nivel,0
	je verificare_nivel_1
	cmp counterPoints,pointsNivel2
	jne nu_e_gata
	jmp castigare_joc
	verificare_nivel_1:
	cmp counterPuncte,pointsNivel1
	jne nu_e_gata
	castigare_joc:
	inc finish   ;daca s-au mancat toate bilele albe, marcam ca jocul s-a terminat si afisam un mesaj corespunzator
	mov begin_game,2
	make_text_macro 'Y', area, area_width/2-10, area_height/30+40
	make_text_macro 'O', area, area_width/2, area_height/30+40
	make_text_macro 'U', area, area_width/2+10, area_height/30+40
	make_text_macro ' ', area, area_width/2+20, area_height/30+40
	make_text_macro ' ', area, area_width/2+30, area_height/30+40
	make_text_macro 'W', area, area_width/2+40, area_height/30+40
	make_text_macro 'O', area, area_width/2+50, area_height/30+40
	make_text_macro 'N', area, area_width/2+60, area_height/30+40
	make_symbol_macro 10, area, area_width/2+15,area_height/30+60
	inc finish
	mov nivel,1

	nu_e_gata:
	

	
	make_text_macro 'V', area, area_width/25+chenar_width+chenar_width/8+5,area_height/4+65
	make_text_macro 'I', area, area_width/25+chenar_width+chenar_width/8+15,area_height/4+65
	make_text_macro 'E', area, area_width/25+chenar_width+chenar_width/8+25,area_height/4+65
	make_text_macro 'T', area, area_width/25+chenar_width+chenar_width/8+35,area_height/4+65
	make_text_macro 'I', area, area_width/25+chenar_width+chenar_width/8+45,area_height/4+65
	
	make_text_macro 'R', area, area_width/25+chenar_width+chenar_width/8+65,area_height/4+65
	make_text_macro 'A', area, area_width/25+chenar_width+chenar_width/8+75,area_height/4+65
	make_text_macro 'M', area, area_width/25+chenar_width+chenar_width/8+85,area_height/4+65
	make_text_macro 'A', area, area_width/25+chenar_width+chenar_width/8+95,area_height/4+65
	make_text_macro 'S', area, area_width/25+chenar_width+chenar_width/8+105,area_height/4+65
	make_text_macro 'E', area, area_width/25+chenar_width+chenar_width/8+115,area_height/4+65
	cmp vieti,3
	jl vieti_2
	make_text_macro '3', area, area_width/25+chenar_width+chenar_width/8+135,area_height/4+65
	jmp final_draw
	vieti_2:
	cmp vieti,2
	jl vieti_1
	make_text_macro '2', area, area_width/25+chenar_width+chenar_width/8+135,area_height/4+65
	jmp final_draw
	vieti_1:
	cmp vieti,1
	jl vieti_0
	make_text_macro '1', area, area_width/25+chenar_width+chenar_width/8+135,area_height/4+65
	jmp final_draw
	vieti_0:
	make_text_macro '0', area, area_width/25+chenar_width+chenar_width/8+135,area_height/4+65
	inc finish				;daca nu mai avem vieti, marcam faptul ca am ajuns la final si afisam un mesaj corespunzator
	mov begin_game,2
	make_text_macro 'Y', area, area_width/2-20, area_height/30+40
	make_text_macro 'O', area, area_width/2-10, area_height/30+40
	make_text_macro 'U', area, area_width/2, area_height/30+40
	make_text_macro ' ', area, area_width/2+10, area_height/30+40
	make_text_macro ' ', area, area_width/2+20, area_height/30+40
	make_text_macro 'L', area, area_width/2+30, area_height/30+40
	make_text_macro 'O', area, area_width/2+40, area_height/30+40
	make_text_macro 'S', area, area_width/2+50, area_height/30+40
	make_text_macro 'T', area, area_width/2+60, area_height/30+40
	make_symbol_macro 10, area, area_width/2+15,area_height/30+60

	
	
final_draw:
	popa
	mov esp, ebp
	pop ebp
	ret
draw endp

start:
	;alocam memorie pentru zona de desenat
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov area, eax
	;apelam functia de desenare a ferestrei
	; typedef void (*DrawFunc)(int evt, int x, int y);
	; void __cdecl BeginDrawing(const char *title, int width, int height, unsigned int *area, DrawFunc draw);
	push offset draw
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20
	
	;terminarea programului
	push 0
	call exit
end start
