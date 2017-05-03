.section .data

	negative: .string "-1"
	temp: .space wordSize
	searchWord: .space wordSize
	targetText: .space wordSize 
	wordSize = 1024 #Can be changed without affecting functionality much, except words that are larger than wordSize doesn't work.
	inputBuffer: .space inputBufferSize 
	inputBufferSize = 4096 #Can be changed to any number > size of search word and maintain functionality.
	fstat: .space 144
	newline: .ascii "\n"

.global _start
_start:
	pop %R8 #number of arguments, not needed.
	pop %R8 #executable name, not needed.
	pop %R8 #1st argument file with search words
	pop %R9 #2nd arguement file with text to be searched
		
	mov $2, %RAX #Open text file read from the 2nd argument.
	mov %R9, %RDI
	mov $0, %RDX
	syscall
	cmp $0, %RAX
	jl end #If file is not opend, end program.
	mov %RAX, %R9 #File descriptor for the text file to search.
	
	mov $2, %RAX #Open queries file read from the 1st argument.
	mov %R8, %RDI
	mov $0, %RDX
	syscall
	cmp $0, %RAX
	jl end #If file is not opend, end program.
	mov %RAX, %R8 #File descriptor for the queries file.
	
	push %R8
	push %R9
	
	###################Iterate through content of queries file one inputBufferSize at a time####################
	call get_file_size
	mov %RAX, %R10
	mov $0, %R12 #counter for how long has been scanned
	mov $0, %R15 #end of last search word
	queriesfile_iterator:
		mov $0, %RAX #Read from queries file.
		mov %R8, %RDI
		mov $inputBuffer, %RSI
		mov $inputBufferSize, %RDX
		syscall
		movb $0,inputBufferSize(%RSI)#Add string termination.
		
		#Find next search word in queries file
		next_search_word:
			mov $newline, %RAX
			mov %RSI, %RDI
			mov $inputBufferSize, %RCX
			call match_letter
			cmp $0, %RAX #If %RAX is 0, then the character isn't a newline character.
			je next_query_byte
			#Read all posistions since last \n and before the next \n into searchWord#
			mov %RAX, %R14
			add %R12, %RAX
			mov %RAX, %R13
			
			mov $8, %RAX #Update queries file to end of last search word
			mov %R8, %RDI
			mov %R15, %RSI
			mov $0, %RDX
			syscall
			
			mov $0, %RAX #Read from queries file.
			mov %R8, %RDI
			mov $searchWord, %RSI
			mov %R13, %RDX
			sub %R15, %RDX
			syscall
			dec %RDX
			movb $0,(%RDX,%RSI)#Add string termination instead of \n.
			
			push %R10 #Save registers so they can be used in text file iterator
			push %R12
			push %R13
			push %R14
			push %R15
			
			###################Iterate through text file and match searchWord##################
			mov %RSI, %RAX
			call print_string #Prints the search word.			
			call get_string_length
			mov %RAX, %R13 #Length of searchword stored in R13
			mov $0, %R12 #loop counter
			mov %R9, %RAX
			call get_file_size
			mov %RAX, %R10 #File size of textfile stored in R10
			#dec %R10
			mov $0, %R14 #Counts the number of times a searchword has been found in the text
			mov $0, %R15
			textfile_iterator:
				mov $0, %RAX #Read from text file.
				mov %R9, %RDI
				mov $inputBuffer, %RSI
				mov $inputBufferSize, %RDX
				syscall
				cmp $inputBufferSize, %R10
				movb $0, inputBufferSize(%RSI) #Add string termination.
				jg full_buffer
				movb $0,(%R10,%RSI) #Add string termination.
				full_buffer:
				push %R10
				push %R12
				########Get substring of buffer to test against searchWord########
				mov %RSI, %RAX
				#call print_string				
				call get_string_length
				mov %RAX, %R10 #Length of buffer to iterate through, needed since it may not be full.
				sub %R13, %R10 #only need to loop (length of buffer - length of search word) times to get all possible words.
				inc %R10
				mov $0, %R12 #Loop counter
				inputBuffer_iterator:
					mov $inputBuffer, %RSI
					mov $targetText, %RDI
					mov %R12, %RAX
					mov %R13, %RDX
					add %R12, %RDX
					call substring
					#####Match targetText to searchWord#####
					#mov $targetText, %RAX
					#call print_string
					
					mov $searchWord, %RSI
					mov %R13, %RCX
					repe cmpsb
					jne no_match
					mov %R15, %RAX
					add %R12, %RAX
					call print_integer
					inc %R14
					
					########################################
					no_match:
					inc %R12
					dec %R10
					cmp $0, %R10
					jg inputBuffer_iterator
					
				##################################################################
				pop %R12
				pop %R10
				
				sub $inputBufferSize, %R10 #Subtract what has been read from the size of the file.
				cmp $0, %R10 #If there is more left to read than the size of the buffer, repeat. 
				jle no_more_to_read
				
				mov $8, %RAX #update text file to character searchWordSize-1.
				mov %R9, %RDI
				mov %R15, %RSI
				add $inputBufferSize, %RSI
				sub %R13, %RSI
				inc %RSI
				mov $0, %RDX
				syscall
				
				add %R13, %R10
				dec %R10
				add $inputBufferSize, %R15
				sub %R13, %R15
				inc %R15
				jmp textfile_iterator
				no_more_to_read:
				cmp $0, %R14
				jg found
				mov $negative, %RAX
				call print_string #prints -1 if the word has not been found in the textfile
			###################################################################################
			
			found:
			mov $8, %RAX #Reset search file for next search word.
			mov %R9, %RDI
			mov $0, %RSI
			mov $0, %RDX
			syscall
			
			pop %R15 #Restore registers after use in iterator. 
			pop %R14
			pop %R13
			pop %R12
			pop %R10
			
			mov $8, %RAX #Update queries file to after last searchword 
			mov %R8, %RDI
			mov %R13, %RSI
			mov $0, %RDX
			syscall

			mov %R13, %R15 #Last position where a newline character was found
			mov %R13, %R12 #The number of bytes now scanned.
			sub %R14, %R10 #Update how much is left of the file.
			cmp $0, %R10 #If there is more left to read than the size of the buffer, repeat.
			jg queriesfile_iterator
			jle end
			
		next_query_byte:
			add $inputBufferSize, %R12
			sub $inputBufferSize, %R10 #Subtract what has been read from the size of the file.
			cmp $0, %R10 #If there is more left to read than the size of the buffer, repeat.
			jg queriesfile_iterator
	#################################################################################################

	end:
		pop %R8
		pop %R9
		mov $3, %RAX #Close queries file.
		mov %R8, %RDI
		syscall
		
		mov $3, %RAX #Close text file.
		mov %R9, %RDI
		syscall
	
		mov $60, %RAX #Exit program
		mov $0, %RDI
		syscall

