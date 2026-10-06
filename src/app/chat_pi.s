# Pi's native JSONL RPC. Built-in tools are restricted to read/grep/find/ls.
.include "rhun.inc"
.bss
.p2align 3
models: .zero SB_SIZE
notice: .zero SB_SIZE
ui_id: .zero SB_SIZE
ui_title: .zero SB_SIZE
ui_choices: .zero SB_SIZE
select_mode: .long 0
.globl chat_pi_pending
chat_pi_pending: .long 0
.text
FN chat_pi_clear_ui
    PROLOGUE
    mov dword ptr [rip + chat_pi_pending], 0
    mov dword ptr [rip + select_mode], 0
    lea rdi, [rip + select_chosen]
    call palette_close_choose
    test eax, eax
    jz 1f
    mov dword ptr [rip + g_focus], FOCUS_AGENTS
1:  EPILOGUE
FN chat_pi_label
    mov rax, [rip + ui_title + SB_ptr]
    test rax, rax
    jnz 1f
    lea rax, [rip + .Lquestion_hint]
1:  ret
FN chat_pi_prompt
    PROLOGUE
    mov r12, rdi
    mov r13, rsi
    lea rdi, [rip + .Lprompt]
    call chat_runtime_append
    lea rdi, [rip + chat_runtime_request]
    mov rsi, r12
    mov rdx, r13
    call chat_json_quote
    lea rdi, [rip + .Lend]
    call chat_runtime_append
    call chat_runtime_send
    EPILOGUE
FN chat_pi_cancel
    PROLOGUE
    cmp dword ptr [rip + chat_pi_pending], 0
    je 1f
    call cancel_ui
1:  lea rdi, [rip + chat_runtime_request]
    call sb_clear
    lea rdi, [rip + .Labort]
    call chat_runtime_append
    call chat_runtime_send
    EPILOGUE
FN chat_pi_models
    cmp dword ptr [rip + chat_runtime_state], 3
    jne 1f
    lea rdi, [rip + .Lmodels_command]
    jmp send_literal
1:  ret
send_literal:
    PROLOGUE
    mov r12, rdi
    lea rdi, [rip + chat_runtime_request]
    call sb_clear
    mov rdi, r12
    call chat_runtime_append
    call chat_runtime_send
    EPILOGUE

set_model:
    PROLOGUE
    mov r12, rdi
    xor ebx, ebx
1:  cmp byte ptr [r12 + rbx], 0
    je 9f
    cmp byte ptr [r12 + rbx], '/'
    je 2f
    inc rbx
    jmp 1b
2:  lea rdi, [rip + chat_runtime_request]
    call sb_clear
    lea rdi, [rip + .Lset_model]
    call chat_runtime_append
    lea rdi, [rip + chat_runtime_request]
    mov rsi, r12
    mov rdx, rbx
    call chat_json_quote
    lea rdi, [rip + .Lmodel_id]
    call chat_runtime_append
    lea rdi, [r12 + rbx + 1]
    call chat_runtime_quote
    lea rdi, [rip + .Lend]
    call chat_runtime_append
    call chat_runtime_send
    test rax, rax
    js 9f
    mov dword ptr [rip + g_focus], FOCUS_AGENTS
    mov dword ptr [rip + chat_runtime_state], 5
    call time_ms
    add rax, 15000
    mov [rip + chat_runtime_deadline], rax
9:  EPILOGUE

FN chat_pi_record
    PROLOGUE
    call json_parse_complete
    test rax, rax
    jz .Lbad
    mov r12, rax
    mov rdi, rax
    lea rsi, [rip + .Ltype]
    call json_get
    mov r13, rax
    mov rdi, rax
    lea rsi, [rip + .Lresponse]
    call json_is
    test eax, eax
    jnz .Lresponse_record
    mov rdi, r13
    lea rsi, [rip + .Lui_request]
    call json_is
    test eax, eax
    jnz .Lui
    cmp dword ptr [rip + chat_runtime_state], 4
    jne .Ldone
    mov rdi, r13
    lea rsi, [rip + .Lsettled]
    call json_is
    test eax, eax
    jnz .Lsettled_record
    mov rdi, r13
    lea rsi, [rip + .Lmessage_start]
    call json_is
    test eax, eax
    jnz .Lboundary
    mov rdi, r13
    lea rsi, [rip + .Lmessage_update]
    call json_is
    test eax, eax
    jnz .Ldelta
    mov rdi, r13
    call json_str
    cmp rdx, 15
    jb .Ldone
    mov rdi, rax
    mov rsi, rdx
    lea rdx, [rip + .Ltool_prefix]
    mov ecx, 15
    call str_starts
    test eax, eax
    jz .Ldone
    lea rdi, [rip + notice]
    call sb_clear
    lea rdi, [rip + notice]
    mov rsi, r12
    call json_dump
    cmp qword ptr [rip + notice + SB_len], 65536
    ja .Ldone
    mov edi, 3
    mov rsi, [rip + notice + SB_ptr]
    mov rdx, [rip + notice + SB_len]
    call agents_chat_event
    jmp .Ldone
