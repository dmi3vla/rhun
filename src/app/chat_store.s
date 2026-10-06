# Project-local chat tabs: owned JSON snapshots, native IDs, drafts, atomic saves.
.include "rhun.inc"
.equ CHAT_TABS_MAX, 16
.equ CHAT_STORE_MAX, 16 << 20
.bss
.p2align 3
records: .zero VEC_SIZE        # independently owned canonical JSON cstrs
current: .quad 0
path: .zero SB_SIZE
snapshot: .zero SB_SIZE
output: .zero SB_SIZE
labels: .zero SB_SIZE
dirty: .long 0
.p2align 3
save_at: .quad 0
.globl chat_resume_id
chat_resume_id: .quad 0
.text
FN chat_store_native_id
    PROLOGUE
    mov r12, rdi
    call strlen
    mov rsi, rax
    mov rdi, r12
    call mem_dup
    mov r12, rax
    mov rdi, [rip + chat_resume_id]
    call mem_free
    mov [rip + chat_resume_id], r12
    call chat_store_dirty
    EPILOGUE

FN chat_store_dirty
    cmp qword ptr [rip + path + SB_len], 0
    je 1f
    cmp qword ptr [rip + current], 0
    jl 1f
    mov dword ptr [rip + dirty], 1
1:  ret

FN chat_store_timeout
    mov eax, -1
    cmp dword ptr [rip + dirty], 0
    je 1f
    mov eax, 1000
1:  ret

FN chat_store_tick
    push rbx
    cmp dword ptr [rip + dirty], 0
    je 1f
    call time_ms
    cmp rax, [rip + save_at]
    jb 1f
    call chat_store_save
1:  pop rbx
    ret

FN chat_store_capture
    PROLOGUE
    mov rbx, [rip + current]
    test rbx, rbx
    js 9f
    cmp rbx, [rip + records + VEC_len]
    jae 9f
    lea rdi, [rip + snapshot]
    call sb_clear
    lea rdi, [rip + snapshot]
    call agents_chat_export
    cmp qword ptr [rip + snapshot + SB_len], 0
    je 9f
    cmp qword ptr [rip + snapshot + SB_len], 8 << 20
    ja 8f
    mov rdi, [rip + snapshot + SB_ptr]
    mov rsi, [rip + snapshot + SB_len]
    call mem_dup
    mov r12, rax
    mov rax, [rip + records + VEC_ptr]
    mov rdi, [rax + rbx*8]
    call mem_free
    mov rax, [rip + records + VEC_ptr]
    mov [rax + rbx*8], r12
9:  xor eax, eax
    EPILOGUE
8:  mov eax, -1
    EPILOGUE

# New Chat must not erase an existing tab, and does not reuse its native ID.
FN chat_store_before_new
    PROLOGUE
    call chat_busy
    test eax, eax
    jnz 8f
    cmp qword ptr [rip + records + VEC_len], CHAT_TABS_MAX
    jae 7f
    call chat_store_capture
    test eax, eax
    js 8f
    mov rdi, [rip + chat_resume_id]
    call mem_free
    mov qword ptr [rip + chat_resume_id], 0
    xor eax, eax
    EPILOGUE
7:  lea rdi, [rip + .Ltab_limit]
    call app_toast
8:  mov eax, -1
    EPILOGUE

FN chat_store_new
    PROLOGUE
    lea rdi, [rip + records]
    mov esi, 8
    call vec_push
    mov qword ptr [rax], 0
    mov rax, [rip + records + VEC_len]
    dec rax
    mov [rip + current], rax
    call chat_store_dirty
    EPILOGUE

FN chat_store_save
    PROLOGUE
    cmp qword ptr [rip + records + VEC_len], 0
    je 9f
    cmp qword ptr [rip + path + SB_len], 0
    je 9f
    call chat_store_capture
    test eax, eax
    js 8f
    lea rdi, [rip + output]
    call sb_clear
    lea rdi, [rip + output]
    lea rsi, [rip + .Lfile_prefix]
    call sb_push_cstr
    lea rdi, [rip + output]
    mov rsi, [rip + current]
    call sb_push_u64
    lea rdi, [rip + output]
    lea rsi, [rip + .Lfile_chats]
    call sb_push_cstr
    xor ebx, ebx
