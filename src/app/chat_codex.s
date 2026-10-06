# First interactive adapter: Codex app-server's native stdio protocol.
.include "rhun.inc"
.bss
.p2align 3
# Provider is frozen for the lifetime of the owned process.
.globl chat_provider, chat_requested_provider
chat_provider: .long 0         # 0 Codex, 1 OpenCode ACP, 2 Grok ACP, 3 Pi RPC
chat_requested_provider: .long 0
channel: .zero CP_SIZE
partial: .zero SB_SIZE
request: .zero SB_SIZE
answer: .zero SB_SIZE
model_text: .zero SB_SIZE
model_picker: .long 0
.p2align 3
thread_id: .quad 0
turn_id: .quad 0
answer_item: .quad 0
stop_requested: .long 0
restart_requested: .long 0
resume_sent: .long 0
restart_provider: .long 0
stop_deadline: .quad 0
cli: .quad 0
state: .long 0                # 0 closed, 1 init, 2 thread, 3 ready, 4 turn
deadline: .quad 0
status: .quad 0
readbuf: .zero 16384
argv: .zero 72
.text
FN chat_init
    lea rdi, [rip + channel]
    call chat_pipe_init
    lea rax, [rip + .Lclosed]
    mov [rip + status], rax
    ret

FN chat_status
    call chat_pending_kind
    test eax, eax
    jz 1f
    cmp eax, 2
    jne 2f
    lea rax, [rip + .Lanswer_wait]
    ret
2:
    jmp chat_pending_label
1:
    mov rax, [rip + status]
    ret

FN chat_busy
    mov eax, [rip + state]
    cmp eax, 3
    je 1f
    test eax, eax
    jnz 2f
    mov eax, [rip + channel + CP_pid]
    test eax, eax
2:  setnz al
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
    call chat_interactions_clear
    lea rdi, [rip + channel]
    call chat_pipe_close
    mov dword ptr [rip + state], 0
    mov dword ptr [rip + stop_requested], 0
    mov dword ptr [rip + restart_requested], 0
    lea rax, [rip + .Lclosed]
    mov [rip + status], rax
    EPILOGUE

FN chat_mark_restored
    lea rax, [rip + .Lrestored]
    mov [rip + status], rax
    ret

FN chat_resume
    mov dword ptr [rip + g_focus], FOCUS_AGENTS
    mov dword ptr [rip + cfg_agents], 1
    cmp dword ptr [rip + state], 0
    jne 1f
    cmp dword ptr [rip + channel + CP_pid], 0
    je chat_start
    mov eax, [rip + chat_requested_provider]
    mov [rip + restart_provider], eax
    mov dword ptr [rip + restart_requested], 1
    lea rax, [rip + .Lconnecting]
    mov [rip + status], rax
1:  ret

# chat_start() -> 0 success, -1 failure. Only called on explicit New Chat.
FN chat_start
    PROLOGUE
    cmp qword ptr [rip + g_project], 0
    je .Lstart_no_project
    cmp dword ptr [rip + channel + CP_pid], 0
    je .Lstart_idle
    cmp dword ptr [rip + state], 3
    jne .Lstart_busy
    call chat_shutdown
    mov eax, [rip + chat_requested_provider]
    mov [rip + restart_provider], eax
    mov dword ptr [rip + restart_requested], 1
    xor eax, eax
    EPILOGUE
.Lstart_idle:
    mov eax, [rip + chat_requested_provider]
    mov [rip + chat_provider], eax
    mov rdi, [rip + cli]
    call mem_free
    lea rdi, [rip + .Lcodex]
    mov rax, [rip + cfg_chat_cli]
    cmp byte ptr [rax], 0
    je 1f
    mov rdi, rax
1:
    cmp dword ptr [rip + chat_provider], 2
    jne 11f
    lea rdi, [rip + .Lgrok]
    jmp 2f
11: cmp dword ptr [rip + chat_provider], 3
    jne 12f
    lea rdi, [rip + .Lpi]
    jmp 2f
12: cmp dword ptr [rip + chat_provider], 1
    jne 2f
    lea rdi, [rip + .Lopencode]
    mov rax, [rip + cfg_opencode_cli]
    cmp byte ptr [rax], 0
    je 2f
    mov rdi, rax