.Lboundary:
    lea rdi, [rip + chat_runtime_answer]
    call sb_clear
    call agents_chat_answer_boundary
    jmp .Ldone
.Ldelta:
    mov rdi, r12
    lea rsi, [rip + .Lassistant_event]
    call json_get
    mov r14, rax
    mov rdi, rax
    lea rsi, [rip + .Ltype]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Ltext_delta]
    call json_is
    test eax, eax
    jz .Ldone
    mov rdi, r14
    lea rsi, [rip + .Ldelta_key]
    call json_get
    mov rdi, rax
    call json_str
    test rax, rax
    jz .Lbad
    mov rcx, [rip + chat_runtime_answer + SB_len]
    add rcx, rdx
    cmp rcx, 1 << 20
    ja .Lbad
    lea rdi, [rip + chat_runtime_answer]
    mov rsi, rax
    call sb_push
    mov edi, 2
    mov rsi, [rip + chat_runtime_answer + SB_ptr]
    mov rdx, [rip + chat_runtime_answer + SB_len]
    call agents_chat_event
    jmp .Ldone
.Lsettled_record:
    call ready
    lea rdi, [rip + .Lget_state]
    call send_literal
    jmp .Ldone
.Lresponse_record:
    mov rdi, r12
    lea rsi, [rip + .Lsuccess]
    call json_get
    mov rdi, rax
    call json_type
    cmp eax, JT_TRUE
    jne .Lerror
    mov rdi, r12
    lea rsi, [rip + .Lcommand]
    call json_get
    mov r13, rax
    mov rdi, rax
    lea rsi, [rip + .Lstate_command]
    call json_is
    test eax, eax
    jnz .Lstate
    mov rdi, r13
    lea rsi, [rip + .Lmodel_command]
    call json_is
    test eax, eax
    jnz .Lmodel_ack
    mov rdi, r13
    lea rsi, [rip + .Lavailable_models]
    call json_is
    test eax, eax
    jnz .Lmodel_catalog
    mov rdi, r13
    lea rsi, [rip + .Lprompt_command]
    call json_is
    test eax, eax
    jz .Ldone
    mov rdi, r12
    lea rsi, [rip + .Lprompt_response_id]
    call response_id
    test eax, eax
    jz .Ldone
    cmp dword ptr [rip + chat_runtime_state], 4
    jne .Ldone
    mov rdi, r12
    lea rsi, [rip + .Ldata]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Ldisposition]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Lhandled]
    call json_is
    test eax, eax
    jz .Ldone
    call ready
    jmp .Ldone
.Lmodel_ack:
    mov rdi, r12
    lea rsi, [rip + .Lmodel_response_id]
    call response_id
    test eax, eax
    jz .Ldone
    cmp dword ptr [rip + chat_runtime_state], 5
    jne .Ldone
    call ready
    jmp .Ldone
.Lstate:
    mov rdi, r12
    lea rsi, [rip + .Linit_response_id]
    cmp dword ptr [rip + chat_runtime_state], 1
    je 11f
    lea rsi, [rip + .Lstate_response_id]
11: call response_id
    test eax, eax
    jz .Ldone
    mov rdi, r12
    lea rsi, [rip + .Ldata]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Lsession_file]
    call json_get
    mov rdi, rax
    call json_str
    test rax, rax
    jz 1f
    cmp rdx, 1024
    ja .Lbad
    mov rdi, rax
    call chat_store_native_id
1:  cmp dword ptr [rip + chat_runtime_state], 1
    jne .Ldone
    call ready
    jmp .Ldone
.Lmodel_catalog:
    mov rdi, r12
    lea rsi, [rip + .Lmodels_response_id]
    call response_id
    test eax, eax
    jz .Ldone
    cmp dword ptr [rip + chat_runtime_state], 3
    jne .Ldone
    mov rdi, r12
    lea rsi, [rip + .Ldata]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Lmodels]
    call json_get
    mov r14, rax
    lea rdi, [rip + models]
    call sb_clear
    xor ebx, ebx