1:  cmp rbx, [rip + records + VEC_len]
    jae 3f
    test rbx, rbx
    jz 2f
    lea rdi, [rip + output]
    mov esi, ','
    call sb_push_byte
2:  mov rax, [rip + records + VEC_ptr]
    mov rsi, [rax + rbx*8]
    test rsi, rsi
    jz 8f
    lea rdi, [rip + output]
    call sb_push_cstr
    cmp qword ptr [rip + output + SB_len], CHAT_STORE_MAX
    ja 8f
    inc rbx
    jmp 1b
3:  lea rdi, [rip + output]
    lea rsi, [rip + .Lfile_end]
    call sb_push_cstr
    mov rdi, [rip + path + SB_ptr]
    mov rsi, [rip + output + SB_ptr]
    mov rdx, [rip + output + SB_len]
    call file_write_private
    test rax, rax
    js 8f
    mov dword ptr [rip + dirty], 0
    call time_ms
    add rax, 1000
    mov [rip + save_at], rax
9:  xor eax, eax
    EPILOGUE
8:  lea rdi, [rip + .Lsave_error]
    call app_toast
    # Keep the last valid disk snapshot. Avoid retrying every UI tick.
    call time_ms
    add rax, 5000
    mov [rip + save_at], rax
    mov eax, -1
    EPILOGUE

# Called after the previous project's active snapshot was saved by app_set_project.
FN chat_store_project
    PROLOGUE 16
    mov qword ptr [rsp], 0
    xor ebx, ebx
1:  cmp rbx, [rip + records + VEC_len]
    jae 2f
    mov rax, [rip + records + VEC_ptr]
    mov rdi, [rax + rbx*8]
    call mem_free
    inc rbx
    jmp 1b
2:  mov qword ptr [rip + records + VEC_len], 0
    mov qword ptr [rip + current], -1
    mov dword ptr [rip + dirty], 0
    mov rdi, [rip + chat_resume_id]
    call mem_free
    mov qword ptr [rip + chat_resume_id], 0
    lea rdi, [rip + path]
    call sb_clear
    call chat_project_state_path
    test rax, rax
    jz 9f
    lea rdi, [rip + path]
    mov rsi, rax
    call sb_push_cstr
    lea rdi, [rip + path]
    lea rsi, [rip + .Lsuffix]
    call sb_push_cstr
    mov rdi, [rip + path + SB_ptr]
    call file_open_read
    test eax, eax
    js 9f
    mov ebx, eax
    mov edi, eax
    call file_size
    mov r12, rax
    mov edi, ebx
    SYS SYS_close
    test r12, r12
    js 8f
    cmp r12, CHAT_STORE_MAX
    ja 8f
    mov rdi, [rip + path + SB_ptr]
    mov ecx, CHAT_STORE_MAX
    call file_read_limited
    test rax, rax
    jz 9f
    mov [rsp], rax
    mov rsi, rdx
    mov rdi, rax
    call json_parse_complete
    mov r12, rax
    test r12, r12
    jz 8f
    mov rdi, r12
    lea rsi, [rip + .Lversion]
    call json_get
    mov rdi, rax
    call json_u64
    cmp rax, 1
    jne 8f
    test rdx, rdx
    jz 8f
    mov rdi, r12
    lea rsi, [rip + .Lactive]
    call json_get
    mov rdi, rax
    call json_u64
    test rdx, rdx
    jz 8f
    mov r15, rax
    mov rdi, r12
    lea rsi, [rip + .Lchats]
    call json_get
    mov r12, rax
    mov rdi, rax
    call json_len
    test rax, rax
    jz 9f
    cmp rax, CHAT_TABS_MAX
    ja 8f
    cmp r15, rax
    jae 8f
    xor r13d, r13d
