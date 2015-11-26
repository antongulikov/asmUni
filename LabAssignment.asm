; -------------------------------------------------------------------------------------	;
;	Лабораторная работа №2 по курсу Программирование на языке ассемблера				;
;	Вариант №1.5																		;
;	Выполнил студент Гуликов Антон Александрович, 344 группа.																;
;																						;
;	Исходный модуль LabAssignment.asm													;
;	Содержит функции на языке ассемблера, разработанные в соответствии с заданием		;
; -------------------------------------------------------------------------------------	;
;	Задание: Реализовать прямое и обратное преобразования Фурье
;	Формат данных сигнала: __int8
;	Формат данных спектра: double
;	Размер (количество отсчетов) сигнала и спектра: 8
;	Способ реализации: DFT4x4 + 1 бабочка
;	Отсчеты спектра являются комплексными числами. Причем действительные части хранятся
;	в первой половине массива, а мнимые - во второй
; -------------------------------------------------------------------------------------	;
; void CalculateSpectrum(spectrum_type* Spectrum, signal_type* Signal)					;
;	Прямое преобразование Фурье. Вычисляет спектр Spectrum по сигналу Signal			;
;	Типы данных spectrum_type и signal_type, а так же разимер сигнала					;
;	определяются в файле Tuning.h														;
; -------------------------------------------------------------------------------------	;
;
; ---------------------------------------------------------------------------------------;
; Как будем решать :
; Для начала посчитаем DFT 4x4 для четных позиций и для нечетных
;     (1,  1,  1,  1)   (a[0])
;     (1, -j, -1,  j)   (a[2])
; X = (1, -1,  1, -1) * (a[4])  =>
;     (1,  j, -1, -j)   (a[6])
;
; А потом сделаем бабочку
.DATA
re1 real8 1., 0., -1., 0. ; Нужнаые нам вектора транпонированной матрицы dft4*4, для преобразований
re2 real8 1., -1., 1., -1.
im1 real8 0., -1., 0., 1.
im2 real8 0., 1., 0., -1.
br1 real8 1., 0.7071067812, 0., -0.7071067812 ; rbr1 = br1
br2 real8 -1., -0.7071067812, 0., 0.7071067812 ; rbr2 = br2
bi1 real8 0., -0.7071067812, -1., -0.7071067812;
bi2 real8 0., 0.7071067812, 1., 0.7071067812

zero real8 0.
eight real8 8.0
two real8 2.0
minus real8 -1., -1., -1., -1.
eightd real8 0.125, 0.125, 0.125, 0.125

