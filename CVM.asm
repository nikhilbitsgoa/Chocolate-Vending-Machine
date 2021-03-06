
#make_bin#

#LOAD_SEGMENT=FFFFh#
#LOAD_OFFSET=0000h#

#CS=0000h#
#IP=0000h#

#DS=0000h#
#ES=0000h#

#SS=0000h#
#SP=FFFEh#

#AX=0000h#
#BX=0000h#
#CX=0000h#
#DX=0000h#
#SI=0000h#
#DI=0000h#
#BP=0000h#

.model tiny

.data
org	00

; keypad lookup table
keypad_table	db	060h,050h,030h
keypad_table_length	equ	3

; port addresses of 8255
porta equ 10h
portb equ 12h
portc equ 14h
ctrl_addr equ 16h
io_mode equ 80h

;delay and keyboard variables
keypressed	db	?
delay20mscount	equ	1000h

; key ids
keyid_dairy_milk	equ 	1
keyid_five_star		equ		2
keyid_perk			equ		3


; stack
stack1		dw	100 dup(0)
top_stack1	label	word

;pressure sensor variables
is_valid db ?
no_of_coins db ?
pressure_offset equ 13
pressure_limit equ 14
pressure_limit_plus_offset equ 28   ;max coins=14,offset=13,+1(in-valid input from 15 coins onwards)

;state variables
state_porta db ?
state_portb db ?
state_portc db ?
state_control_register db ?

;validity condition variables
is_insufficient db 4 ; if set less than 4 then the chocolate id is insufficient
coins_for_dairy_milk equ 4
coins_for_five_star equ 2
coins_for_perk equ 1
num_of_chocs db 0
num_of_dairy_milk_left db 30
num_of_five_star_left db 30
num_of_perk_left db 30

;stepper motor rotation sequence variables
stepper_motor_sequence1 equ 00000100b			;motor sequence with pb2=1
stepper_motor_sequence2 equ 00001000b			;motor sequence with pb3=1
stepper_motor_sequence3 equ 00010000b			;motor sequence with pb4=1
stepper_motor_sequence4 equ 00100000b			;motor sequence with pb5=1 


.code
.startup
		; intialize ds, es,ss to start of ram
          mov       ax,0200h
          mov       ds,ax
          mov       es,ax
          mov       ss,ax
          mov       sp,0fffeh
          mov       si,0000 
		  
		  
		mov al,00010111b
		out 1eh,al             ;initialising 8253 to generate clock for adc
		mov al,05h
		out 18h,al   
		main1: 


			call glow_nothing
			
			
			;get the key pressed in the variable keypressed
			call get_key_pressed
			
			cmp keypressed,keyid_dairy_milk
			jnz x1
			jmp x3
			x1:
				cmp keypressed,keyid_five_star
				jnz x2
				jmp x3
			x2:
				cmp keypressed,keyid_perk
				jnz x3
				
			x3:
				call restore_ports
				call glow_nothing
			
			;start sensing pressure
			call sense_input_pressure
			
			
			
			;check if the number of coins exceed or not
				cmp is_valid,00h
				jz main1    ; if yes then discard and start fresh
				; else go to main2 where you see the key press.
		main2:
			;check for the validity as well as the multiplicity
			call validity_check_after_keypress
			
			;check if the number of coins is integral multiple or not
				cmp is_valid,00h
				jnz main3				; if yes then discard and start fresh
main1_before:	call glow_invalid
				call delay_20ms
				jmp main1
				; else go to start motor to dispense the chocolates
			
		main3:
			;if the chocolates are not sufficient then go back
				cmp is_insufficient,4
				jge main4
				call glow_insufficient
				jmp main_end
				
		main4:
				call start_motor
		
		main_end:
			    jmp main1
			