2:  call proc_which
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
    cmp dword ptr [rip + chat_provider], 2
    jne 11f
    lea rax, [rip + .Lgrok_agent]
    mov [rip + argv + 8], rax
    lea rax, [rip + .Lgrok_no_leader]
    mov [rip + argv + 16], rax
    lea rax, [rip + .Lgrok_stdio]
    mov [rip + argv + 24], rax
    jmp 3f
11: cmp dword ptr [rip + chat_provider], 3
    jne 12f
    lea rax, [rip + .Lpi_mode]
    mov [rip + argv + 8], rax
    lea rax, [rip + .Lpi_rpc]
    mov [rip + argv + 16], rax
    lea rax, [rip + .Lpi_tools]
    mov [rip + argv + 24], rax
    lea rax, [rip + .Lpi_readonly]
    mov [rip + argv + 32], rax
    mov qword ptr [rip + argv + 40], 0
    mov rax, [rip + chat_resume_id]
    test rax, rax
    jz 3f
    cmp byte ptr [rax], 0
    je 3f
    mov [rip + argv + 48], rax
    lea rax, [rip + .Lpi_session]
    mov [rip + argv + 40], rax
    mov qword ptr [rip + argv + 56], 0
    jmp 3f
12: cmp dword ptr [rip + chat_provider], 1
    jne 3f
    lea rax, [rip + .Lacp]
    mov [rip + argv + 8], rax
    mov qword ptr [rip + argv + 16], 0
3:
    mov rdi, [rip + thread_id]
    call mem_free
    mov qword ptr [rip + thread_id], 0
    mov rdi, [rip + turn_id]
    call mem_free
    mov qword ptr [rip + turn_id], 0
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
    cmp dword ptr [rip + chat_provider], 3
    jne 11f
    lea rdi, [rip + pi_initialize_packet]
    jmp 4f
11: cmp dword ptr [rip + chat_provider], 0
    je 4f
    lea rdi, [rip + acp_initialize_packet]
4:  call send_cstr
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
    call chat_pending_kind
    test eax, eax
    jnz 8f
    mov rdi, r12
    mov rsi, r13
    call chat_context_prepare
    test eax, eax
    js 8f
    lea rdi, [rip + request]
    call sb_clear
    cmp dword ptr [rip + chat_provider], 3
    jne 11f
    mov rdi, r12
    mov rsi, r13
    call chat_pi_prompt
    jmp .Lqueued_turn
11: cmp dword ptr [rip + chat_provider], 0
    je 7f
    mov rdi, r12
    mov rsi, r13
    call chat_acp_prompt
    jmp .Lqueued_turn
7:  lea rdi, [rip + .Lturn_prefix]
    call append
    mov rdi, [rip + thread_id]
    call quote_cstr
    mov rdi, [rip + cfg_chat_model]
    cmp byte ptr [rdi], 0
    je 1f
    lea rdi, [rip + .Lmodel_prefix]
    call append
    mov rdi, [rip + cfg_chat_model]
    call quote_cstr
1:
    mov rdi, [rip + cfg_chat_effort]
    cmp byte ptr [rdi], 0
    je 2f
    lea rdi, [rip + .Leffort_prefix]
    call append
    mov rdi, [rip + cfg_chat_effort]
    call quote_cstr
2:
    lea rdi, [rip + .Linput_prefix]
    call append
    lea rdi, [rip + request]
    mov rsi, r12
    mov rdx, r13
    call chat_json_quote
    lea rdi, [rip + .Ltext_end]
    call append
    call chat_context_images
    lea rdi, [rip + .Larray_end]
    call append
    call send_request
.Lqueued_turn:
    test rax, rax
    js 8f
    lea rdi, [rip + answer]
    call sb_clear
    mov rdi, [rip + turn_id]
    call mem_free
    mov qword ptr [rip + turn_id], 0
    mov rdi, [rip + answer_item]
    call mem_free
    mov qword ptr [rip + answer_item], 0
    mov dword ptr [rip + stop_requested], 0
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

# Cancel a native turn, including a click before its ID has arrived.
FN chat_stop
    PROLOGUE
    cmp dword ptr [rip + state], 4
    jne 9f
    cmp dword ptr [rip + stop_requested], 0
    jne 9f
    mov dword ptr [rip + stop_requested], 1
    call time_ms
    add rax, 10000
    mov [rip + stop_deadline], rax
    lea rax, [rip + .Lstopping]
    mov [rip + status], rax
    cmp dword ptr [rip + chat_provider], 3
    jne 11f
    call chat_pi_cancel
    jmp 12f
11: cmp dword ptr [rip + chat_provider], 0
    je 1f
    call chat_acp_cancel
12:
    test rax, rax
    jns 9f
    call chat_shutdown
    jmp 9f
1:  cmp qword ptr [rip + turn_id], 0
    je 9f
    call interrupt_turn
9:
    mov dword ptr [rip + g_dirty], 1
    EPILOGUE

FN chat_disconnect
    jmp chat_shutdown

FN chat_choose_model
    cmp dword ptr [rip + state], 3
    jne 1f
    cmp dword ptr [rip + chat_provider], 3
    je chat_pi_models
    cmp dword ptr [rip + chat_provider], 0
    jne chat_acp_choose_model
    mov dword ptr [rip + model_picker], 1
    jmp chat_list_models
1:  ret

# Codex model is sent on the next native turn; no implicit provider switch.
set_codex_model:
    PROLOGUE
    mov rbx, rdi
    call strlen
    mov rsi, rax
    mov rdi, rbx
    call mem_dup
    mov rbx, rax
    mov rdi, [rip + cfg_chat_model]
    lea rax, [rip + .Lempty_model]
    # Config strings may point into static defaults; use config's owned setter.
    mov rdi, rbx
    call chat_config_model
    mov rdi, rbx
    call mem_free
    mov dword ptr [rip + g_focus], FOCUS_AGENTS
    EPILOGUE

FN chat_list_models
    cmp dword ptr [rip + chat_provider], 3
    je chat_pi_models
    cmp dword ptr [rip + chat_provider], 0
    jne chat_acp_models
    cmp dword ptr [rip + state], 3
    jne 1f
    lea rdi, [rip + .Lmodels_request]
    jmp send_cstr
1:  ret

# Send already framed protocol bytes, used by the interaction queue.
FN chat_send_packet
    mov rdx, rsi
    mov rsi, rdi
    lea rdi, [rip + channel]
    jmp chat_pipe_queue

interrupt_turn:
    PROLOGUE
    lea rdi, [rip + request]
    call sb_clear
    lea rdi, [rip + .Linterrupt_prefix]
    call append
    mov rdi, [rip + thread_id]
    call quote_cstr
    lea rdi, [rip + .Lturn_id_prefix]
    call append
    mov rdi, [rip + turn_id]
    call quote_cstr
    lea rdi, [rip + .Lobject_suffix]
    call append
    call send_request
    test rax, rax
    jns 1f
    call chat_shutdown
    jmp 2f
1:  mov dword ptr [rip + stop_requested], 2
2:  EPILOGUE

# result/params contains {turn:{id:...}}; keep a copied ID, never an arena pointer.
capture_turn:
    PROLOGUE
    lea rsi, [rip + .Lturn]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Lid]
    call json_get
    mov rdi, rax
    call json_str
    test rdx, rdx
    jz 9f
    mov rdi, rax
    mov rsi, rdx
    call mem_dup
    mov rbx, rax
    mov rdi, [rip + turn_id]
    call mem_free
    mov [rip + turn_id], rbx
    cmp dword ptr [rip + stop_requested], 1
    jne 9f
    call interrupt_turn
9:  EPILOGUE

# Reject late deltas/tools from a previous turn in the same native thread.
active_turn_event:
    PROLOGUE
    lea rsi, [rip + .Lturn_id_key]
    call json_get
    mov rdi, rax
    mov rsi, [rip + turn_id]
    test rsi, rsi
    jz 1f
    call json_is
    EPILOGUE
1:  xor eax, eax
    EPILOGUE

# Consume one protocol line. The JSON arena cannot survive another json_parse.
on_record:
    PROLOGUE 16
    mov [rsp], rdi
    mov [rsp + 8], rsi
    call chat_text_valid
    test eax, eax
    jnz 1f
    mov rdi, [rsp]
    mov rsi, [rsp + 8]
    call dispatch_record
    EPILOGUE
1:  call chat_shutdown
    lea rax, [rip + .Lprotocol_failed]
    mov [rip + status], rax
    mov rdi, rax
    call strlen
    mov rdx, rax
    lea rsi, [rip + .Lprotocol_failed]
    mov edi, 3
    call agents_chat_event
    EPILOGUE