.type get_string_length, @function
get_string_length:
  /* Dertermines the length of a zero-terminated string. Returns result in %rax.
   * %rax: Address of string.
   */
  push %rbp
  mov %rsp, %rbp

  push %rcx
  push %rbx
  push %rdx
  push %rsi
  push %r11

  xor %rdx, %rdx

  # Get string length
  lengthLoop:
    movb (%rax), %bl    # Read a byte from string
    cmp $0, %bl         # If byte == 0: end loop
  je lengthDone
    inc %rdx
    inc %rax
  jmp lengthLoop
  lengthDone:

  mov %rdx, %rax

  pop %r11
  pop %rsi
  pop %rdx
  pop %rbx
  pop %rcx

  mov %rbp, %rsp
  pop %rbp
  ret
  
.type print_integer, @function
print_integer:
  /* Prints integer in RAX. */

  push  %rbp
  mov   %rsp, %rbp        # function Prolog
  
  push  %rax              # saving the registers on the stack
  push  %rcx
  push  %rdx
  push  %rdi
  push  %rsi
  push  %r9

  mov   $1, %r9           # we always print the 1 character "\n"
  push  $10               # put '\n' on the stack
  
  rax_loop1:
  mov   $0, %rdx
  mov   $10, %rcx
  idiv  %rcx              # idiv alwas divides rdx:rax/operand
                          # result is in rax, remainder in rdx
  add   $48, %rdx         # add 48 to remainder to get corresponding ASCII
  push  %rdx              # save our first ASCII sign on the stack
  inc   %r9               # counter
  cmp   $0, %rax   
  jne   rax_loop1             # loop until rax = 0

  rax_print_loop:
  mov   $1, %rax          # Here we make a syscall. 1 in rax designates a sys_write
  mov   $1, %rdi          # rdx: int file descriptor (1 is stdout)
  mov   %rsp, %rsi        # rsi: char* buffer (rsp points to the current char to write)
  mov   $1, %rdx          # rdx: size_t count (we write one char at a time)
  syscall                 # instruction making the syscall
  add   $8, %rsp          # set stack pointer to next char
  dec   %r9
  jne   rax_print_loop

  pop   %r9               # restoring the registers
  pop   %rsi
  pop   %rdi
  pop   %rdx
  pop   %rcx
  pop   %rax

  mov   %rbp, %rsp        # function Epilog
  pop   %rbp
  ret
  
