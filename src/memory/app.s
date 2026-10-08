.include "rhun.inc"
.include "canvas/canvas.inc"
.text
FN memory_open_scene
    PROLOGUE
    mov rbx, rdi
    call doc_new
    mov [rax + DOC_canvas], rbx
    mov [rbx + SC_doc], rax
    lea rcx, [rip + .Ltitle]
    mov [rax + DOC_name], rcx
    mov rdi, rax
    mov esi, TAB_CANVAS
    call app_add_tab
    EPILOGUE
FN cmd_memory_demo
    PROLOGUE
    lea rdi, [rip + .Ldemo]
    mov esi, .Ldemo_end-.Ldemo
    call memory_import
    test rax, rax
    jz .Ldemo_bad
    mov rdi, rax
    call memory_open_scene
    EPILOGUE
.Ldemo_bad: lea rdi, [rip + .Linvalid]
    call app_toast
    EPILOGUE
FN cmd_memory_import
    lea rdi, [rip + .Lprompt]
    mov esi, 18
    jmp prompt_open
FN memory_import_file
    PROLOGUE
    mov ecx, 3 << 20
    call file_read_limited
    test rax, rax
    jz .Lfile_bad
    mov rbx, rax
    mov r13, rdx
    mov rdi, rax
    mov rsi, rdx
    call memory_import
    test rax, rax
    jnz .Lfile_imported
    mov rdi, rbx
    mov rsi, r13
    call memory_header_import
.Lfile_imported:
    mov r12, rax
    mov rdi, rbx
    call mem_free
    test r12, r12
    jz .Lfile_bad
    mov rdi, r12
    call memory_open_scene
    EPILOGUE
.Lfile_bad: lea rdi, [rip + .Linvalid]
    call app_toast
    EPILOGUE
.section .rodata
.Ltitle: .asciz "Radare2 Memory"
.Lprompt: .asciz "Import typed memory snapshots (no target execution)"
.Linvalid: .asciz "Memory: invalid schema, identity, lifetime or limits; existing tabs kept"
.Ldemo: .incbin "examples/memory/rhun-lifecycle.rhun-memory"
.Ldemo_end:
