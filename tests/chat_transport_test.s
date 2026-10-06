# Transport harness: frames FILE | quote FILE | pipe EXEC ARGS...
.include "rhun.inc"
.bss
.p2align 3
partial: .zero SB_SIZE
quoted: .zero SB_SIZE
pipe: .zero CP_SIZE
bytes: .zero 200000
readbuf: .zero 16384
errors: .zero SB_SIZE
sigact: .zero 32
.text
FN main
    PROLOGUE
    mov qword ptr [rip + sigact], 1
    mov edi, 13
    lea rsi, [rip + sigact]
    xor edx, edx
    mov r10d, 8
    SYS SYS_rt_sigaction
    mov rax, [rip + g_argv]
    mov rdi, [rax + 8]
    cmp byte ptr [rdi], 'p'
    je .Lpipe
    cmp byte ptr [rdi], 'q'
    je .Lquote
    mov rdi, [rax + 16]
    call file_read_all
    mov r12, rax
    mov r13, rdx
    mov r14, rax
.Lfeed:
    test r13, r13
    jz .Lframe_done
    lea rdi, [rip + partial]
    mov rsi, r14
    mov edx, 1
    lea rcx, [rip + record]
    xor r8d, r8d
    call chat_lines_feed
    test rax, rax
    js .Lfailure
    inc r14
    dec r13
    jmp .Lfeed
.Lframe_done:
    mov rdi, r12
    call mem_free
    lea rdi, [rip + partial]
    call sb_free
    xor eax, eax
    EPILOGUE
.Lquote:
    mov rdi, [rax + 16]
    call file_read_all
    mov r12, rax
    mov rsi, rax
    lea rdi, [rip + quoted]
    call chat_json_quote
    mov rdi, [rip + quoted + SB_ptr]
    mov rsi, [rip + quoted + SB_len]
    call output
    mov rdi, r12
    call mem_free
    lea rdi, [rip + quoted]
    call sb_free
    xor eax, eax
    EPILOGUE
.Lpipe:
    lea rdi, [rip + pipe]
    call chat_pipe_init
    lea rdi, [rip + pipe]
    mov rax, [rip + g_argv]
    lea rsi, [rax + 16]
    mov rdx, [rip + g_envp]
    xor ecx, ecx
    call chat_pipe_start
    test rax, rax
    js .Lfailure
    lea rdi, [rip + bytes]
    mov ecx, 200000
    mov al, 'x'
    rep stosb
    lea rdi, [rip + pipe]
    lea rsi, [rip + bytes]
    mov edx, 200000
    call chat_pipe_queue
    test rax, rax
    js .Lfailure
    # Rejected oversized append must leave the queued bytes unchanged.
    lea rdi, [rip + pipe]
    lea rsi, [rip + bytes]
    mov edx, CHAT_QUEUE_LIMIT + 1
    call chat_pipe_queue
    cmp rax, -90
    jne .Lfailure
    call time_ms
    lea r12, [rax + 10000]
    xor r13d, r13d             # stdout EOF
    xor r14d, r14d             # stderr EOF
    mov r15d, -1              # exit status
.Ltick:
    lea rdi, [rip + pipe]
    call chat_pipe_flush
    test rax, rax
    js .Lfailure_close
    test r13d, r13d
    jnz 2f
    mov edi, [rip + pipe + CP_out]
    lea rsi, [rip + readbuf]
    mov edx, 16384
    SYS SYS_read
    cmp rax, -EAGAIN
    je 2f
    cmp rax, -EINTR
    je 2f
    test rax, rax
    js .Lfailure_close
    jnz 1f
    mov r13d, 1
    jmp 2f
1:  lea rdi, [rip + readbuf]
    mov rsi, rax
    call output
2:  test r14d, r14d
    jnz 4f
    mov edi, [rip + pipe + CP_err]
    lea rsi, [rip + readbuf]
    mov edx, 16384
    SYS SYS_read
    cmp rax, -EAGAIN
    je 4f
    cmp rax, -EINTR
    je 4f
    test rax, rax
    js .Lfailure_close
    jnz 3f
    mov r14d, 1
    jmp 4f
3:  lea rdi, [rip + errors]
    lea rsi, [rip + readbuf]
    mov rdx, rax
    call sb_push
4:  cmp r15d, -1
    jne 5f
    mov edi, [rip + pipe + CP_pid]
    mov esi, 1
    call proc_wait
    mov r15d, eax
5:  cmp r15d, -1
    je 6f
    test r13d, r13d
    jz 6f
    test r14d, r14d
    jz 6f
    cmp r15d, 0
    jne .Lfailure_close
    mov dword ptr [rip + pipe + CP_pid], 0
    lea rdi, [rip + pipe]
    call chat_pipe_close
    mov rdi, [rip + errors + SB_ptr]
    mov rsi, [rip + errors + SB_len]
    call output
    lea rdi, [rip + errors]
    call sb_free
    xor eax, eax
    EPILOGUE
6:  call time_ms
    cmp rax, r12
    ja .Lfailure_close
    xor edi, edi
    xor esi, esi
    mov edx, 1
    SYS SYS_poll
    jmp .Ltick
.Lfailure_close:
    lea rdi, [rip + pipe]
    call chat_pipe_close
.Lfailure:
    mov eax, 1
    EPILOGUE

record:
    push rbx
    mov rbx, rsi
    call output
    lea rdi, [rip + newline]
    mov esi, 1
    call output
    pop rbx
    ret
output:
    mov rdx, rsi
    mov rsi, rdi
    mov edi, 1
    jmp write_all
.section .rodata
newline: .byte 10
