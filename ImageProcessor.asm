%include "in_out.asm"

O_directory equ 0q0200000
sys_makenewdir equ 0q777

section .data
    ; directory db "/home/rostin/Desktop/photos",0

    fdfolder dq 0
    fdinput dq 0
    fdoutput dq 0
    endbuffer dq 0

    dir db "edited_photo",0
    n db 0
    size dq 0                       
    offset dq 0
    width dq 0
    height dq 0

    

    negflag dq 0                ;this is a flag when n is negative that we use psubusb instead of paddusb



section .bss
    array resb 8                ;this is array= n,n,n,n,n,n,n,n because i cant use vpbroudcastb

    directory resb 1000         ;we input directory of our image folder and store it here
    newdirectory resb 1000      ;our new directory is directory/edited_photo
    files resb 1000000          
    filename resb 1000          ;our filename which is directory/filename
    newfilename resb 1000       ;our newfilename which is newdirectory/filename

    fileheader resb 14          ;first 14 bytes of bmp is file header
    filetype resb 4             ;next 4 bytes is file type. 12 is os and else is windows
    osheader resb 8             ;8 bytes os header
    winheader resb 36           ;36 bytes windows header
    padding resb 4              ;our padding at the end of each row of pixels. we read the paddings and store it here
    row resb 1000000            ;our row of pixels which is width*3
    
section .text
    global _start


;this macro concats string 1 and 2 and stores it in 3
%macro concat 3
    push rax 
    push rsi 
    push rdi

    mov rsi,%1
    mov rdi,%3
%%part1:
    mov al,[rsi]
    cmp al,0
    je %%next1
    mov [rdi],al
    inc rdi
    inc rsi 
    jmp %%part1
%%next1:
    mov byte [rdi],'/'
    inc rdi
    mov rsi,%2
%%part2:
    mov al,[rsi]
    cmp al,0
    je %%next2
    mov [rdi],al
    inc rdi 
    inc rsi
    jmp %%part2
%%next2:
    mov byte [rdi],0
    pop rdi
    pop rsi 
    pop rax

%endmacro


_start:
    call readString             ;we read directory as string
    call readNum                ;we read n
    mov [n],al
    cmp rax,0                   ;we get the absolute value of n and set a flag if it was negative. if negflag is 0 we use paddusb if 1 we use psubusb
    jl setflag
    jmp else
setflag:
    imul rax,-1
    mov [n],al
    mov qword [negflag],1
else:
    call createDirectory        ;we create our new directory edited_photo in the directory we read from input
    call readDirectory          ;we read our directory we read from input and open each file
_exit:
    mov rax,60
    xor rdi,rdi 
    syscall

;this is our function which reads a string
readString:
    push rax 
    push rsi 
    mov rax,0
    mov rsi,directory
body_rs:
    call getc
    cmp al,0xA
    je end_rs
    mov [rsi],al
    inc rsi 
    jmp body_rs
end_rs:
    mov byte [rsi],0
    pop rsi 
    pop rax
    ret


;this function creates new directory
createDirectory:
    concat directory,dir,newdirectory

    mov rax,83
    mov rdi,newdirectory
    mov rsi,sys_makenewdir              ;this is our sys for making directory
    syscall

    ret

readDirectory:
    mov rax,2
    mov rdi,directory
    mov rsi,O_directory                 ;we open our directory
    syscall

    mov [fdfolder],rax

    mov rax,217
    mov rdi,[fdfolder]                  ;we use getdents function to get each filename in our directory
    mov rsi,files
    mov rdx,1000000
    syscall

    mov [endbuffer],rax
    
    mov rdx,0
    mov r11,files
    add [endbuffer],r11

readFiles:
    add rdx,r11
    cmp rdx,[endbuffer]
    jge end_rf
    mov r11,0
    mov r11w,[rdx+16]
    mov r12,rdx 
    add r12,18
    xor r13,r13
    mov r13b,[r12]
    cmp r13,8
    jne readFiles

    inc r12

    push rdx
    push r11
    push r12
    push r13

    call openfile

    pop r13
    pop r12 
    pop r11 
    pop rdx 
    jmp readFiles
end_rf:
    ret

;r12 stores our filename
openfile:
    concat directory,r12,filename

    mov rax,2
    mov rdi,filename                    ;we open our image
    mov rsi,O_RDWR
    syscall
    mov [fdinput],rax

    call lightImages                    

    mov rax,3
    mov rdi,[fdinput]
    syscall

    ret

;this function first checks if our file is a bmp image then we proccess it
lightImages:
    mov rax,0
    mov rdi,[fdinput]            ;read 14 bytes of input file
    mov rsi,fileheader
    mov rdx,14
    syscall

    mov al,[fileheader]
    mov bl,[fileheader+1]
    cmp al,'B'
    je ifbm
    jmp elsebm
ifbm:
    cmp bl,'M'
    je if2bm
    jmp elsebm
if2bm:
    jmp size_li
elsebm:
    ret
;we create a new file and we write our fileheader and file type in to that new file
size_li:
    call createfile             ;now that we know our image is bmp(first two bytes are B and M) we create a new image in our new directory edited_photo
    mov eax,[fileheader+2]
    mov [size],rax              ;size of file

    mov eax,[fileheader+10]
    mov [offset],rax

    mov rax,0
    mov rdi,[fdinput]
    mov rsi,filetype
    mov rdx,4
    syscall

    mov rax,1
    mov rdi,[fdoutput]
    mov rsi,fileheader
    mov rdx,14
    syscall 

    mov rax,1
    mov rdi,[fdoutput]
    mov rsi,filetype
    mov rdx,4
    syscall


    mov eax,[filetype]
    cmp rax,12                  ;if file type is 12 its os else its windows
    je os
    jmp windows

