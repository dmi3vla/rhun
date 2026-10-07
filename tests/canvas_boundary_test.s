.include "rhun.inc"
.include "canvas/canvas.inc"
.text
FN main
    PROLOGUE
    call scene_new
    mov rbx, rax
    mov dword ptr [rbx + SC_y], 116
    mov rdi, rbx
    mov esi, CT_RECT
    mov edx, 130
    mov ecx, 114
    mov r8d, 170
    mov r9d, 90
    call scene_add
    mov rdi, rbx
    mov esi, CT_ELLIPSE
    mov edx, 440
    mov ecx, 114
    mov r8d, 160
    mov r9d, 90
    call scene_add
    mov rdi, rbx
    mov esi, 2
    mov edx, 215
    mov ecx, 275
    call canvas_bound_point
    cmp ecx, 1
    jne .Lfail
    cmp eax, 440
    jne .Lfail
    cmp edx, 275
    jne .Lfail
    mov rdi, rbx
    mov esi, 1
    mov edx, 440
    mov ecx, 275
    call canvas_bound_point
    cmp ecx, 1
    jne .Lfail
    cmp eax, 300
    jne .Lfail
    cmp edx, 275
    jne .Lfail
    mov rdi, rbx
    call scene_free
    lea rdi, [rip + .Lok]
    call log_cstr
    xor eax, eax
    EPILOGUE
.Lfail:
    mov r12, rax
    mov r13, rdx
    mov r14, rcx
    lea rdi, [rip + .Lfail_msg]
    call log_cstr
    mov rdi, r12
    call log_u64
    mov rdi, r13
    call log_u64
    mov rdi, r14
    call log_u64
    mov eax, 1
    EPILOGUE
.section .rodata
.Lok: .asciz "canvas shape boundaries ok\n"
.Lfail_msg: .asciz "boundary failed\n"
