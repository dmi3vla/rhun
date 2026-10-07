# Fixed primitive workload, no file I/O or model/network calls in timed loop.
.include "rhun.inc"
.include "canvas/canvas.inc"
.bss
out: .zero SB_SIZE
.text
FN main
    PROLOGUE
    mov edi, 1000*700*4
    call mem_alloc
    mov r15, rax
    mov rdi, rax
    mov esi, 1000
    mov edx, 700
    mov ecx, 1000
    call gfx_set_target
    mov dword ptr [rip + g_theme + T_PANEL*4], 0xff252a33
    mov r14d, 100
.Lbench_scene:
    call scene_new
    mov rbx, rax
    mov dword ptr [rbx + SC_w], 1000
    mov dword ptr [rbx + SC_h], 700
    xor r12d, r12d
1:  cmp r12d, r14d
    jae 2f
    mov eax, r12d
    xor edx, edx
    mov ecx, 40
    div ecx
    imul edx, 24
    imul eax, 24
    mov ecx, eax
    mov rdi, rbx
    mov esi, CT_RECT
    mov r8d, 20
    mov r9d, 18
    call scene_add
    inc r12d
    jmp 1b
2:  call time_ms
    mov r13, rax
    xor r12d, r12d
.Lbench_frame:
    xor r10d, r10d
3:  cmp r10d, r14d
    jae 4f
    imul rsi, r10, CE_SIZE
    add rsi, [rbx + SC_elements + VEC_ptr]
    mov rdi, rbx
    push r10
    push r10
    call canvas_paint_element
    pop r10
    pop r10
    inc r10d
    jmp 3b
4:  inc r12d
    cmp r12d, 200
    jb .Lbench_frame
    call time_ms
    sub rax, r13
    mov r13, rax
    lea rdi, [rip + out]
    mov esi, r14d
    call sb_push_u64
    lea rdi, [rip + out]
    lea rsi, [rip + .Lms]
    call sb_push_cstr
    lea rdi, [rip + out]
    mov rsi, r13
    call sb_push_u64
    lea rdi, [rip + out]
    mov esi, 10
    call sb_push_byte
    mov rdi, rbx
    call scene_free
    cmp r14d, 1000
    jae 8f
    mov r14d, 1000
    jmp .Lbench_scene
8:  mov rdi, r15
    call mem_free
    mov rdi, [rip + out + SB_ptr]
    mov rsi, [rip + out + SB_len]
    call log_write
    lea rdi, [rip + out]
    call sb_free
    xor eax, eax
    EPILOGUE
.section .rodata
.Lms: .asciz " elements / 200 frames total_ms="