3:  mov rdi, r12
    call json_len
    cmp r13, rax
    jae 5f
    mov rdi, r12
    mov rsi, r13
    call json_at
    mov r14, rax
    lea rdi, [rip + snapshot]
    call sb_clear
    lea rdi, [rip + snapshot]
    mov rsi, r14
    call json_dump
    mov rdi, [rip + snapshot + SB_ptr]
    mov rsi, [rip + snapshot + SB_len]
    call mem_dup
    mov r14, rax
    lea rdi, [rip + records]
    mov esi, 8
    call vec_push
    mov [rax], r14
    inc r13
    jmp 3b
5:  mov [rip + current], r15
    mov rdi, r12
    mov rsi, r15
    call json_at
    mov rdi, rax
    call agents_chat_import
    test eax, eax
    js 8f
    call chat_mark_restored
9:  mov rdi, [rsp]
    call mem_free
    EPILOGUE
8:  lea rdi, [rip + .Lload_error]
    call app_toast
    mov qword ptr [rip + current], -1
    xor ebx, ebx
1:  cmp rbx, [rip + records + VEC_len]
    jae 2f
    mov rax, [rip + records + VEC_ptr]
    mov rdi, [rax + rbx*8]
    call mem_free
    inc rbx
    jmp 1b
2:  mov qword ptr [rip + records + VEC_len], 0
    # A corrupt/version-mismatched file is retained for manual recovery.
    lea rdi, [rip + path]
    call sb_clear
    jmp 9b

FN chat_tabs
    PROLOGUE
    call chat_store_capture
    lea rdi, [rip + labels]
    call sb_clear
    xor ebx, ebx
1:  cmp rbx, [rip + records + VEC_len]
    jae 3f
    lea rdi, [rip + labels]
    lea rsi, [rbx + 1]
    call sb_push_u64
    lea rdi, [rip + labels]
    lea rsi, [rip + .Ltab_label]
    call sb_push_cstr
    mov rax, [rip + records + VEC_ptr]
    mov rdi, [rax + rbx*8]
    mov r12, rdi
    call strlen
    mov rsi, rax
    mov rdi, r12
    call json_parse_complete
    mov rdi, rax
    lea rsi, [rip + .Lprovider_key]
    call json_get
    mov rdi, rax
    call json_u64
    lea rsi, [rip + .Lcodex_label]
    test rax, rax
    jz 2f
    lea rsi, [rip + .Lopencode_label]
2:  lea rdi, [rip + labels]
    call sb_push_cstr
    lea rdi, [rip + labels]
    mov esi, 10
    call sb_push_byte
    inc rbx
    jmp 1b
3:  test rbx, rbx
    jz 9f
    mov rdi, [rip + labels + SB_ptr]
    lea rsi, [rip + choose_tab]
    lea rdx, [rip + .Lchoose_tabs]
    call palette_choose
9:  EPILOGUE

choose_tab:
    push rbx
    mov rbx, rdi
    xor esi, esi
1:  mov al, [rbx + rsi]
    cmp al, '0'
    jb 2f
    cmp al, '9'
    ja 2f
    inc rsi
    jmp 1b
2:  call parse_u64
    test rdx, rdx
    jz 9f
    lea rdi, [rax - 1]
    call chat_store_switch
9:  pop rbx
    ret