.CODE
; -------------------------------------------------------------------------------------	;
; void CalculateSpectrum(spectrum_type* Spectrum, signal_type* Signal)					;
;	Прямое преобразование Фурье. Вычисляет спектр Spectrum по сигналу Signal			;
;	Типы данных spectrum_type и signal_type, а так же разимер сигнала					;
;	определяются в файле Tuning.h														;
; -------------------------------------------------------------------------------------	;
CalculateSpectrum PROC	; [RCX] - Spectrum	
						; [RDX] - Signal

	sub rsp, 32*8
	vmovdqu ymmword ptr[rsp + 32*0], ymm6		; сохраним все регистры
	vmovdqu ymmword ptr[rsp + 32*1], ymm7
	vmovdqu ymmword ptr[rsp + 32*2], ymm8
	vmovdqu ymmword ptr[rsp + 32*3], ymm9
	vmovdqu ymmword ptr[rsp + 32*4], ymm10
	vmovdqu ymmword ptr[rsp + 32*5], ymm11
	vmovdqu ymmword ptr[rsp + 32*6], ymm12
	vmovdqu ymmword ptr[rsp + 32*7], ymm13
	
	vzeroall									;обнулим все регистры	


	vpmovsxbd xmm0, dword ptr[rdx]
	vcvtdq2pd ymm0, xmm0						; ymm0 = (a[0], a[1], a[2], a[3])

		; ymm6 - вещественная часть преобразовни четных ymm7 - мнимая часть преобразования чечтных
	; ymm8 -      -//-                     нечетных ymm9 -               -//-          нечетных

	; Сделаем dft 4 * 4

	vpermpd ymm1, ymm0, 00000000b	 ; ymm1 (a[0] * 4)
	vaddpd ymm6, ymm6, ymm1
		
	vpermpd ymm1, ymm0, 01010101b    ; ymm1 (a[1] * 4)
	vaddpd ymm8, ymm8, ymm1

	vpermpd ymm1, ymm0, 10101010b    ; ymm1 (a[2] * 4)
	vfmadd231pd ymm6, ymm1, re1
	vfmadd231pd ymm7, ymm1, im1

	vpermpd ymm1, ymm0, 11111111b	 ; ymm1 (a[3] * 4)
	vfmadd231pd ymm8, ymm1, re1
	vfmadd231pd ymm9, ymm1, im1

	vpmovsxbd xmm0, dword ptr[rdx + 4]
	vcvtdq2pd ymm0, xmm0						; ymm0 = (a[4], a[5], a[6], a[7])

	vpermpd ymm1, ymm0, 00000000b	; ymm1 (a[4] * 4)
	vfmadd231pd ymm6, ymm1, re2

	vpermpd ymm1, ymm0, 01010101b	; ymm1 (a[5] * 4)
	vfmadd231pd ymm8, ymm1, re2

	vpermpd ymm1, ymm0, 10101010b	; ymm1 (a[6] * 4)
	vfmadd231pd ymm6, ymm1, re1
	vfmadd231pd ymm7, ymm1, im2

	vpermpd ymm1, ymm0, 11111111b	; ymm1 (a[7] * 4)
	vfmadd231pd ymm8, ymm1, re1
	vfmadd231pd ymm9, ymm1, im2

	; Ура. Осталось сделать бабочку =)

	vaddpd ymm10, ymm10, ymm6      ; Первые четыре числа вещественной части
	vaddpd ymm12, ymm12, ymm6	   ; Следующие четыре числа вещественной части	
	vaddpd ymm11, ymm11, ymm7      ; То же самое для мнимой
	vaddpd ymm13, ymm13, ymm7	

	vfmadd231pd ymm10, ymm8, br1   ; Бабочка для первой половины ; a
	vfmsub231pd ymm10, ymm9, bi1								 ; ?	
	
	vfmadd231pd ymm11, ymm8, bi1								; ?
	vfmadd231pd ymm11, ymm9, br1								; ?
									
	vfmadd231pd ymm12, ymm8, br2   ; Бабочка для второй половины
	vfmsub231pd ymm12, ymm9, bi2
	
	vfmadd231pd ymm13, ymm8, bi2
	vfmadd231pd ymm13, ymm9, br2

	vmulpd ymm10, ymm10, minus		 
	vmulpd ymm12, ymm12, minus
	
	
	vmovupd real8 ptr[rcx], ymm10
	vmovupd real8 ptr[rcx + 4 * 8], ymm12	
	vmovupd real8 ptr[rcx + 8 * 8], ymm11	
	vmovupd real8 ptr[rcx + 12 * 8], ymm13	

	vzeroall									; обнулим все регистры 
	vmovdqu ymm6, ymmword ptr[rsp + 32*0]
	vmovdqu ymm7, ymmword ptr[rsp + 32*1]
	vmovdqu ymm8, ymmword ptr[rsp + 32*2]
	vmovdqu ymm9, ymmword ptr[rsp + 32*3]
	vmovdqu ymm10, ymmword ptr[rsp + 32*4]
	vmovdqu ymm11, ymmword ptr[rsp + 32*5]
	vmovdqu ymm12, ymmword ptr[rsp + 32*6]
	vmovdqu ymm13, ymmword ptr[rsp + 32*7]
	add rsp, 32*8
	ret
CalculateSpectrum ENDP
; -------------------------------------------------------------------------------------	;
; void RecoverSignal(signal_type* Signal, spectrum_type* Spectrum)						;
;	Обратное преобразование Фурье. Вычисляет сигнал Signal по спектру Spectrum			;
;	Типы данных spectrum_type и signal_type, а так же размер сигнала					;
;	определяются в файле Tuning.h														;
; -------------------------------------------------------------------------------------	;
RecoverSignal PROC	; [RCX] - Signal
					; [RDX] - Spectrum

