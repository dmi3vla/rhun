.include "rhun.inc"
.include "canvas/canvas.inc"
.bss
shape: .zero CE_SIZE
.text
FN main
    PROLOGUE
    lea rbx, [rip + shape]
    mov dword ptr [rbx + CE_x], 100
    mov dword ptr [rbx + CE_y], 200
    mov dword ptr [rbx + CE_w], 100
    mov dword ptr [rbx + CE_h], 60
    mov dword ptr [rbx + CE_angle], 90
    mov rdi, rbx
    mov esi, 100
    mov edx, 200
    mov ecx, 1
    call canvas_rotate_point
    cmp eax, 180
    jne .Lfail
    cmp edx, 180
    jne .Lfail
    mov esi, eax
    mov rdi, rbx
    mov ecx, -1
    call canvas_rotate_point
    cmp eax, 100
    jne .Lfail
    cmp edx, 200
    jne .Lfail
    lea rdi, [rip + .Lnumber]
    mov esi, 8
    call json_parse_complete
    mov rdi, rax
    call canvas_json_number
    test edx, edx
    jz .Lfail
    cvtsd2si eax, xmm0
    cmp eax, -1250
    jne .Lfail
    lea rdi, [rip + .Lok]
    call log_cstr
    xor eax, eax
    EPILOGUE
.Lfail:
    mov eax, 1
    EPILOGUE
.section .rodata
.Lnumber: .ascii "-1.25e+3"
.Lok: .asciz "canvas rotation and external numbers ok\n"