dispatch_record:
    cmp dword ptr [rip + chat_provider], 3
    je chat_pi_record
    cmp dword ptr [rip + chat_provider], 0
    jne chat_acp_record
    PROLOGUE
    mov r14, rdi
    mov r15, rsi
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
    lea rsi, [rip + .Lmodels_id]
    call json_is
    test eax, eax
    jz 2f
    mov rdi, r13
    lea rsi, [rip + .Ldata]
    call json_get
    mov r12, rax
    lea rdi, [rip + model_text]
    call sb_clear
    xor r13d, r13d
.Lmodel_loop:
    mov rdi, r12
    call json_len
    cmp r13, rax
    jae .Lmodels_done
    cmp r13, 100
    jae .Lmodels_done
    mov rdi, r12
    mov rsi, r13
    call json_at
    mov rdi, rax
    lea rsi, [rip + .Lmodel_key]
    call json_get
    mov rdi, rax
    call json_str
    lea rdi, [rip + model_text]
    mov rsi, rax
    call sb_push
    lea rdi, [rip + model_text]
    mov esi, 10
    call sb_push_byte
    inc r13
    jmp .Lmodel_loop
.Lmodels_done:
    cmp dword ptr [rip + model_picker], 0
    je 1f
    mov dword ptr [rip + model_picker], 0
    mov rdi, [rip + model_text + SB_ptr]
    test rdi, rdi
    jz .Lrecord_done
    lea rsi, [rip + set_codex_model]
    lea rdx, [rip + .Lmodel_picker_title]
    call palette_choose
    jmp .Lrecord_done
1:  mov edi, 3
    mov rsi, [rip + model_text + SB_ptr]
    mov rdx, [rip + model_text + SB_len]
    call agents_chat_event
    jmp .Lrecord_done
2:  mov rdi, r12
    lea rsi, [rip + .Lturn_id]
    call json_is
    test eax, eax
    jz 1f
    mov rdi, r13
    call capture_turn
    jmp .Lrecord_done
1:  mov rdi, r12
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
    mov rdi, rax
    call chat_store_native_id
    mov dword ptr [rip + state], 3
    lea rax, [rip + .Lready]
    mov [rip + status], rax
    call chat_store_dirty
    jmp .Lrecord_done
.Linitialized:
    mov dword ptr [rip + resume_sent], 0
    cmp dword ptr [rip + state], 1
    jne .Lrecord_done
    lea rdi, [rip + .Linitialized_msg]
    call send_cstr
    lea rdi, [rip + request]
    call sb_clear
    mov rax, [rip + chat_resume_id]
    test rax, rax
    jz 1f
    cmp byte ptr [rax], 0
    je 1f
    mov dword ptr [rip + resume_sent], 1
    lea rdi, [rip + .Lresume_prefix]
    call append
    mov rdi, [rip + chat_resume_id]
    call quote_cstr
    lea rdi, [rip + .Lresume_cwd]
    call append
    jmp 2f
1:  lea rdi, [rip + .Lthread_prefix]
    call append
2:  mov rdi, [rip + g_project]
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
    jz 1f
    mov rdi, r14
    mov rsi, r15
    call chat_interaction_receive
    test eax, eax
    js .Lbad_record
    jmp .Lrecord_done
1:
    mov rdi, rbx
    lea rsi, [rip + .Lparams]
    call json_get
    mov r13, rax
    mov rdi, rax
    lea rsi, [rip + .Lthread_id_key]
    call json_get
    test rax, rax
    jz 2f
    mov rdi, rax
    mov rsi, [rip + thread_id]
    test rsi, rsi
    jz .Lrecord_done
    call json_is
    test eax, eax
    jz .Lrecord_done
2:
    mov rdi, r12
    lea rsi, [rip + .Lstarted_method]
    call json_is
    test eax, eax
    jz 3f
    mov rdi, r13
    call capture_turn
    jmp .Lrecord_done
3:  mov rdi, r12
    lea rsi, [rip + .Litem_started]
    call json_is
    test eax, eax
    jnz .Ltool_item
    mov rdi, r12
    lea rsi, [rip + .Litem_completed]
    call json_is
    test eax, eax
    jnz .Ltool_item
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
.Ltool_item:
    cmp dword ptr [rip + state], 4
    jne .Lrecord_done
    mov rdi, r13
    call active_turn_event
    test eax, eax
    jz .Lrecord_done
    mov rdi, r13
    lea rsi, [rip + .Litem_key]
    call json_get
    mov rdi, rax
    call chat_render_codex_tool
    jmp .Lrecord_done
.Ldelta:
    cmp dword ptr [rip + state], 4
    jne .Lrecord_done
    mov rdi, r13
    call active_turn_event
    test eax, eax
    jz .Lrecord_done
    mov rdi, r13
    lea rsi, [rip + .Litem_id_key]
    call json_get
    mov r14, rax
    mov rsi, [rip + answer_item]
    test rsi, rsi
    jz 1f
    mov rdi, r14
    call json_is
    test eax, eax
    jnz 2f
1:  mov rdi, r14
    call json_str
    test rdx, rdx
    jz 2f
    mov rdi, rax
    mov rsi, rdx
    call mem_dup
    mov r14, rax
    mov rdi, [rip + answer_item]
    call mem_free
    mov [rip + answer_item], r14
    lea rdi, [rip + answer]
    call sb_clear
    call agents_chat_answer_boundary
2:  mov rdi, r13
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
    lea rsi, [rip + .Lid]
    call json_get
    mov rdi, rax
    mov rsi, [rip + turn_id]
    test rsi, rsi
    jz .Lrecord_done
    call json_is
    test eax, eax
    jz .Lrecord_done
    mov rdi, r13
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
    mov rdi, r13
    lea rsi, [rip + .Lstatus_key]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Linterrupted_value]
    call json_is
    test eax, eax
    lea rax, [rip + .Lfailed]
    jz .Lturn_finished
    lea rax, [rip + .Lstopped]
.Lturn_finished:
    mov [rip + status], rax
    mov dword ptr [rip + state], 3
    mov dword ptr [rip + stop_requested], 0
    call chat_interactions_clear
    jmp .Lrecord_done
.Lrpc_error:
    mov rdi, rbx
    lea rsi, [rip + .Lerror]
    call json_get
    test rax, rax
    jnz 1f
    mov rdi, rbx
    lea rsi, [rip + .Lparams]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Lerror]
    call json_get
1:  mov rdi, rax
    lea rsi, [rip + .Lmessage]
    call json_get
    mov rdi, rax
    call json_str
    test rdx, rdx
    jz 2f
    mov r14, rax
    mov r15, rdx
    cmp dword ptr [rip + state], 2
    jne 11f
    cmp dword ptr [rip + resume_sent], 1
    jne 11f
    mov rdi, rax
    mov rsi, r15
    lea rdx, [rip + .Lno_rollout]
    mov ecx, .Lno_rollout_end - .Lno_rollout - 1
    call str_starts
    test eax, eax
    jz 11f
    call agents_chat_has_dialogue
    test eax, eax
    jnz 11f
    # Empty threads have no native rollout until their first turn. Recover only
    # an empty local conversation, preserving its draft; never lose real context.
    mov dword ptr [rip + resume_sent], 0
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
    call time_ms
    add rax, 15000
    mov [rip + deadline], rax
    lea rdi, [rip + .Lempty_recovered]
    call app_toast
    jmp .Lrecord_done
11: mov rsi, r14
    mov rdx, r15
    mov edi, 3
    call agents_chat_event
2:  mov rdi, rbx
    lea rsi, [rip + .Lid]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Lmodels_id]
    call json_is
    test eax, eax
    jz 12f
    mov dword ptr [rip + model_picker], 0
    jmp .Lrecord_done
12: cmp dword ptr [rip + state], 4
    jne 3f
    mov dword ptr [rip + state], 3
    mov dword ptr [rip + stop_requested], 0
    call chat_interactions_clear
    lea rax, [rip + .Lrpc_failed]
    mov [rip + status], rax
    jmp .Lrecord_done
3:  lea rdi, [rip + .Lrpc_failed]
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
    cmp dword ptr [rip + stop_requested], 0
    je 1f
    call time_ms
    cmp rax, [rip + stop_deadline]
    jae .Ltick_failed
1:
    # Diagnostics stay separate from JSON; UI exposes protocol failures.
    cmp dword ptr [rip + state], 5
    je 2f
    cmp dword ptr [rip + state], 2
    ja .Ltick_done
2:
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
    cmp dword ptr [rip + restart_requested], 0
    je .Ltick_done
    mov dword ptr [rip + restart_requested], 0
    mov eax, [rip + restart_provider]
    mov [rip + chat_requested_provider], eax
    call chat_start
.Ltick_done:
    EPILOGUE

.section .rodata
.Lopencode: .asciz "opencode"
.Lacp: .asciz "acp"
.Lcodex: .asciz "codex"
.Lserver: .asciz "app-server"
.Llisten: .asciz "--listen"
.Lstdio: .asciz "stdio://"
.Lclosed: .asciz "Start a new agent chat"
.Lconnecting: .asciz "Connecting to agent..."
.Lready: .asciz "Codex ready"
.Lworking: .asciz "Agent is working..."
.Lanswer_wait: .asciz "Waiting for your answer to the question above"
.Lstopping: .asciz "Stopping current turn..."
.Lstopped: .asciz "Turn stopped. You can continue this conversation."
.Lfailed: .asciz "Turn failed or interrupted"
.Lclosing: .asciz "Previous chat is closing. Try again shortly."
.Lmissing: .asciz "Selected agent CLI not found; check PATH or its CLI setting"
.Lnoproject: .asciz "Open a project folder first"
.Llaunch_failed: .asciz "Could not start agent chat on this platform"
.Lrpc_failed: .asciz "Provider returned an error. Check CLI sign-in/configuration."
.Lprotocol_failed: .asciz "Invalid or oversized provider protocol message"
.Lconnection_lost: .asciz "Agent connection closed or initialization timed out"
.Lmethod: .asciz "method"
.Lparams: .asciz "params"
.Lresult: .asciz "result"
.Lerror: .asciz "error"
.Lid: .asciz "id"
.Lmessage: .asciz "message"
.Lmodel_key: .asciz "model"
.Ldata: .asciz "data"
.Lmodels_id: .asciz "models"
.Linit_id: .asciz "init"
.Lthread_id: .asciz "thread"
.Lturn_id: .asciz "turn"
.Lthread_id_key: .asciz "threadId"
.Lstarted_method: .asciz "turn/started"
.Linterrupted_value: .asciz "interrupted"
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
.Lmodel_prefix: .asciz ",\"model\":"
.Leffort_prefix: .asciz ",\"effort\":"
.Lmodels_request: .asciz "{\"id\":\"models\",\"method\":\"model/list\",\"params\":{\"limit\":100}}\n"
.Linterrupt_prefix: .asciz "{\"id\":\"interrupt\",\"method\":\"turn/interrupt\",\"params\":{\"threadId\":"
.Lturn_id_prefix: .asciz ",\"turnId\":"
.Lobject_suffix: .asciz "}}\n"

.globl chat_runtime_state, chat_runtime_status, chat_runtime_session, chat_runtime_answer
.set chat_runtime_state, state
.set chat_runtime_status, status
.set chat_runtime_session, thread_id
.set chat_runtime_answer, answer
.globl chat_runtime_request, chat_runtime_stop, chat_runtime_append, chat_runtime_quote, chat_runtime_send
.set chat_runtime_request, request
.set chat_runtime_stop, stop_requested
.set chat_runtime_append, append
.set chat_runtime_quote, quote_cstr
.set chat_runtime_send, send_request

.Lmodel_picker_title: .asciz "Choose Codex model"
.Lempty_model: .asciz ""

.globl chat_runtime_deadline
.set chat_runtime_deadline, deadline

.globl chat_runtime_state
.Lrestored: .asciz "Saved chat restored. Use Chat: Resume Conversation to reconnect."
.Lresume_prefix: .asciz "{\"id\":\"thread\",\"method\":\"thread/resume\",\"params\":{\"threadId\":"
.Lresume_cwd: .asciz ",\"cwd\":"

.Ltext_end: .asciz "}"
.Larray_end: .asciz "]}}\n"

.Litem_started: .asciz "item/started"
.Litem_completed: .asciz "item/completed"
.Litem_key: .asciz "item"
.Litem_id_key: .asciz "itemId"

.section .rodata
.Lgrok: .asciz "grok"
.Lpi: .asciz "pi"
.Lgrok_agent: .asciz "agent"
.Lgrok_no_leader: .asciz "--no-leader"
.Lgrok_stdio: .asciz "stdio"
.Lpi_mode: .asciz "--mode"
.Lpi_rpc: .asciz "rpc"
.Lpi_tools: .asciz "--tools"
.Lpi_readonly: .asciz "read,grep,find,ls"
.Lpi_session: .asciz "--session"

.section .rodata
.Lturn_id_key: .asciz "turnId"

.section .rodata
.Lno_rollout: .asciz "no rollout found for thread id "
.Lno_rollout_end:
.Lempty_recovered: .asciz "Codex empty conversation reopened; draft retained"