.exit
glow_five_star proc near
		pushf
		push	ax
		push	bx
		push	cx
		push	dx


	;set pb1 to 1 and pb0 to 1
		mov al,10011000b
		out ctrl_addr,al
		mov al, 00000011b
		out portb,al
		mov al,00001000b
		out portc,al
		
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		popf
		
		ret

glow_five_star endp

glow_dairy_milk proc near
		pushf
		push	ax
		push	bx
		push	cx
		push	dx


	;set pb1 to 1 and pb0 to 0
		mov al,10011000b
		out ctrl_addr,al
		mov al, 00000010b
		out portb,al
		mov al,00001000b
		out portc,al
		
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		popf
		
		ret

glow_dairy_milk endp

glow_invalid proc near
		pushf
		push	ax
		push	bx
		push	cx
		push	dx
	
	
	;set pb1 to 0 and pb0 to 0
		mov al,10011000b
		out ctrl_addr,al
		mov al, 00000000b
		out portb,al
		mov al,00001000b
		out portc,al
		
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		popf
		
		ret

glow_invalid endp

glow_perk proc near
		pushf
		push	ax
		push	bx
		push	cx
		push	dx

	;set pb1 to 0 and pb0 to 1
		mov al,10011000b
		out ctrl_addr,al
		mov al, 00000001b
		out portb,al
		mov al,00001000b
		out portc,al

		pop	dx
		pop	cx
		pop	bx
		pop	ax
		popf
		
		ret

glow_perk endp

delay_20ms	proc	near
		pushf
		push	ax
		push	bx
		push	cx
		push	dx
		
		mov	cx, delay20mscount						; machine cycles count for 20ms
x_delayloop:	nop
		nop
		nop
		nop
		nop
		loop	x_delayloop
		
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		popf
		
		ret
delay_20ms	endp

get_key_pressed proc near
		
		pushf
		push	ax
		push	bx
		push	cx
		push	dx
		
		;setting 8255 pc lower(0-3) as output and pc upper(4-7) is input
		mov al,10011000b
		out ctrl_addr,al
		;check for key release
		xxx0:
				mov al,01110000b
				out portc,al
		; checking if all keys are released
		xxx1:	in  al,portc
				and al,70h
				cmp al,70h
				jnz xxx1		
				call delay_20ms
					
				mov al,01110000b
				out portc,al
		; checking for key pressed
		xxx2:		in al,portc
					and al,70h
					cmp al,70h
					jz xxx2		
					call delay_20ms
					; decoding key pressed
					mov al,01110000b
					out portc,al
					in al,portc
					and al,70h
					cmp al,70h		
					jz xxx2
					call delay_20ms
		
		xxx3:
					cmp al,keypad_table[0]
					jnz xxx4
					mov keypressed,keyid_dairy_milk
					jmp get_key_pressed_end
		xxx4:
					cmp al,keypad_table[1]
					jnz xxx5
					mov keypressed,keyid_five_star
					jmp get_key_pressed_end
		xxx5:
					cmp al,keypad_table[2]
					jnz get_key_pressed_end
					mov keypressed,keyid_perk
					jmp get_key_pressed_end
		get_key_pressed_end:
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		popf
		ret
get_key_pressed endp

restore_ports proc near

		pushf
		push	ax
		push	bx
		push	cx
		push	dx

		mov al,80h
		out ctrl_addr,al
		
		mov al,00h
		out porta,al
		
		
		mov al,80h
		out ctrl_addr,al
		mov al,00000000b
		out portb,al
		
		
		mov al,80h
		out ctrl_addr,al
		mov al,00000000b
		out portc,al
		
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		popf
		
		ret
restore_ports endp

;call this procedure before any procedure or inside any procedure that has a possibility of changing the state of ports.
store_state_of_ports proc near
		pushf
		push	ax
		push	bx
		push	cx
		push	dx

		in al,ctrl_addr
		mov state_control_register,al
		in al,porta
		mov state_porta,al
		in al,portb
		mov state_portb,al
		in al,portc
		mov state_portc,al

		pop	dx
		pop	cx
		pop	bx
		pop	ax
		popf
		
		ret	
