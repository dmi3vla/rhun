# First interactive adapter: Codex app-server's native stdio protocol.
.include "rhun.inc"
.bss
.p2align 3
channel: .zero CP_SIZE
partial: .zero SB_SIZE
request: .zero SB_SIZE
answer: .zero SB_SIZE
thread_id: .quad 0
cli: .quad 0
state: .long 0                # 0 closed, 1 init, 2 thread, 3 ready, 4 turn
deadline: .quad 0
status: .quad 0
readbuf: .zero 16384
argv: .zero 40
.text
FN chat_init
    lea rdi, [rip + channel]
    call chat_pipe_init
    lea rax, [rip + .Lclosed]
    mov [rip + status], rax
    ret

FN chat_status
    mov rax, [rip + status]
    ret

FN chat_busy
    mov eax, [rip + state]
    cmp eax, 3
    je 1f
    test eax, eax
    setnz al
    movzx eax, al
    ret
1:  xor eax, eax
    ret

FN chat_timeout
    mov eax, -1
    cmp dword ptr [rip + channel + CP_pid], 0
    je 1f
    mov eax, 20
1:  ret

# Explicitly close owned process on project change / application exit.
FN chat_shutdown
    PROLOGUE
    lea rdi, [rip + channel]
    call chat_pipe_close
    mov dword ptr [rip + state], 0
    lea rax, [rip + .Lclosed]
    mov [rip + status], rax
    EPILOGUE

# chat_start() -> 0 success, -1 failure. Only called on explicit New Chat.
FN chat_start
    PROLOGUE
    cmp qword ptr [rip + g_project], 0
    je .Lstart_no_project
    cmp dword ptr [rip + channel + CP_pid], 0
    jne .Lstart_busy
    mov rdi, [rip + cli]
    call mem_free
    lea rdi, [rip + .Lcodex]
    call proc_which
    mov [rip + cli], rax
    test rax, rax
    jz .Lstart_missing
    mov [rip + argv], rax
    lea rax, [rip + .Lserver]
    mov [rip + argv + 8], rax
    lea rax, [rip + .Llisten]
    mov [rip + argv + 16], rax
    lea rax, [rip + .Lstdio]
    mov [rip + argv + 24], rax
    mov qword ptr [rip + argv + 32], 0
    mov rdi, [rip + thread_id]
    call mem_free
    mov qword ptr [rip + thread_id], 0
    lea rdi, [rip + partial]
    call sb_clear
    lea rdi, [rip + answer]
    call sb_clear
    lea rdi, [rip + channel]
    lea rsi, [rip + argv]
    mov rdx, [rip + g_envp]
    mov rcx, [rip + g_project]
    call chat_pipe_start
    test rax, rax
    js .Lstart_failed
    mov dword ptr [rip + state], 1
    lea rax, [rip + .Lconnecting]
    mov [rip + status], rax
    call time_ms
    add rax, 15000
    mov [rip + deadline], rax
    lea rdi, [rip + .Linitialize]
    call send_cstr
    test rax, rax
    js .Lstart_failed
    xor eax, eax
    EPILOGUE
.Lstart_no_project:
    lea rdi, [rip + .Lnoproject]
    jmp .Lstart_error
.Lstart_busy:
    lea rdi, [rip + .Lclosing]
    jmp .Lstart_error
.Lstart_missing:
    lea rdi, [rip + .Lmissing]
    jmp .Lstart_error
.Lstart_failed:
    call chat_shutdown
    lea rdi, [rip + .Llaunch_failed]
.Lstart_error:
    mov [rip + status], rdi
    call app_toast
    mov eax, -1
    EPILOGUE

send_cstr:
    push rbx
    mov rbx, rdi
    call strlen
    lea rdi, [rip + channel]
    mov rsi, rbx
    mov rdx, rax
    call chat_pipe_queue
    pop rbx
    ret
send_request:
    lea rdi, [rip + channel]
    mov rsi, [rip + request + SB_ptr]
    mov rdx, [rip + request + SB_len]
    jmp chat_pipe_queue
append:
    mov rsi, rdi
    lea rdi, [rip + request]
    jmp sb_push_cstr
quote_cstr:
    push rbx
    mov rbx, rdi
    call strlen
    mov rdx, rax
    mov rsi, rbx
    lea rdi, [rip + request]
    call chat_json_quote
    pop rbx
    ret

# chat_send(bytes,len) -> 1 accepted, 0 rejected. Retain draft on failure.
FN chat_send
    PROLOGUE
    mov r12, rdi
    mov r13, rsi
    cmp dword ptr [rip + state], 3
    jne 8f
    test rsi, rsi
    jz 8f
    cmp rsi, 65536
    ja 8f
    lea rdi, [rip + request]
    call sb_clear
    lea rdi, [rip + .Lturn_prefix]
    call append
    mov rdi, [rip + thread_id]
    call quote_cstr
    lea rdi, [rip + .Linput_prefix]
    call append
    lea rdi, [rip + request]
    mov rsi, r12
    mov rdx, r13
    call chat_json_quote
    lea rdi, [rip + .Lturn_suffix]
    call append
    call send_request
    test rax, rax
    js 8f
    lea rdi, [rip + answer]
    call sb_clear
    mov dword ptr [rip + state], 4
    lea rax, [rip + .Lworking]
    mov [rip + status], rax
    mov edi, 1
    mov rsi, r12
    mov rdx, r13
    call agents_chat_event
    mov eax, 1
    EPILOGUE
8:  xor eax, eax
    EPILOGUE

# Stop closes the runtime for this MVP. Native interrupt/resume comes next.
FN chat_stop
    call chat_shutdown
    lea rax, [rip + .Lstopped]
    mov [rip + status], rax
    mov dword ptr [rip + g_dirty], 1
    ret

# Consume one protocol line. The JSON arena cannot survive another json_parse.
on_record:
    PROLOGUE
    call json_parse_complete
    test rax, rax
    jz .Lbad_record
    mov rbx, rax
    mov rdi, rax
    call json_type
    cmp eax, JT_OBJ
    jne .Lbad_record
    mov rax, rbx
    mov rdi, rax
    lea rsi, [rip + .Lmethod]
    call json_get
    mov r12, rax
    test rax, rax
    jnz .Lnotification
    mov rdi, rbx
    lea rsi, [rip + .Lerror]
    call json_get
    test rax, rax
    jnz .Lrpc_error
    mov rdi, rbx
    lea rsi, [rip + .Lid]
    call json_get
    mov r12, rax
    mov rdi, rbx
    lea rsi, [rip + .Lresult]
    call json_get
    mov r13, rax
    mov rdi, r12
    lea rsi, [rip + .Linit_id]
    call json_is
    test eax, eax
    jnz .Linitialized
    mov rdi, r12
    lea rsi, [rip + .Lthread_id]
    call json_is
    test eax, eax
    jz .Lrecord_done
    cmp dword ptr [rip + state], 2
    jne .Lrecord_done
    mov rdi, r13
    lea rsi, [rip + .Lthread]
    call json_get
    lea rsi, [rip + .Lid]
    mov rdi, rax
    call json_get
    mov rdi, rax
    call json_str
    test rdx, rdx
    jz .Lbad_record
    mov rdi, rax
    mov rsi, rdx
    call mem_dup
    mov [rip + thread_id], rax
    mov dword ptr [rip + state], 3
    lea rax, [rip + .Lready]
    mov [rip + status], rax
    jmp .Lrecord_done
.Linitialized:
    cmp dword ptr [rip + state], 1
    jne .Lrecord_done
    lea rdi, [rip + .Linitialized_msg]
    call send_cstr
    lea rdi, [rip + request]
    call sb_clear
    lea rdi, [rip + .Lthread_prefix]
    call append
    mov rdi, [rip + g_project]
    call quote_cstr
    lea rdi, [rip + .Lthread_suffix]
    call append
    call send_request
    test rax, rax
    js .Lbad_record
    mov dword ptr [rip + state], 2
    jmp .Lrecord_done
.Lnotification:
    # Server requests are not notifications. Never leave them silently waiting.
    mov rdi, rbx
    lea rsi, [rip + .Lid]
    call json_get
    test rax, rax
    jnz .Lunsupported_request
    mov rdi, rbx
    lea rsi, [rip + .Lparams]
    call json_get
    mov r13, rax
    mov rdi, r12
    lea rsi, [rip + .Ldelta_method]
    call json_is
    test eax, eax
    jnz .Ldelta
    mov rdi, r12
    lea rsi, [rip + .Lcompleted_method]
    call json_is
    test eax, eax
    jnz .Lcompleted
    mov rdi, r12
    lea rsi, [rip + .Lerror]
    call json_is
    test eax, eax
    jnz .Lrpc_error
    jmp .Lrecord_done
.Ldelta:
    cmp dword ptr [rip + state], 4
    jne .Lrecord_done
    mov rdi, r13
    lea rsi, [rip + .Ldelta_key]
    call json_get
    mov rdi, rax
    call json_str
    test rdx, rdx
    jz .Lrecord_done
    mov rcx, [rip + answer + SB_len]
    add rcx, rdx
    cmp rcx, CHAT_FRAME_LIMIT
    ja .Lbad_record
    lea rdi, [rip + answer]
    mov rsi, rax
    call sb_push
    mov edi, 2
    mov rsi, [rip + answer + SB_ptr]
    mov rdx, [rip + answer + SB_len]
    call agents_chat_event
    jmp .Lrecord_done
.Lcompleted:
    cmp dword ptr [rip + state], 4
    jne .Lrecord_done
    mov rdi, r13
    lea rsi, [rip + .Lturn]
    call json_get
    mov r13, rax
    mov rdi, rax
    lea rsi, [rip + .Lstatus_key]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Lcompleted_value]
    call json_is
    test eax, eax
    jz .Lturn_failed
    lea rax, [rip + .Lready]
    jmp .Lturn_finished
.Lturn_failed:
    lea rax, [rip + .Lfailed]
.Lturn_finished:
    mov [rip + status], rax
    mov dword ptr [rip + state], 3
    jmp .Lrecord_done
.Lunsupported_request:
    # MVP cannot display interactive questions/approvals yet. Surface it and
    # abort the owned runtime rather than auto-approve or hang the turn.
    lea rdi, [rip + .Lunsupported]
    jmp .Lprotocol_error
.Lrpc_error:
    lea rdi, [rip + .Lrpc_failed]
    jmp .Lprotocol_error
.Lbad_record:
    lea rdi, [rip + .Lprotocol_failed]
.Lprotocol_error:
    mov r12, rdi
    call chat_shutdown
    mov [rip + status], r12
    mov rdi, r12
    call strlen
    mov rdx, rax
    mov rsi, r12
    mov edi, 3
    call agents_chat_event
.Lrecord_done:
    mov dword ptr [rip + g_dirty], 1
    EPILOGUE

# Bounded tick: one stdin write and at most four stdout reads; stderr drained.
FN chat_tick
    PROLOGUE
    cmp dword ptr [rip + channel + CP_pid], 0
    je .Ltick_done
    cmp dword ptr [rip + state], 0
    je .Lreap
    lea rdi, [rip + channel]
    call chat_pipe_flush
    test rax, rax
    js .Ltick_failed
    mov ebx, 4
