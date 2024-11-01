.data
Header:	.space 56
Path:	.asciz "C:\\ProjektRISCV\\example.bmp"
Error:	.asciz "Error with opening BMP File"
Error2:	.asciz "Error with writing to BMP File"
Entera:	.asciz "Enter coefficient a (not equal to 0) of the quadratic function multiplied by 2^4: "
Enterb:	.asciz "Enter coefficient b of the quadratic function multiplied by 2^4: "
Enterc:	.asciz "Enter coefficient c of the quadratic function multiplied by 2^4: "
	.text
	.globl main
main:
	li a7, 1024  # sys call for open file
	li a1, 0     # flag for reading
	la a0, Path
	ecall
	
	mv s0, a0    # move file decryptor to s0
	
	li t0, -1
	bne t0, s0, readbmp  # check if error with file
	
	li a7, 4
	la a0, Error
	ecall

readbmp:
	li a7, 63   # sys call for reading a descryptor
	mv a0, s0
	la a1, Header
	addi a1, a1, 2  # move from signature
	li a2, 54
	ecall
	
	lw s1, 18(a1)  # bmp file width in s1
	lw s2, 22(a1)  # bmp file height in s2
	lw s3, 2(a1)   # bmp file size in s3
	lw s4, 10(a1)  # bmp file offset to pixel array
	sub s5, s3, s4 # pixel array size in s5
	
	li a7, 9  # allocate heap memory
	mv a0, s5
	ecall
	
	mv s11, a0
	mv t0, a0 # address of heap memory allocated
	
	li a7, 63
	mv a0, s0
	mv a1, t0
	mv a2, s5
	ecall  # read pixel array to allocated heap memory in (t0)
	
	li a7, 57
	mv a0, s0
	ecall
	
	li t1, 0
	li t2, 0
	li t3, 0
	li t4, 3
	li t6, 0xff # t5 used to color pixel on white
	srai s7, s1, 1 # in s7 width/2
	mul s7, s7, t4
	add s8, s11, s7 #address of first pixel in axis OY in s8
	srai s6, s2, 1 # in s6 height/2
readinput:
# reading the coefficients of a quadratic function from the console
	la a0, Entera
	li a7, 4
	ecall
	
	li a7, 5
	ecall
	mv a3, a0
	
	la a0, Enterb
	li a7, 4
	ecall
	
	li a7, 5
	ecall
	mv a4, a0
	
	la a0, Enterc
	li a7, 4
	ecall
	
	li a7, 5
	ecall
	mv a5, a0

#counting padding in bmp file
ifpadding:
	mul t5, s1, t4
	andi t5, t5, 3 #padding in t5
	li t4, 3
	mv a7, t5
	beqz t5, pixelrow
	addi t4, t4, 1
	sub t5, t4, t5
	li t3, 0
	li t4, 3
	mv a7, t5

#drawing coordinate system----------------------------------------------------------------------------------
pixelrow:
	beq t2, s6, axisX
	beq t0, s8, onaxisY
	sb t6, (t0)
	addi t0, t0, 1
	addi t3, t3, 1 #t3 counts the bytes of a given pixel
	bne t3, t4, pixelrow
	li t3, 0
	addi t1, t1, 1 #t1 counts the width at which the pixel is present
	bne t1, s1, pixelrow
	li t1, 0
	bnez t5, addpadding
	
next_row:
	li t1, 0
	addi t2, t2, 1 #increase the present height by one
	bne t2, s2, pixelrow
	b calcvertex
	
addpadding:
	sb zero, (t0)
	addi t0, t0, 1
	addi t1, t1, 1
	bne t1, t5, addpadding
	li t4, 3
	addi t2, t2, 1
	li t1, 0
	li t3, 0
	bne t2, s2, pixelrow #check the height of pixel array
	b calcvertex
	
axisX:
	sb zero, (t0)
	addi t0, t0, 1
	addi t3, t3, 1 #t3 counts the bytes of a given pixel
	bne t3, t4, axisX
	li t3, 0
	addi t1, t1, 1 #t1 counts the width at which the pixel is present
	bne t1, s1, axisX
	li t1, 0
	mul a2, s1, t4
	add s8, s8, a2
	add s8, s8, t5 #adding padding to the address of the next pixel on the 0Y axis
	bnez t5, addpadding
	b next_row
	
