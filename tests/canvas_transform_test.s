# World/screen round trips including negative pan and all zoom bounds.
.include "rhun.inc"
.include "canvas/canvas.inc"
.bss
scene: .zero SC_SIZE
.text
FN main
    PROLOGUE
    lea rbx, [rip + scene]
    mov dword ptr [rbx + SC_x], 237
    mov dword ptr [rbx + SC_y], 89
    mov dword ptr [rbx + SC_pan_x], -123
    mov dword ptr [rbx + SC_pan_y], 57
    mov r12d, 16384
1:  mov [rbx + SC_zoom], r12d
    mov r13d, -1000000
2:  mov rdi, rbx
    mov esi, r13d
    mov edx, r13d
    neg edx
    call scene_to_screen
    mov esi, eax
    mov rdi, rbx
    call scene_to_world
    sub eax, r13d
    cmp eax, -4
    jl .Lfail
    cmp eax, 4
    jg .Lfail
    add edx, r13d
    cmp edx, -4
    jl .Lfail
    cmp edx, 4
    jg .Lfail
    add r13d, 10001
    cmp r13d, 1000000
    jle 2b
    add r12d, 8192
    cmp r12d, 262144
    jle 1b
    # Owned fixture lifecycle, stable monotonically allocated IDs.
    call scene_new
    mov rbx, rax
    cmp qword ptr [rbx + SC_elements + VEC_len], 2
    jne .Lfail
    cmp qword ptr [rbx + SC_next_id], 3
    jne .Lfail
    mov rdi, rbx
    call scene_free
    lea rdi, [rip + .Lok]
    call log_cstr
    xor eax, eax
    EPILOGUE
.Lfail:
    mov eax, 1
    EPILOGUE
.section .rodata
.Lok: .asciz "canvas transforms ok\n"