.Lread:
    mov edi, [rip + channel + CP_out]
    test edi, edi
    js .Lreap
    lea rsi, [rip + readbuf]
    mov edx, 16384
    SYS SYS_read
    cmp rax, -EAGAIN
    je .Lstderr
    cmp rax, -EINTR
    je .Lstderr
    test rax, rax
    js .Ltick_failed
    jz .Ltick_failed
    lea rdi, [rip + partial]
    lea rsi, [rip + readbuf]
    mov rdx, rax
    lea rcx, [rip + on_record]
    xor r8d, r8d
    call chat_lines_feed
    test rax, rax
    js .Ltick_failed
    cmp dword ptr [rip + state], 0
    je .Lreap
    dec ebx
    jnz .Lread
.Lstderr:
    mov edi, [rip + channel + CP_err]
    lea rsi, [rip + readbuf]
    mov edx, 16384
    SYS SYS_read
    # Diagnostics stay separate from JSON; UI exposes protocol failures.
    cmp dword ptr [rip + state], 2
    ja .Ltick_done
    call time_ms
    cmp rax, [rip + deadline]
    jae .Ltick_failed
    jmp .Ltick_done
.Ltick_failed:
    call chat_shutdown
    lea rax, [rip + .Lconnection_lost]
    mov [rip + status], rax
    mov dword ptr [rip + g_dirty], 1
.Lreap:
    mov edi, [rip + channel + CP_pid]
    mov esi, 1
    call proc_wait
    cmp eax, -1
    je .Ltick_done
    mov dword ptr [rip + channel + CP_pid], 0
.Ltick_done:
    EPILOGUE

.section .rodata
.Lcodex: .asciz "codex"
.Lserver: .asciz "app-server"
.Llisten: .asciz "--listen"
.Lstdio: .asciz "stdio://"
.Lclosed: .asciz "Start a new Codex chat"
.Lconnecting: .asciz "Connecting to Codex..."
.Lready: .asciz "Codex ready"
.Lworking: .asciz "Codex is working..."
.Lstopped: .asciz "Stopped. Start a new chat to reconnect."
.Lfailed: .asciz "Turn failed or interrupted"
.Lclosing: .asciz "Previous chat is closing. Try again shortly."
.Lmissing: .asciz "Codex CLI not found in PATH"
.Lnoproject: .asciz "Open a project folder first"
.Llaunch_failed: .asciz "Could not start Codex chat on this platform"
.Lrpc_failed: .asciz "Codex returned an error. Check CLI sign-in/configuration."
.Lprotocol_failed: .asciz "Invalid or oversized Codex protocol message"
.Lconnection_lost: .asciz "Codex connection closed or initialization timed out"
.Lunsupported: .asciz "This action needs an approval/question UI. Chat stopped."
.Lmethod: .asciz "method"
.Lparams: .asciz "params"
.Lresult: .asciz "result"
.Lerror: .asciz "error"
.Lid: .asciz "id"
.Linit_id: .asciz "init"
.Lthread_id: .asciz "thread"
.Lthread: .asciz "thread"
.Lturn: .asciz "turn"
.Lstatus_key: .asciz "status"
.Lcompleted_value: .asciz "completed"
.Ldelta_key: .asciz "delta"
.Ldelta_method: .asciz "item/agentMessage/delta"
.Lcompleted_method: .asciz "turn/completed"
.Linitialize: .asciz "{\"id\":\"init\",\"method\":\"initialize\",\"params\":{\"clientInfo\":{\"name\":\"rhun\",\"title\":\"rhun\",\"version\":\"0.1.0\"}}}\n"
.Linitialized_msg: .asciz "{\"method\":\"initialized\",\"params\":{}}\n"
.Lthread_prefix: .asciz "{\"id\":\"thread\",\"method\":\"thread/start\",\"params\":{\"cwd\":"
.Lthread_suffix: .asciz ",\"sandbox\":\"workspace-write\",\"approvalPolicy\":\"on-request\"}}\n"
.Lturn_prefix: .asciz "{\"id\":\"turn\",\"method\":\"turn/start\",\"params\":{\"threadId\":"
.Linput_prefix: .asciz ",\"input\":[{\"type\":\"text\",\"text\":"
.Lturn_suffix: .asciz "}]}}\n"