.type print_string, @function  
print_string:
 /*Prints a string stored in %RAX followed by a newline*/
 	push  %rbp
  mov   %rsp, %rbp        # function Prolog
  
  push %RAX
  push %RDI
  push %RSI
  push %RDX
  
  push %RAX
  call get_string_length
  mov %RAX, %RDX #length of string
  mov $1, %rax #Print
	mov $1, %rdi #Stnd out
	mov (%RSP), %RSI	
	syscall
	push $10 #push newline onto stack
  mov   $1, %RAX
  mov   $1, %RDI
  mov   %RSP, %RSI #print the newline
  mov   $1, %RDX
  syscall
  pop %RDX
  pop %RDX
	
	pop %RDX
  pop %RSI
  pop %RDI
  pop %RAX
  
  mov   %rbp, %rsp        # function Epilog
  pop   %rbp
  ret
  
.type match_letter, @function
match_letter:
  /* returns posistion of the first match of the first character in %RAX in string pointed at by %RDI, of length %RCX.
   * posistion returned in %RAX, if no match is found 0 is returned in %RAX.
   */
  
  push %RBP							# function Prolog
  mov %RSP, %RBP
  
  push %RCX
  push %RDI
  push %R10
  push %R9
  
  mov %RAX, %R10
  movzxb (%R10), %RAX
  mov %RCX, %R9
  cld
  repne scasb
  cmovne %RCX, %RAX
  cmove %R9, %RAX
  sub %RCX, %RAX

 	pop %R9
 	pop %R10
  pop %RDI
  pop %RCX
  
  mov %RBP, %RSP        # function Epilog
  pop %RBP
  ret
  
.type get_file_size, @function
get_file_size:
  /* Determines the size of a file in bytes. Returns result in %rax.
   * %rax: file descriptor
   */
  push %rbp
  mov %rsp, %rbp

  push %rbx
  push %rcx
  push %rdi
  push %rsi
  push %r11

  # Get fstat 
  mov %rax, %rdi        # file handler
  mov $5, %rax          # syscall fstat
  mov $fstat, %rsi      # reserved space for the stat struct
  syscall
  
  mov $fstat, %rbx
  mov 48(%rbx), %rax    # position of size in the struct

  pop %r11
  pop %rsi
  pop %rdi
  pop %rcx
  pop %rbx

  mov %rbp, %rsp
  pop %rbp
  ret
  
.type substring, @function  
substring:
	/* Moves substring of length RCX, starting at index RAX and ending at index RDX. 
	 * of string pointed at by RSI to string pointed at by RDI.
	 */
	push %RBP								# function Prolog
  mov %RSP, %RBP
  
  push %RAX
  push %RDI
  push %RSI
  push %RDX
  push %RCX
  push %R9
  
	add %RAX, %RSI #String is shifted start index places.
	sub %RAX, %RDX #Start index subtracted from End index
	mov %RDX, %RCX
	cld
	rep movsb
	movb $0, (%RDI)
  
  pop %R9
  pop %RCX
  pop %RDX
  pop %RSI
  pop %RDI
  pop %RAX
  
  mov %RBP, %RSP
  pop %RBP
  ret