store_state_of_ports endp

;call this procedure after any procedure that has a possibility of changing the state of ports.
revert_state_of_ports proc near
		pushf
		push	ax
		push	bx
		push	cx
		push	dx

		mov al,state_control_register
		out ctrl_addr,al
		mov al,state_porta
		out porta,al
		mov al,state_portb
		out portb,al
		mov al,state_portc
		out portc,al

		pop	dx
		pop	cx
		pop	bx
		pop	ax
		popf
		
		ret		
revert_state_of_ports endp

sense_input_pressure proc near
			pushf
			push	ax
			push	bx
			push	cx
			push	dx
			

			
						;send start of conversion signal to adc along with address of analog input channel to activate
								mov al,10011000b  		;setting portc upper(4-7) as input and portc lower(0-3) as output,porta as input,portb as output
								out ctrl_addr,al
								;making it low to high
								
								mov al,00000000b		;setting pc1(soc) to 0,pc0 to 0
								out portc,al
								call delay_20ms
								
								mov al,10011000b  		;setting portc upper(4-7) as input and portc lower(0-3) as output,porta as input,portb as output
								out ctrl_addr,al
								mov al,00000010b		;setting pc1(soc) to 1,pc0 to 0
								out portc,al
								
								call delay_20ms
								
								mov al,10011000b  		;setting portc upper(4-7) as input and portc lower(0-3) as output,porta as input,portb as output
								out ctrl_addr,al
								mov al,00h				;setting pb6,pb7 to 0,0
								out portb,al
						;giving conversion time to adc
						;right now giving a longer delay(20ms) rather than only conversion time of adc(100us)
						;check for end of conversion signal from adc
								
								
eoc_check:						
								mov al,10011000b  		;setting portc upper(4-7) as input and portc lower(0-3) as output,porta as input,portb as output
								out ctrl_addr,al
								in al,portc
								mov bl,al
								and bl,10000000b
								cmp bl,00h
								jz eoc_done
								jmp eoc_check
								
						;conversion complete move to taking input from adc
eoc_done:						mov al,10011000b  		;setting portc upper(4-7) as input and portc lower(0-3) as output,porta as input,portb as output
								out ctrl_addr,al
								in al,porta				;taking d0-d7 from adc into porta and then into al for further processing.
						
						;to check validity of input by examining d0-d7 sequence
						mov al,10011000b  		;setting portc upper(4-7) as input and portc lower(0-3) as output,porta as input,portb as output
						out ctrl_addr,al
						in al,porta				;taking d0-d7 from adc into porta and then into al for further processing.

						
						cmp al,pressure_limit_plus_offset
						jge pressure_limit_exceed
						cmp al,00h
						je pressure_limit_fall_short
						mov is_valid,01h
						mov bl,al
						sub bl,pressure_offset 
						mov no_of_coins,bl
						jmp pressure_finish
pressure_limit_exceed:	mov is_valid,00h
						mov no_of_coins,00h
						jmp pressure_finish
pressure_limit_fall_short: mov is_valid,00h
						mov no_of_coins,00h
pressure_finish:
	
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		popf
		
		ret		
sense_input_pressure endp