; Делаем обратное преобразование
;     (1,  1,  1,  1)   (a[0] + j * a[8])
;     (1,  j, -1, -j)   (a[2] + j * a[10])
; X = (1, -1,  1, -1) * (a[4] + j * a[12])  =>
;     (1, -j, -1,  j)   (a[6] + j * a[14])
;
; А потом бабочку

	sub rsp, 32*8
	vmovdqu ymmword ptr[rsp + 32*0], ymm6		; сохраним все регистры
	vmovdqu ymmword ptr[rsp + 32*1], ymm7
	vmovdqu ymmword ptr[rsp + 32*2], ymm8
	vmovdqu ymmword ptr[rsp + 32*3], ymm9
	vmovdqu ymmword ptr[rsp + 32*4], ymm10
	vmovdqu ymmword ptr[rsp + 32*5], ymm11
	vmovdqu ymmword ptr[rsp + 32*6], ymm12
	vmovdqu ymmword ptr[rsp + 32*7], ymm13
	
	vzeroall									;обнулим все регистры	

	; Будем брать по элементику и умножать его на матричку
	; Как и в прошлый раз в ymm6, ymm7, ymm8, ymm9 - Все для тех же целей

	vmovdqu ymm0, ymmword ptr[rdx]				; ymm0 - (x[0], x[1], x[2], x[3])
	vmovdqu ymm1, ymmword ptr[rdx + 4 * 8]		; ymm1 - (x[4], x[5], x[6], x[7])
	vmovdqu ymm2, ymmword ptr[rdx + 8 * 8]		; ymm2 - j * (x[8], x[9], x[10], x[11])
	vmovdqu ymm3, ymmword ptr[rdx + 12 * 8]     ; ymm3 - j * (x[12], x[13], x[14], x[15])


	vpermpd ymm4, ymm0, 00000000b				; ymm4 - (x[0] * 4)
	vaddpd ymm6, ymm6, ymm4
	
	vpermpd ymm4, ymm0, 01010101b				; ymm4 - (x[1] * 4)
	vaddpd ymm8, ymm8, ymm4

	vpermpd ymm4, ymm0, 10101010b				; ymm4 - (x[2] * 4)
	vfmadd231pd ymm6, ymm4, re1
	vfmadd231pd ymm7, ymm4, im2

	vpermpd ymm4, ymm0, 11111111b				; ymm4 - (x[3] * 4)
	vfmadd231pd ymm8, ymm4, re1
	vfmadd231pd ymm9, ymm4, im2

	vpermpd ymm4, ymm1, 00000000b				; ymm4 - (x[4] * 4)
	vfmadd231pd ymm6, ymm4, re2

	vpermpd ymm4, ymm1, 01010101b				; ymm4 - (x[5] * 4)
	vfmadd231pd ymm8, ymm4, re2

	vpermpd ymm4, ymm1, 10101010b				; ymm4 - (x[6] * 4)
	vfmadd231pd ymm6, ymm4, re1
	vfmadd231pd ymm7, ymm4, im1

	vpermpd ymm4, ymm1, 11111111b				; ymm4 - (x[7] * 4)
	vfmadd231pd ymm8, ymm4, re1
	vfmadd231pd ymm9, ymm4, im1

	vpermpd ymm4, ymm2, 00000000b				; ymm4 - j * (x[8] * 4)
	vaddpd ymm7, ymm7, ymm4

	vpermpd ymm4, ymm2, 01010101b				; ymm4 - j * (x[9] * 4)
	vaddpd ymm9, ymm9, ymm4

	vpermpd ymm4, ymm2, 10101010b				; ymm4 - j * (x[10] * 4)
	vfmadd231pd ymm7, ymm4, re1
	vfmsub231pd ymm6, ymm4, im2

	vpermpd ymm4, ymm2, 11111111b				; ymm4 - j * (x[11] * 4)
	vfmadd231pd ymm9, ymm4, re1
	vfmsub231pd ymm8, ymm4, im2

	vpermpd ymm4, ymm3, 00000000b				; ymm4 - j * (x[12] * 4)
	vfmadd231pd ymm7, ymm4, re2

	vpermpd ymm4, ymm3, 01010101b				; ymm4 - j * (x[13] * 4)
	vfmadd231pd ymm9, ymm4, re2

	vpermpd ymm4, ymm3, 10101010b				; ymm4 - j * (x[14] * 4)
	vfmadd231pd ymm7, ymm4, re1
	vfmsub231pd ymm6, ymm4, im2

	vpermpd ymm4, ymm3, 11111111b				; ymm4 - j * (x[15] * 4)
	vfmadd231pd ymm9, ymm4, re1
	vfmsub231pd ymm8, ymm4, im2

	vaddpd ymm10, ymm10, ymm6      ; Первые четыре числа вещественной части
	vaddpd ymm12, ymm12, ymm6	   ; Следующие четыре числа вещественной части	
		

	vfmadd231pd ymm10, ymm8, br1   ; Бабочка для первой половины ; 
	vfmsub231pd ymm10, ymm9, bi2								 
		
	vfmadd231pd ymm12, ymm8, br2   ; Бабочка для второй половины
	vfmsub231pd ymm12, ymm9, bi1

	vmulpd ymm12, ymm12, eightd
	vmulpd ymm10, ymm10, eightd	

	vmulpd ymm10, ymm10, minus		 
	vmulpd ymm12, ymm12, minus

	vcvtpd2dq xmm10, ymm10
	vcvtpd2dq xmm12, ymm12

	vpackssdw xmm10, xmm10, xmm12
	vpacksswb xmm10, xmm10, xmm10

	vmovq qword ptr[rcx], xmm10
	

	vzeroall									; обнулим все регистры 
	vmovdqu ymm6, ymmword ptr[rsp + 32*0]
	vmovdqu ymm7, ymmword ptr[rsp + 32*1]
	vmovdqu ymm8, ymmword ptr[rsp + 32*2]
	vmovdqu ymm9, ymmword ptr[rsp + 32*3]
	vmovdqu ymm10, ymmword ptr[rsp + 32*4]
	vmovdqu ymm11, ymmword ptr[rsp + 32*5]
	vmovdqu ymm12, ymmword ptr[rsp + 32*6]
	vmovdqu ymm13, ymmword ptr[rsp + 32*7]
	add rsp, 32*8
ret
   
RecoverSignal ENDP
END
