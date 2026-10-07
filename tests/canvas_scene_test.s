.include "rhun.inc"
.include "canvas/canvas.inc"
.bss
output: .zero SB_SIZE
.text
FN main
    PROLOGUE
    call scene_new
    mov rbx, rax
    mov rdi, rbx
    call scene_clone
    mov r12, rax
    mov rdi, rbx
    mov esi, CT_RECT
    mov edx, -30
    mov ecx, 72
    mov r8d, 180
    mov r9d, 92
    call scene_add
    mov rdi, rbx
    mov rsi, r12
    call scene_commit
    mov rdi, rbx
    call scene_dirty
    cmp eax, 1
    jne .Lfail
    mov rdi, rbx
    call scene_undo
    cmp qword ptr [rbx + SC_elements + VEC_len], 0
    jne .Lfail
    mov rdi, rbx
    call scene_dirty
    test eax, eax
    jnz .Lfail
    cmp qword ptr [rbx + SC_revision], 2
    jne .Lfail
    mov rdi, rbx
    call scene_redo
    cmp qword ptr [rbx + SC_elements + VEC_len], 1
    jne .Lfail
    cmp qword ptr [rbx + SC_revision], 3
    jne .Lfail
    mov rax, [rbx + SC_elements + VEC_ptr]
    mov r12, rax
    lea rdi, [rip + .Ltext]
    mov esi, .Ltext_end - .Ltext
    call mem_dup
    mov [r12 + CE_text], rax
    mov rdi, rbx
    lea rsi, [rip + output]
    call scene_serialize
    test eax, eax
    jz .Lfail
    mov rdi, [rip + output + SB_ptr]
    mov rsi, [rip + output + SB_len]
    call scene_parse
    test rax, rax
    jz .Lfail
    mov r12, rax
    # Reset the parser with unrelated data. Owned Cyrillic text must survive.
    lea rdi, [rip + .Lother]
    mov esi, 2
    call json_parse_complete
    mov rax, [r12 + SC_elements + VEC_ptr]
    mov rdi, [rax + CE_text]
    lea rsi, [rip + .Ltext]
    call strcmp_eq
    test eax, eax
    jz .Lfail
    mov rdi, r12
    call scene_free
    lea rdi, [rip + .Lbad]
    mov esi, .Lbad_end - .Lbad
    call scene_parse
    test rax, rax
    jnz .Lfail
    # A new edit after undo discards redo and does not recycle IDs.
    mov rdi, rbx
    call scene_undo
    mov rdi, rbx
    call scene_clone
    mov r12, rax
    mov rdi, rbx
    mov esi, CT_ELLIPSE
    mov edx, 80
    mov ecx, 80
    mov r8d, 60
    mov r9d, 60
    call scene_add
    cmp qword ptr [rax + CE_id], 2
    jne .Lfail
    mov rdi, rbx
    mov rsi, r12
    call scene_commit
    cmp qword ptr [rbx + SC_redo + VEC_len], 0
    jne .Lfail
    mov rdi, rbx
    call scene_free
    lea rdi, [rip + output]
    call sb_free
    lea rdi, [rip + .Lok]
    call log_cstr
    xor eax, eax
    EPILOGUE
.Lfail:
    mov eax, 1
    EPILOGUE
.section .rodata
.Ltext: .ascii "Привет\n\"текст\""
.Ltext_end:
.byte 0
.Lother: .asciz "{}"
.Lbad: .ascii "{\"type\":\"rhun-canvas\",\"version\":2,\"next\":1,\"elements\":[]}"
.Lbad_end:
.Lok: .asciz "canvas owned scene and history ok\n"