validity_check_after_keypress proc near
		pushf
		push	ax
		push	bx
		push	cx
		push	dx
		
		; get number of coins for the key pressed
		dairy_milk_pressed:
			cmp keypressed,keyid_dairy_milk
			jnz five_star_pressed
			mov cl,coins_for_dairy_milk
			mov al,no_of_coins
			mov ch,00h
		    mov al,no_of_coins
		    mov ah,00h
		
		     ;check if the number of coins is the integral multiple of the key pressed
	      	div cl             ; al = ax/cl, ah = remainder
		
		;compare the remainder
		    cmp ah,00h
			jz set_it_valid1
			mov is_valid,00h
			jmp validity_end
			
			set_it_valid1:
			mov is_valid,01h
			mov num_of_chocs,al
			sub num_of_dairy_milk_left,al
			cmp num_of_dairy_milk_left,00h
			jge	validity_end
			call glow_dairy_milk
			mov is_insufficient,keyid_dairy_milk
			add num_of_dairy_milk_left,al
			jmp validity_end
			
		
		five_star_pressed:
			cmp keypressed,keyid_five_star
			jnz perk_pressed
			mov cl,coins_for_five_star
			mov al,no_of_coins
			mov al,no_of_coins
			mov ch,00h
		    mov al,no_of_coins
		    mov ah,00h
		
		     ;check if the number of coins is the integral multiple of the key pressed
	      	div cl             ; al = ax/cl, ah = remainder
		
		;compare the remainder
		    cmp ah,00h
			jz set_it_valid2
			mov is_valid,00h
			jmp validity_end
			
			set_it_valid2:
			mov is_valid,01h
			mov num_of_chocs,al
			sub num_of_five_star_left,al
			cmp num_of_five_star_left,00h
			jge	validity_end
			call glow_five_star
			mov is_insufficient,keyid_five_star
			add num_of_five_star_left,al
			jmp validity_end
		
		perk_pressed:
			mov is_valid,00h
			cmp keypressed,keyid_perk
			jnz validity_end
			mov cl,coins_for_perk
			mov al,no_of_coins
			mov al,no_of_coins
			mov ch,00h
		    mov al,no_of_coins
		    mov ah,00h
		
		     ;check if the number of coins is the integral multiple of the key pressed
	      	div cl             ; al = ax/cl, ah = remainder
		
		;compare the remainder
		    cmp ah,00h
			jz set_it_valid3
			mov is_valid,00h
			jmp validity_end
			set_it_valid3:
			mov is_valid,01h
			mov num_of_chocs,al
			sub num_of_perk_left,al
			cmp num_of_perk_left,00h
			jge	validity_end
			call glow_perk
			mov is_insufficient,keyid_perk
			add num_of_perk_left,al
			jmp validity_end
		after_chocolate_selected:
			mov is_valid,01h
		
		mov ch,00h
		mov al,no_of_coins
		mov ah,00h
		
		;check if the number of coins is the integral multiple of the key pressed
		div cl             ; al = ax/cl, ah = remainder
		
		;compare the remainder
		cmp ah,00h
		jz set_it_valid
		mov is_valid,00h
		
		set_it_valid:
		mov is_valid,01h
		mov num_of_chocs,al
		validity_end:
		
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		popf
		
		ret		

validity_check_after_keypress endp

start_motor proc near
		
		pushf
		push	ax
		push	bx
		push	cx
		push	dx
		
		; now dummy glow led the number of time the chocolates are ordedairy_milk
		mov cl,num_of_chocs
		mov ch,00h
		
		start_motor1:
			call stepper_motor_open
			call delay_20ms
			call stepper_motor_close
			loop start_motor1

motorend:
        			

		pop	dx
		pop	cx
		pop	bx
		pop	ax
		popf
		
		ret		
start_motor endp

glow_nothing proc near
		
		pushf
		push	ax
		push	bx
		push	cx
		push	dx
		
		mov al,80h
		out ctrl_addr,al
		mov al,00000000b
		out portc,al
		
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		popf
		
		ret		

glow_nothing endp

glow_insufficient proc near

		pushf
		push	ax
		push	bx
		push	cx
		push	dx
		
		call glow_nothing
		
		cmp is_insufficient,keyid_dairy_milk
		jnz glow_insufficient1
		call glow_dairy_milk
		jmp glow_insufficient_end
		
		glow_insufficient1:
		cmp is_insufficient,keyid_five_star
		jnz glow_insufficient2
		call glow_five_star
		jmp glow_insufficient_end
		
		glow_insufficient2:
		cmp is_insufficient,keyid_perk
		jnz glow_insufficient_end
		call glow_perk
		jmp glow_insufficient_end
		
		glow_insufficient_end:
		call delay_20ms
		call delay_20ms
		call glow_nothing
		
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		popf
		
		ret	