onaxisY:
	sb zero, (t0)
	addi t0, t0, 1
	addi t3, t3, 1
	bne t3, t4, onaxisY
	li t3, 0
	li t4, 3
	mul a2, s1, t4
	add s8, s8, a2
	add s8, s8, t5 #adding padding to the address of the next pixel on the 0Y axis
	addi t1, t1, 1
	b pixelrow

#after drawin coordinate system------------------------------------------------------------------------------------
calcvertex:
#calculating the vertex of the function
	li t0, 0
	li t1, 0
	li t2, 0
	li t3, 0
	li t4, 0
	li t6, 0
	slli t0, a3, 1 #2*a
	slli t6, a4, 4
	neg t6, t6
	div t1, t6, t0 #calculated vertex p
	mul t2, t1, t1
	srai t2, t2, 4 #calculated x^2
	mul t0, a3, t2
	srai t0, t0, 4 #calculated ax^2
	mul t2, a4, t1
	srai t2, t2, 4 #calculated bx
	add t0, t0, t2 #adding ax^2+bx
	add t0, t0, a5 #adding the coefficient c, in t0 the q of the vertex is calculated

get_abs_of_p:
	bgez t1, get_abs_of_q
	neg t1, t1 # |p| in t1

get_abs_of_q:
	bgez t0, searchscale
	neg t0, t0 # |q| in t0
	
searchscale:
	li t2, 4 # 2(binary)*2^-4=1/4 -> 1 pixel: initial scale
	li t5, 16 # square 1x1

#checking if vertex is in square 1x1, 2x2,  4x4, 8x8 ...
check_p:
	blt t1, t5, check_q
	slli t2, t2, 1
	slli t5, t5, 1
	b check_p
	
check_q:
	blt t0, t5, calcminX
	slli t2, t2, 1
	slli t5, t5, 1
	b check_q
	
calcminX:
	srai t0, s1, 1
	mv s7, t0
	mul s7, s7, t2 #rightmost x on the OX axis in s7
	neg t0, t0 #in t0 the number of pixels to the left of (0,0)
	mul t0, t0, t2 #the leftmost x on the OX axis at t0 on our scale
	srai s10, s2, 1 #half pixel height
	neg s9, s10
	mul s10, s10, t2 #max y in file
	mul s9, s9, t2 #min y w pliku
	mv  t1, s11 #in t1 will be the address of subsequent pixels on the OX axis
	li t4, 3
	mul t3, s1, t4
	add t3, t3, a7
	srai t6, s2, 1
	mul t3, t3, t6
	add t1, t1, t3 #address of the first pixel on the OX axis
	li t3, 0
	
#searching for a pixel that will be visible on the graph
findpixels:
	 mul t5, t0, t0 #x^2
	 srai t5, t5, 4
	 mul t5, t5, a3 #ax^2
	 srai t5, t5, 4
	 mul t6, a4, t0 #bx
	 srai t6, t6, 4
	 add t5, t5, t6
	 add t5, t5, a5 #in t5 value of function for given x 
	 bgt t5, s10, nextpixel
	 blt t5, s9, nextpixel
	 mv t6, t1
	div t5, t5, t2 #y/scale
	mul a6, s1, t4 #width*3
	add a6, a6, a7 #+padding
	mul t5, t5, a6
	add t6, t6, t5 #in t6 the address of the pixel to be highlighted on black
	
foundpixel:
# colorize the pixel in black that belongs to the chart
	sb zero, (t6)
	addi t6 t6, 1
	addi t3, t3, 1
	bne t3, t4, foundpixel
	
nextpixel:
	addi t1,t1, 3 #next pixel
	add t0, t0, t2 #moving to the next x on the OX axis
	li t3, 0
	li t6, 0
	bne t0, s7, findpixels #if we are at x on the rightmost side, we save the bmp file
	
savebmp:
# save changes to bmp file ----------------------------------------------
	li a7, 1024
	li a1, 1
	la a0, Path
	ecall
	mv s0, a0
	
	li t0, -1
	bne s0, t0, saveheader
	li a7, 4
	la a0, Error2
	ecall

saveheader:
	li a7, 64
	mv a0, s0
	la a1, Header
	addi a1, a1, 2
	li a2, 54
	ecall
	
	li a7, 64
	mv a0, s0
	mv a1, s11
	mv a2, s5
	ecall
	
	li a7, 57
	mv a0, s0
	ecall

end:
	li a7, 10
	ecall