1:  mov rdi, r14
    call json_len
    cmp rbx, rax
    jae 3f
    cmp rbx, 100
    jae 3f
    mov rdi, r14
    mov rsi, rbx
    call json_at
    mov r15, rax
    mov rdi, rax
    lea rsi, [rip + .Lprovider]
    call json_get
    mov rdi, rax
    call json_str
    test rax, rax
    jz 2f
    cmp rdx, 256
    ja 2f
    lea rdi, [rip + models]
    mov rsi, rax
    call sb_push
    lea rdi, [rip + models]
    mov esi, '/'
    call sb_push_byte
    mov rdi, r15
    lea rsi, [rip + .Lid]
    call json_get
    mov rdi, rax
    call json_str
    test rax, rax
    jz .Lbad
    cmp rdx, 1024
    ja .Lbad
    lea rdi, [rip + models]
    mov rsi, rax
    call sb_push
    lea rdi, [rip + models]
    mov esi, 10
    call sb_push_byte
2:  inc rbx
    jmp 1b
3:  cmp qword ptr [rip + models + SB_len], 0
    je .Ldone
    mov rdi, [rip + models + SB_ptr]
    lea rsi, [rip + set_model]
    lea rdx, [rip + .Lchoose]
    call palette_choose
    jmp .Ldone
.Lui:
    # Fire-and-forget extension UI updates can arrive during a blocking dialog.
    mov rdi, r12
    lea rsi, [rip + .Lmethod]
    call json_get
    mov r14, rax
    mov rdi, rax
    lea rsi, [rip + .Lconfirm]
    call json_is
    test eax, eax
    jnz 11f
    mov rdi, r14
    lea rsi, [rip + .Linput]
    call json_is
    test eax, eax
    jnz 11f
    mov rdi, r14
    lea rsi, [rip + .Leditor]
    call json_is
    test eax, eax
    jnz 11f
    mov rdi, r14
    lea rsi, [rip + .Lselect]
    call json_is
    test eax, eax
    jz .Ldone
11: # One blocking extension dialog at a time; retain copied IDs and text.
    cmp dword ptr [rip + chat_pi_pending], 0
    jne .Lbad
    mov dword ptr [rip + select_mode], 0
    mov rdi, r12
    lea rsi, [rip + .Lid]
    call json_get
    mov r13, rax
    mov rdi, rax
    call json_str
    test rax, rax
    jz .Lbad
    cmp rdx, 1024
    ja .Lbad
    lea rdi, [rip + ui_id]
    call sb_clear
    lea rdi, [rip + ui_id]
    mov rsi, r13
    call json_dump
    mov rdi, r12
    lea rsi, [rip + .Lmethod]
    call json_get
    mov r13, rax
    mov rdi, rax
    lea rsi, [rip + .Lconfirm]
    call json_is
    test eax, eax
    jz 1f
    mov dword ptr [rip + chat_pi_pending], 1
    jmp 3f
1:  mov rdi, r13
    lea rsi, [rip + .Linput]
    call json_is
    test eax, eax
    jnz 2f
    mov rdi, r13
    lea rsi, [rip + .Leditor]
    call json_is
    test eax, eax
    jz 4f
2:  mov dword ptr [rip + chat_pi_pending], 2
3:
.Lui_show_title:
    mov rdi, r12
    lea rsi, [rip + .Ltitle_key]
    call json_get
    mov rdi, rax
    call json_str
    test rax, rax
    jz .Ldone
    cmp rdx, 4096
    ja .Lbad
    mov r14, rax
    mov r15, rdx
    lea rdi, [rip + ui_title]
    call sb_clear
    lea rdi, [rip + ui_title]
    mov rsi, r14
    mov rdx, r15
    call sb_push
    mov rsi, r14
    mov rdx, r15
    mov edi, 3
    call agents_chat_event
    cmp dword ptr [rip + select_mode], 0
    je .Ldone
    mov rdi, [rip + ui_choices + SB_ptr]
    lea rsi, [rip + select_chosen]
    lea rdx, [rip + .Lselect_hint]
    call palette_choose
    jmp .Ldone
4:  mov rdi, r13
    lea rsi, [rip + .Lselect]
    call json_is
    test eax, eax
    jz .Ldone
    jmp .Lselect_request