FN chat_tab_close
    PROLOGUE
    mov r12, [rip + current]
    test r12, r12
    js 9f
    call chat_busy
    test eax, eax
    jnz 8f
    call chat_store_save
    call chat_shutdown
    mov rax, [rip + records + VEC_ptr]
    mov rdi, [rax + r12*8]
    call mem_free
    mov rdi, [rip + records + VEC_ptr]
    lea rdi, [rdi + r12*8]
    lea rsi, [rdi + 8]
    mov rdx, [rip + records + VEC_len]
    sub rdx, r12
    dec rdx
    shl rdx, 3
    call memmove
    dec qword ptr [rip + records + VEC_len]
    mov qword ptr [rip + current], -1
    call agents_chat_reset
    mov rdi, [rip + chat_resume_id]
    call mem_free
    mov qword ptr [rip + chat_resume_id], 0
    cmp qword ptr [rip + records + VEC_len], 0
    jne 1f
    mov rdi, [rip + path + SB_ptr]
    test rdi, rdi
    jz 9f
    lea rsi, [rip + .Lempty_file]
    mov edx, .Lempty_file_end - .Lempty_file - 1
    call file_write_private
    mov dword ptr [rip + dirty], 0
    jmp 9f
1:  cmp r12, [rip + records + VEC_len]
    jb 2f
    dec r12
2:  mov rax, [rip + records + VEC_ptr]
    mov rdi, [rax + r12*8]
    mov rbx, rdi
    call strlen
    mov rsi, rax
    mov rdi, rbx
    call json_parse_complete
    mov rdi, rax
    call agents_chat_import
    test eax, eax
    js 9f
    mov [rip + current], r12
    call chat_mark_restored
    call chat_store_dirty
    call chat_store_save
    call chat_resume
    jmp 9f
8:  lea rdi, [rip + .Lswitch_busy]
    call app_toast
9:  EPILOGUE

FN chat_tab_next
    mov rdi, [rip + current]
    inc rdi
    cmp rdi, [rip + records + VEC_len]
    jb chat_store_switch
    xor edi, edi
    jmp chat_store_switch
FN chat_tab_previous
    mov rdi, [rip + current]
    dec rdi
    jns chat_store_switch
    mov rdi, [rip + records + VEC_len]
    dec rdi
    jmp chat_store_switch

FN chat_store_switch
    PROLOGUE
    mov r12, rdi
    cmp rdi, [rip + records + VEC_len]
    jae 9f
    call chat_busy
    test eax, eax
    jnz 8f
    call chat_store_save
    call chat_shutdown
    mov rax, [rip + records + VEC_ptr]
    mov rdi, [rax + r12*8]
    mov rbx, rdi
    call strlen
    mov rsi, rax
    mov rdi, rbx
    call json_parse_complete
    test rax, rax
    jz 9f
    mov rdi, rax
    call agents_chat_import
    test eax, eax
    js 7f
    mov [rip + current], r12
    call chat_mark_restored
    mov dword ptr [rip + g_focus], FOCUS_AGENTS
    mov dword ptr [rip + cfg_agents], 1
    call chat_store_dirty
    call chat_resume
    jmp 9f
7:  call chat_mark_restored
    lea rdi, [rip + .Lload_error]
    call app_toast
    call chat_resume
    jmp 9f
8:  lea rdi, [rip + .Lswitch_busy]
    call app_toast
9:  EPILOGUE

.section .rodata
.Lfile_prefix: .asciz "{\"version\":1,\"active\":"
.Lfile_chats: .asciz ",\"chats\":["
.Lfile_end: .asciz "]}\n"
.Lsuffix: .asciz ".chats.json"
.Lversion: .asciz "version"
.Lactive: .asciz "active"
.Lchats: .asciz "chats"
.Ltab_label: .asciz ": "
.Lchoose_tabs: .asciz "Choose chat tab"
.Lsave_error: .asciz "Could not save chat tabs; last disk snapshot retained"
.Lload_error: .asciz "Invalid or oversized chat state; file retained for recovery"
.Ltab_limit: .asciz "At most 16 chat tabs; close a saved tab before creating another"
.Lswitch_busy: .asciz "Stop the current turn before switching chat tabs"

.Lprovider_key: .asciz "provider"
.Lcodex_label: .asciz "Codex"
.Lopencode_label: .asciz "OpenCode"
.Lempty_file: .asciz "{\"version\":1,\"active\":0,\"chats\":[]}\n"
.Lempty_file_end:
