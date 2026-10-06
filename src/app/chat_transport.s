# Interactive CLI transport. Protocol stdout is never mixed with diagnostics.
.include "rhun.inc"

.text
# chat_pipe_init(CP*): caller supplies fresh storage.
FN chat_pipe_init
    mov dword ptr [rdi + CP_pid], 0
    mov dword ptr [rdi + CP_in], -1
    mov dword ptr [rdi + CP_out], -1
    mov dword ptr [rdi + CP_err], -1
    mov qword ptr [rdi + CP_queue + SB_ptr], 0
    mov qword ptr [rdi + CP_queue + SB_len], 0
    mov qword ptr [rdi + CP_queue + SB_cap], 0
    mov qword ptr [rdi + CP_sent], 0
    ret

# chat_pipe_start(CP*, argv, envp, cwd) -> pid or -errno.
# Parent ends alone are nonblocking; children receive ordinary blocking stdio.
FN chat_pipe_start
.ifdef WINDOWS
    # ws_write on anonymous pipes blocks even with O_NONBLOCK. A Windows worker
    # or overlapped named-pipe implementation is required before enabling chat.
    mov rax, -38
    ret
.else
    PROLOGUE 32
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    cmp dword ptr [rbx + CP_pid], 0
    jne .Lcp_busy
    mov qword ptr [rsp], -1
    mov qword ptr [rsp + 8], -1
    mov qword ptr [rsp + 16], -1
    xor r15d, r15d
.Lcp_make:
    lea rdi, [rsp + r15*8]
    mov esi, O_CLOEXEC
    SYS SYS_pipe2
    test rax, rax
    js .Lcp_fail
    inc r15
    cmp r15, 3
    jb .Lcp_make
    # Mark only the parent endpoints nonblocking and check every fcntl result.
    mov edi, [rsp + 4]
    call .Lcp_nonblock
    test rax, rax
    js .Lcp_fail
    mov edi, [rsp + 8]
    call .Lcp_nonblock
    test rax, rax
    js .Lcp_fail
    mov edi, [rsp + 16]
    call .Lcp_nonblock
    test rax, rax
    js .Lcp_fail
    mov rdi, r12
    mov rsi, r13
    mov rdx, r14
    mov ecx, [rsp]
    mov r8d, [rsp + 12]
    mov r9d, [rsp + 20]
    push 1
    push 1
    call proc_spawn
    add rsp, 16
    test rax, rax
    js .Lcp_fail
    mov [rbx + CP_pid], eax
    mov eax, [rsp + 4]
    mov [rbx + CP_in], eax
    mov eax, [rsp + 8]
    mov [rbx + CP_out], eax
    mov eax, [rsp + 16]
    mov [rbx + CP_err], eax
    mov edi, [rsp]
    SYS SYS_close
    mov edi, [rsp + 12]
    SYS SYS_close
    mov edi, [rsp + 20]
    SYS SYS_close
    mov eax, [rbx + CP_pid]
    EPILOGUE
.Lcp_fail:
    mov r14, rax
    xor r15d, r15d
.Lcp_cleanup:
    mov edi, [rsp + r15*4]
    test edi, edi
    js 1f
    SYS SYS_close
1:  inc r15
    cmp r15, 6
    jb .Lcp_cleanup
    mov rax, r14
    EPILOGUE
.Lcp_busy:
    mov rax, -16
    EPILOGUE
.Lcp_nonblock:
    mov esi, 4                 # F_SETFL
    mov edx, O_NONBLOCK
    SYS SYS_fcntl
    ret
.endif

# chat_pipe_queue(CP*, bytes, len) -> 0 or -errno. Caller supplies framing.
# A rejected append leaves the existing queue intact.
FN chat_pipe_queue
    PROLOGUE
    mov rbx, rdi
    cmp dword ptr [rbx + CP_in], 0
    jl 8f
    cmp rdx, CHAT_QUEUE_LIMIT
    ja 7f
    mov rax, [rbx + CP_queue + SB_len]
    add rax, rdx
    cmp rax, CHAT_QUEUE_LIMIT
    ja 7f
    lea rdi, [rbx + CP_queue]
    call sb_push
    xor eax, eax
    EPILOGUE
7:  mov rax, -90               # EMSGSIZE
    EPILOGUE
8:  mov rax, -32               # EPIPE
    EPILOGUE