.Lselect_request:
    mov rdi, r12
    lea rsi, [rip + .Loptions]
    call json_get
    mov r14, rax
    mov rdi, rax
    call json_len
    test rax, rax
    jz .Lcancel_select
    cmp rax, 128
    ja .Lcancel_select
    lea rdi, [rip + ui_choices]
    call sb_clear
    xor ebx, ebx
1:  mov rdi, r14
    call json_len
    cmp rbx, rax
    jae 3f
    mov rdi, r14
    mov rsi, rbx
    call json_at
    mov rdi, rax
    call json_str
    test rdx, rdx
    jz .Lcancel_select
    cmp rdx, 1024
    ja .Lcancel_select
    xor ecx, ecx
2:  cmp rcx, rdx
    jae 21f
    cmp byte ptr [rax + rcx], 10
    je .Lcancel_select
    cmp byte ptr [rax + rcx], 13
    je .Lcancel_select
    cmp byte ptr [rax + rcx], 0
    je .Lcancel_select
    inc rcx
    jmp 2b
21: lea rdi, [rip + ui_choices]
    mov rsi, rax
    call sb_push
    lea rdi, [rip + ui_choices]
    mov esi, 10
    call sb_push_byte
    inc rbx
    jmp 1b
3:  mov dword ptr [rip + select_mode], 1
    mov dword ptr [rip + chat_pi_pending], 2
    jmp .Lui_show_title
.Lcancel_select:
    call cancel_ui
    jmp .Ldone
.Lerror:
    mov rdi, r12
    lea rsi, [rip + .Lprompt_response_id]
    cmp dword ptr [rip + chat_runtime_state], 4
    je 11f
    lea rsi, [rip + .Lmodel_response_id]
    cmp dword ptr [rip + chat_runtime_state], 5
    je 11f
    lea rsi, [rip + .Linit_response_id]
    cmp dword ptr [rip + chat_runtime_state], 1
    je 11f
    lea rsi, [rip + .Lmodels_response_id]
11: call response_id
    test eax, eax
    jz .Ldone
    cmp dword ptr [rip + chat_runtime_state], 1
    je .Lbad
    call ready
    lea rdi, [rip + .Lfailed]
    call app_toast
    jmp .Ldone
.Lbad:
    call chat_shutdown
    lea rdi, [rip + .Lprotocol_error]
    call app_toast
.Ldone:
    mov dword ptr [rip + g_dirty], 1
    EPILOGUE
response_id:
    PROLOGUE
    mov rbx, rsi
    lea rsi, [rip + .Lid]
    call json_get
    mov rdi, rax
    mov rsi, rbx
    call json_is
    EPILOGUE
ready:
    PROLOGUE
    call chat_pi_clear_ui
    mov dword ptr [rip + chat_runtime_state], 3
    mov dword ptr [rip + chat_runtime_stop], 0
    lea rax, [rip + .Lready]
    mov [rip + chat_runtime_status], rax
    EPILOGUE
ui_prefix:
    PROLOGUE
    lea rdi, [rip + chat_runtime_request]
    call sb_clear
    lea rdi, [rip + .Lui_reply]
    call chat_runtime_append
    lea rdi, [rip + chat_runtime_request]
    mov rsi, [rip + ui_id + SB_ptr]
    mov rdx, [rip + ui_id + SB_len]
    call sb_push
    EPILOGUE
cancel_ui:
    PROLOGUE
    call ui_prefix
    lea rdi, [rip + .Lcancelled]
    call chat_runtime_append
    call chat_runtime_send
    call chat_pi_clear_ui
    EPILOGUE
FN chat_pi_decide
    PROLOGUE
    cmp dword ptr [rip + chat_pi_pending], 1
    jne 9f
    mov ebx, edi
    call ui_prefix
    lea rdi, [rip + .Lno]
    test ebx, ebx
    jz 1f
    lea rdi, [rip + .Lyes]
1:  call chat_runtime_append
    call chat_runtime_send
    mov dword ptr [rip + chat_pi_pending], 0
9:  EPILOGUE
FN chat_pi_answer
    PROLOGUE
    mov r12, rdi
    mov r13, rsi
    cmp dword ptr [rip + chat_pi_pending], 2
    jne 9f
    cmp r13, 65536
    ja 9f
    cmp dword ptr [rip + select_mode], 0
    je 11f
    mov rdi, r12
    mov rsi, r13
    call is_choice
    test eax, eax
    jz 9f