createfile:
    concat newdirectory,r12,newfilename
    
    mov rax,85
    mov rdi,newfilename
    mov rsi,sys_IRUSR | sys_IWUSR
    syscall
    mov [fdoutput],rax
    ret
;width and height in windows are 4 bytes. we write our winheader into our new file
windows:
    mov rax,0
    mov rdi,[fdinput]
    mov rsi,winheader
    mov rdx,36
    syscall

    mov eax,[winheader]
    mov [width],rax

    mov eax,[winheader+4]
    mov [height],rax

    mov rax,1
    mov rdi,[fdoutput]
    mov rsi,winheader
    mov rdx,36
    syscall


    call pixel
    ret

;width and height in os are 2 bytes. we write our os header in to our new file
os:
    mov rax,0
    mov rdi,[fdinput]
    mov rsi,osheader
    mov rdx,8
    syscall


    mov ax,[osheader]
    mov [width],rax

    mov ax,[osheader+2]
    mov [height],rax
    

    mov rax,1
    mov rdi,[fdoutput]
    mov rsi,osheader
    mov rdx,8
    syscall


    call pixel
    ret

;this function calculates padding in each row and we process each row 8 bytes at a time until at the end where there is less than 8 bytes we process them one at a time
;then we read our padding and ignore them and we write each modified row and padding into our new file. our new image has been succesfully created.
pixel:

    mov r9,[width]
    imul r9,3                   ;r9 is width*3 which is the number of our bytes or pixel

    mov rcx,0

    mov rax,r9
    mov rbx,4
    mov rdx,0
    div rbx
    sub rbx,rdx
    cmp rbx,4
    cmove rbx,rcx
    mov r8,rbx                  ;because each row size has to b a multiple of 4 padding bytes are added until its satisfied

    call newLine
    mov rax,r9
    call writeNum
    call newLine
    mov rax,rbx
    call writeNum
    call newLine
    call newLine

    mov rax,0
    mov rdi,[fdinput]
    mov rsi,row                 ;we read r9 bytes of our pixels in one row. we will read the paddings later
    mov rdx,r9
    syscall



    mov rcx,8                 
    mov rdi,array
;this sets array to n,n,..,n
setArray:
    mov al,[n]
    mov [rdi],al
    inc rdi
    dec rcx
    cmp rcx,0
    je end_sa
    jmp setArray
end_sa:
    mov rax,0





    ; vpbroadcastb xmm1,byte [n]            ;cannot use this instruction because i dont have avx
    movq mm1,[array]                        ;we move our n,n,..,n into our mm1 register


    mov rcx,8          ;rcx is our conter for the number of bytes we process


    mov r10,0           ;our counter for our height size

    mov rsi,row
body_pixel:
    movq mm0,[rsi]
    cmp qword [negflag],1       ;if negflage is 1 we use psubusb if 0 we use paddusb.
    je negpixel
    jmp addpixel
negpixel:
    psubusb mm0,mm1
    jmp else_pixel
addpixel:
    paddusb mm0,mm1
    jmp else_pixel
else_pixel:
    movq [rsi],mm0              ;we move our proccessed pixels back to memory to write it later



    add rsi,8
    add rcx,8


    cmp rcx,r9                  ;if remaining pixels are greater than r9 we process them one at a time
    jg next_pixel


    jmp body_pixel

;we process our remaining pixels one at a time
next_pixel:
    sub rcx,8
    mov rax,r9
    sub rax,rcx
rem_pixel:
    cmp rax,0
    je padding_pixel
    mov rbx,0
    mov bl,[rsi]
    mov rdx,0
    mov dl,byte [n]
    cmp qword [negflag],1
    je minus
    jmp plus
minus:
    sub rbx,rdx
    jmp check
plus:
    add rbx,rdx
    jmp check
check:
    cmp rbx,0
    jl min
    cmp rbx,255
    jg max
    jmp else2_pixel
min:
    mov rbx,0
    jmp else2_pixel
max:
    mov rbx,255
    jmp else2_pixel

else2_pixel:
    push rax
    mov rax,rbx
    call writeNum
    call newLine
    call newLine
    pop rax

    mov [rsi],bl
    inc rsi
    dec rax
    jmp rem_pixel

padding_pixel:

    ;we read padding
    mov rax,0
    mov rdi,[fdinput]
    mov rsi,padding
    mov rdx,r8
    syscall

    ;we write our modified row of pixels to our new file
    mov rax,1
    mov rdi,[fdoutput]
    mov rsi,row
    mov rdx,r9
    syscall
    ;we write the padding as well
    mov rax,1
    mov rdi,[fdoutput]
    mov rsi,padding
    mov rdx,r8
    syscall



    inc r10
    cmp r10,[height]        ;if r10 equals height our work here is done
    je end_pixel

    mov rax,0
    mov rdi,[fdinput]       ;else get next row of pixels to process them
    mov rsi,row
    mov rdx,r9
    syscall

    mov rcx,8
    jmp body_pixel

end_pixel:
    mov rax,3
    mov rdi,[fdoutput]      ;we close our newfile and return
    syscall

    ret

