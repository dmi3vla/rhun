.include "rhun.inc"
.include "canvas/canvas.inc"
.include "memory/memory.inc"
.include "diff/diff.inc"
.text
FN diff_stale
    mov rax, [rdi + SC_revision]
    cmp [rsi + DF_revision], rax
    jne 2f
    mov rax, [rsi + DF_base]
    cmp dword ptr [rax + DG_profile], 0
    je 1f
    mov rax, [rdi + SC_memory_view]
    test rax, rax
    jz 2f
    mov ecx, [rax + MM_cursor]
    cmp [rsi + DF_snapshot], ecx
    jne 2f
1:  xor eax, eax
    ret
2:  mov eax, 1
    ret
FN cmd_diff_context
    lea rdi, [rip + .Lcontext_prompt]
    mov esi, 19
    jmp prompt_open
FN cmd_diff_load
    lea rdi, [rip + .Lload_prompt]
    mov esi, 20
    jmp prompt_open
FN cmd_diff_export
    lea rdi, [rip + .Lexport_prompt]
    mov esi, 21
    jmp prompt_open
FN diff_context_write
    PROLOGUE SB_SIZE
    mov r12, rdi
    call canvas_active
    test rax, rax
    jz .Lcontext_error
    mov rdi, rax
    call diff_base_build
    mov rbx, rax
    test rax, rax
    jz .Lcontext_error
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, rbx
    mov rsi, rsp
    call diff_graph_dump
    mov rdi, r12
    mov rsi, [rsp + SB_ptr]
    mov rdx, [rsp + SB_len]
    call file_write_all
    mov r12, rax
    mov rdi, rsp
    call sb_free
    mov rdi, rbx
    call diff_graph_free
    test r12, r12
    js .Lcontext_error
    lea rdi, [rip + .Lcontext_ready]
    call app_toast
    EPILOGUE
.Lcontext_error:
    lea rdi, [rip + diff_error]
    call app_toast
    EPILOGUE
# bytes,len, scene: atomically replace current Diff only after validation.
FN diff_load_bytes
    PROLOGUE 24
    mov [rsp], rdi
    mov [rsp + 8], rsi
    mov rbx, rdx
    mov rdi, rbx
    call diff_base_build
    mov r12, rax
    test rax, rax
    jz .Lload_null
    mov rdi, [rsp]
    mov rsi, [rsp + 8]
    call diff_parse
    mov r13, rax
    test rax, rax
    jz .Lload_base_free
    mov rdi, r12
    mov rsi, r13
    call diff_compare
    mov r14, rax
    test rax, rax
    jz .Lload_target_free
    mov rax, [rbx + SC_revision]
    mov [r14 + DF_revision], rax
    mov rax, [rbx + SC_memory_view]
    test rax, rax
    jz .Lload_install
    mov eax, [rax + MM_cursor]
    mov [r14 + DF_snapshot], eax
.Lload_install:
    mov rdi, [rbx + SC_diff]
    call diff_free
    mov [rbx + SC_diff], r14
    mov dword ptr [rip + g_dirty], 1
    mov eax, 1
    EPILOGUE
.Lload_target_free: mov rdi, r13
    call diff_graph_free
.Lload_base_free: mov rdi, r12
    call diff_graph_free
.Lload_null: xor eax, eax
    EPILOGUE
FN diff_load_file
    PROLOGUE
    mov r12, rdi
    call canvas_active
    mov rbx, rax
    test rax, rax
    jz .Lfile_error
    mov rdi, r12
    mov ecx, 1 << 20
    call file_read_limited
    test rax, rax
    jz .Lfile_error
    mov r12, rax
    mov rdi, rax
    mov rsi, rdx
    mov rdx, rbx
    call diff_load_bytes
    mov r13d, eax
    mov rdi, r12
    call mem_free
    test r13d, r13d
    jz .Lfile_error
    lea rdi, [rip + .Lready]
    call app_toast
    EPILOGUE
.Lfile_error:
    lea rdi, [rip + diff_error]
    call app_toast
    EPILOGUE
FN diff_report_write
    PROLOGUE SB_SIZE
    mov r12, rdi
    call canvas_active
    mov rbx, rax
    test rax, rax
    jz .Lreport_error
    cmp qword ptr [rax + SC_diff], 0
    je .Lreport_error
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, rbx
    mov rsi, rsp
    call diff_dump
    mov rdi, r12
    mov rsi, [rsp + SB_ptr]
    mov rdx, [rsp + SB_len]
    call file_write_all
    mov r12, rax
    mov rdi, rsp
    call sb_free
    test r12, r12
    js .Lreport_error
    lea rdi, [rip + .Lreport_ready]
    call app_toast
    EPILOGUE
.Lreport_error: lea rdi, [rip + diff_error]
    call app_toast
    EPILOGUE
.section .rodata
.Lcontext_prompt: .asciz "Export current CFG/snapshot scope as Agent Claims JSON"
.Lload_prompt: .asciz "Compare structured Agent Claims JSON path"
.Lexport_prompt: .asciz "Export Visual Diff JSON report path"
.Lcontext_ready: .asciz "Diff: source-bound agent template exported; review scope and completeness"
.Lready: .asciz "Diff: comparison ready; Base is supplied evidence, not complete ELF truth"
.Lreport_ready: .asciz "Diff: report exported"
.globl diff_error
diff_error: .asciz "Diff rejected: profile, schema, limits, scope or stale source binding; existing data kept"