# chat_pipe_flush(CP*) -> pending bytes or -errno. One write per tick, max 16 KiB.
FN chat_pipe_flush
    PROLOGUE
    mov rbx, rdi
    mov rdx, [rbx + CP_queue + SB_len]
    sub rdx, [rbx + CP_sent]
    jz 6f
    mov edi, [rbx + CP_in]
    test edi, edi
    js 8f
    cmp rdx, 16384
    jbe 1f
    mov edx, 16384
1:  mov rsi, [rbx + CP_queue + SB_ptr]
    add rsi, [rbx + CP_sent]
    SYS SYS_write
    cmp rax, -EAGAIN
    je 5f
    cmp rax, -EINTR
    je 5f
    test rax, rax
    js 9f
    jz 8f
    add [rbx + CP_sent], rax
5:  mov rax, [rbx + CP_queue + SB_len]
    sub rax, [rbx + CP_sent]
    jnz 9f
6:  lea rdi, [rbx + CP_queue]
    call sb_clear
    mov qword ptr [rbx + CP_sent], 0
    xor eax, eax
9:  EPILOGUE
8:  mov rax, -32
    EPILOGUE

# chat_pipe_close(CP*): closes descriptors and kills owned group; no blocking wait.
# Retains pid for caller to reap with proc_wait(nohang), even after close.
FN chat_pipe_close
    PROLOGUE
    mov rbx, rdi
    mov edi, [rbx + CP_pid]
    test edi, edi
    jz 1f
    neg edi
    mov esi, 9
    SYS SYS_kill
1:  xor r12d, r12d
2:  mov edi, [rbx + CP_in + r12*4]
    test edi, edi
    js 3f
    SYS SYS_close
3:  mov dword ptr [rbx + CP_in + r12*4], -1
    inc r12
    cmp r12, 3
    jb 2b
    lea rdi, [rbx + CP_queue]
    call sb_free
    mov qword ptr [rbx + CP_sent], 0
    EPILOGUE

# chat_lines_feed(SB* partial, bytes, len, callback(ptr,len,ctx), ctx) -> 0/-errno.
# Callback gets a complete nonempty record (CR removed). Its bytes expire after
# callback. Copy retained content, and never recursively feed the same partial.
FN chat_lines_feed
    PROLOGUE 16
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov r15, r8
1:  test r13, r13
    jz 8f
    xor eax, eax
2:  cmp rax, r13
    jae 3f
    cmp byte ptr [r12 + rax], 10
    je 3f
    inc rax
    jmp 2b
3:  mov [rsp], rax
    mov rcx, [rbx + SB_len]
    add rcx, rax
    cmp rcx, CHAT_FRAME_LIMIT
    ja 9f
    mov rdi, rbx
    mov rsi, r12
    mov rdx, rax
    call sb_push
    mov rax, [rsp]
    add r12, rax
    sub r13, rax
    jz 8f
    inc r12
    dec r13
    mov rdi, [rbx + SB_ptr]
    mov rsi, [rbx + SB_len]
    test rsi, rsi
    jz 6f
    cmp byte ptr [rdi + rsi - 1], 13
    jne 4f
    dec rsi
4:  test rsi, rsi
    jz 6f
    mov rdx, r15
    call r14
6:  mov rdi, rbx
    call sb_clear
    jmp 1b
8:  xor eax, eax
    EPILOGUE
9:  mov rdi, rbx
    call sb_clear
    mov rax, -90
    EPILOGUE

# json_quote(sb, bytes, len): append a correctly escaped JSON string.
FN chat_json_quote
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov esi, '"'
    call sb_push_byte
1:  test r13, r13
    jz 6f
    movzx r14d, byte ptr [r12]
    inc r12
    dec r13
    cmp r14d, 32
    jb 4f
    cmp r14d, '"'
    je 3f
    cmp r14d, 92
    jne 5f
3:  mov rdi, rbx
    mov esi, 92
    call sb_push_byte
    jmp 5f
4:  mov rdi, rbx
    lea rsi, [rip + .Lunicode]
    call sb_push_cstr
    mov eax, r14d
    shr eax, 4
    lea rcx, [rip + .Lhex]
    movzx esi, byte ptr [rcx + rax]
    mov rdi, rbx
    call sb_push_byte
    and r14d, 15
    lea rcx, [rip + .Lhex]
    movzx r14d, byte ptr [rcx + r14]
5:  mov rdi, rbx
    mov esi, r14d
    call sb_push_byte
    jmp 1b
6:  mov rdi, rbx
    mov esi, '"'
    call sb_push_byte
    EPILOGUE

.section .rodata
.Lunicode: .asciz "\\u00"
.Lhex: .ascii "0123456789abcdef"