glow_insufficient endp

stepper_motor_open proc near
;give the sequence to stepper motor such that at a time one input is 1,others are 0.
;clockwise rotation is taken as opening of motor slot.

		pushf
		push	ax
		push	bx
		push	cx
		push	dx

		mov al,10011000b  		;setting portc upper(4-7) as input and portc lower(0-3) as output,porta as input,portb as output
		out ctrl_addr,al
		;to disable the decoder putting pc3=0
		in al,portc
		mov dl,al
		mov bl,dl
		and bl,11110111b
		mov al,bl
		out portc,al
		mov al,10011000b  		;setting portc upper(4-7) as input and portc lower(0-3) as output,porta as input,portb as output
		out ctrl_addr,al
		mov al,stepper_motor_sequence1
		out portb,al
		call delay_20ms
		
		mov al,10011000b  		;setting portc upper(4-7) as input and portc lower(0-3) as output,porta as input,portb as output
		out ctrl_addr,al
		mov al,stepper_motor_sequence2
		out portb,al
		call delay_20ms
		mov al,10011000b  		;setting portc upper(4-7) as input and portc lower(0-3) as output,porta as input,portb as output
		out ctrl_addr,al
		mov al,stepper_motor_sequence3
		out portb,al
		call delay_20ms
		mov al,10011000b  		;setting portc upper(4-7) as input and portc lower(0-3) as output,porta as input,portb as output
		out ctrl_addr,al
		mov al,stepper_motor_sequence4
		out portb,al
		call delay_20ms
		mov al,10011000b  		;setting portc upper(4-7) as input and portc lower(0-3) as output,porta as input,portb as output
		out ctrl_addr,al
		mov al,dl
		out portc,al
		
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		popf
		
		ret

stepper_motor_open endp

stepper_motor_close proc near
;give the sequence to stepper motor such that at a time one input is 1,others are 0.
;anti-clockwise rotation is taken as closing of motor slot.

		pushf
		push	ax
		push	bx
		push	cx
		push	dx

		mov al,10011000b  		;setting portc upper(4-7) as input and portc lower(0-3) as output,porta as input,portb as output
		out ctrl_addr,al
		;to disable the decoder putting pc3=0
		in al,portc
		mov dl,al
		mov bl,dl
		and bl,11110111b
		mov al,bl
		out portc,al
		mov al,10011000b  		;setting portc upper(4-7) as input and portc lower(0-3) as output,porta as input,portb as output
		out ctrl_addr,al
		mov al,stepper_motor_sequence3
		out portb,al
		call delay_20ms
		mov al,10011000b  		;setting portc upper(4-7) as input and portc lower(0-3) as output,porta as input,portb as output
		out ctrl_addr,al
		mov al,stepper_motor_sequence1
		out portb,al
		call delay_20ms
		mov al,10011000b  		;setting portc upper(4-7) as input and portc lower(0-3) as output,porta as input,portb as output
		out ctrl_addr,al
		mov al,stepper_motor_sequence4
		out portb,al
		call delay_20ms
		mov al,10011000b  		;setting portc upper(4-7) as input and portc lower(0-3) as output,porta as input,portb as output
		out ctrl_addr,al
		mov al,stepper_motor_sequence3
		out portb,al
		call delay_20ms
		
		;restore state of portc
		mov al,10011000b  		;setting portc upper(4-7) as input and portc lower(0-3) as output,porta as input,portb as output
		out ctrl_addr,al
		mov al,dl
		out portc,al
		
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		popf
		
		ret

stepper_motor_close endp

end