11: call ui_prefix
    lea rdi, [rip + .Lvalue]
    call chat_runtime_append
    lea rdi, [rip + chat_runtime_request]
    mov rsi, r12
    mov rdx, r13
    call chat_json_quote
    lea rdi, [rip + .Lend]
    call chat_runtime_append
    call chat_runtime_send
    test rax, rax
    js 9f
    mov dword ptr [rip + chat_pi_pending], 0
    mov eax, 1
    EPILOGUE
9:  xor eax, eax
    EPILOGUE
select_chosen:
    PROLOGUE
    mov r12, rdi
    call strlen
    mov rsi, rax
    mov rdi, r12
    call chat_pi_answer
    mov dword ptr [rip + g_focus], FOCUS_AGENTS
    EPILOGUE
is_choice:
    PROLOGUE
    mov r12, rdi
    mov r13, rsi
    xor r14d, r14d
1:  cmp r14, [rip + ui_choices + SB_len]
    jae 8f
    mov r15, r14
    mov rbx, [rip + ui_choices + SB_ptr]
2:  cmp byte ptr [rbx + r15], 10
    je 3f
    inc r15
    jmp 2b
3:  mov rax, r15
    sub rax, r14
    cmp rax, r13
    jne 4f
    lea rdi, [rbx + r14]
    mov rsi, r12
    mov rdx, r13
    call memeq
    test eax, eax
    jnz 9f
4:  lea r14, [r15 + 1]
    jmp 1b
8:  xor eax, eax
9:  EPILOGUE
.section .rodata
.globl pi_initialize_packet
pi_initialize_packet: .asciz "{\"id\":\"init\",\"type\":\"get_state\"}\n"
.Lget_state: .asciz "{\"id\":\"state\",\"type\":\"get_state\"}\n"
.Lprompt: .asciz "{\"id\":\"prompt\",\"type\":\"prompt\",\"message\":"
.Labort: .asciz "{\"id\":\"abort\",\"type\":\"abort\"}\n"
.Lmodels_command: .asciz "{\"id\":\"models\",\"type\":\"get_available_models\"}\n"
.Lset_model: .asciz "{\"id\":\"model\",\"type\":\"set_model\",\"provider\":"
.Lmodel_id: .asciz ",\"modelId\":"
.Lend: .asciz "}\n"
.Ltype: .asciz "type"
.Lresponse: .asciz "response"
.Lsuccess: .asciz "success"
.Lcommand: .asciz "command"
.Lstate_command: .asciz "get_state"
.Lmodel_command: .asciz "set_model"
.Lavailable_models: .asciz "get_available_models"
.Lprompt_command: .asciz "prompt"
.Ldata: .asciz "data"
.Ldisposition: .asciz "disposition"
.Lhandled: .asciz "handled"
.Lsession_file: .asciz "sessionFile"
.Lsettled: .asciz "agent_settled"
.Lmessage_start: .asciz "message_start"
.Lmessage_update: .asciz "message_update"
.Lassistant_event: .asciz "assistantMessageEvent"
.Ltext_delta: .asciz "text_delta"
.Ldelta_key: .asciz "delta"
.Lmodels: .asciz "models"
.Lprovider: .asciz "provider"
.Lid: .asciz "id"
.Lchoose: .asciz "Choose Pi provider/model"
.Lready: .asciz "Pi ready (read-only built-in tools)"
.Lfailed: .asciz "Pi command failed; check CLI configuration"
.Lprotocol_error: .asciz "Invalid Pi RPC record; runtime closed"
.Ltool_prefix: .asciz "tool_execution_"
.Lui_request: .asciz "extension_ui_request"
.Lmethod: .asciz "method"
.Lconfirm: .asciz "confirm"
.Linput: .asciz "input"
.Leditor: .asciz "editor"
.Ltitle_key: .asciz "title"
.Lui_reply: .asciz "{\"type\":\"extension_ui_response\",\"id\":"
.Lcancelled: .asciz ",\"cancelled\":true}\n"
.Lyes: .asciz ",\"confirmed\":true}\n"
.Lno: .asciz ",\"confirmed\":false}\n"
.Lvalue: .asciz ",\"value\":"

.section .rodata
.Lselect: .asciz "select"

.section .rodata
.Linit_response_id: .asciz "init"
.Lstate_response_id: .asciz "state"
.Lmodel_response_id: .asciz "model"
.Lmodels_response_id: .asciz "models"
.Lprompt_response_id: .asciz "prompt"

.section .rodata
.Lquestion_hint: .asciz "Pi extension awaits an explicit response"

.section .rodata
.Loptions: .asciz "options"
.Lselect_hint: .asciz "Choose Pi extension response"
