# ACP agent adapter, using the owned stdio runtime and bounded framing.
.include "rhun.inc"
.bss
.p2align 3
models: .zero SB_SIZE
mirror_previous: .zero SB_SIZE
mirror_current: .zero SB_SIZE
mirror_source: .long 0
notification_source: .long 0
notification_wrapped: .long 0
model_config_id: .zero SB_SIZE
model_legacy: .long 0
.p2align 3
catalog_count: .long 0
load_supported: .long 0
.globl chat_acp_image_supported
chat_acp_image_supported: .long 0
.text

FN chat_acp_prompt
    PROLOGUE
    mov r12, rdi
    mov r13, rsi
    lea rdi, [rip + .Lprompt_prefix]
    call chat_runtime_append
    mov rdi, [rip + chat_runtime_session]
    call chat_runtime_quote
    lea rdi, [rip + .Lprompt_text]
    call chat_runtime_append
    lea rdi, [rip + chat_runtime_request]
    mov rsi, r12
    mov rdx, r13
    call chat_json_quote
    lea rdi, [rip + .Ltext_end]
    call chat_runtime_append
    call chat_context_images
    lea rdi, [rip + .Larray_end]
    call chat_runtime_append
    call chat_runtime_send
    EPILOGUE

FN chat_acp_cancel
    PROLOGUE
    call chat_acp_cancel_permissions
    test eax, eax
    js 9f
    lea rdi, [rip + chat_runtime_request]
    call sb_clear
    lea rdi, [rip + .Lcancel_prefix]
    call chat_runtime_append
    mov rdi, [rip + chat_runtime_session]
    call chat_runtime_quote
    lea rdi, [rip + .Lobject_suffix]
    call chat_runtime_append
    call chat_runtime_send
9:  EPILOGUE

FN chat_acp_models
    cmp dword ptr [rip + chat_runtime_state], 3
    je 1f
    ret
1:  mov edi, 3
    mov rsi, [rip + models + SB_ptr]
    mov rdx, [rip + models + SB_len]
    test rdx, rdx
    jnz agents_chat_event
    lea rsi, [rip + .Lno_models]
    mov rdi, rsi
    call strlen
    mov rdx, rax
    lea rsi, [rip + .Lno_models]
    mov edi, 3
    jmp agents_chat_event

FN chat_acp_choose_model
    mov rdi, [rip + models + SB_ptr]
    test rdi, rdi
    jz 1f
    cmp byte ptr [rdi], 0
    je 1f
    lea rsi, [rip + set_acp_model]
    lea rdx, [rip + .Lchoose_model]
    jmp palette_choose
1:  lea rdi, [rip + .Lno_models]
    jmp app_toast

set_acp_model:
    PROLOGUE
    mov r12, rdi
    cmp dword ptr [rip + chat_runtime_state], 3
    jne 9f
    lea rdi, [rip + chat_runtime_request]
    call sb_clear
    lea rdi, [rip + .Lset_config_prefix]
    cmp dword ptr [rip + model_legacy], 0
    je 1f
    lea rdi, [rip + .Lset_model_prefix]
1:  call chat_runtime_append
    mov rdi, [rip + chat_runtime_session]
    call chat_runtime_quote
    cmp dword ptr [rip + model_legacy], 0
    jne 2f
    lea rdi, [rip + .Lconfig_id_prefix]
    call chat_runtime_append
    mov rdi, [rip + model_config_id + SB_ptr]
    call chat_runtime_quote
    lea rdi, [rip + .Lvalue_prefix]
    jmp 3f
2:  lea rdi, [rip + .Lmodel_id_prefix]
3:  call chat_runtime_append
    mov rdi, r12
    call chat_runtime_quote
    lea rdi, [rip + .Lobject_suffix]
    call chat_runtime_append
    call chat_runtime_send
    test rax, rax
    js 9f
    mov dword ptr [rip + chat_runtime_state], 5
    call time_ms
    add rax, 15000
    mov [rip + chat_runtime_deadline], rax
    lea rax, [rip + .Lsetting_model]
    mov [rip + chat_runtime_status], rax
    mov dword ptr [rip + g_focus], FOCUS_AGENTS
9:  EPILOGUE

# Preferred ACP model catalog: configOptions, including grouped select values.
read_config_models:
    PROLOGUE
    lea rsi, [rip + .Lconfig_options]
    call json_get
    mov r12, rax
    test rax, rax
    jz 9f
    lea rdi, [rip + models]
    call sb_clear
    mov dword ptr [rip + catalog_count], 0
    mov dword ptr [rip + model_legacy], 0
    lea rdi, [rip + model_config_id]
    call sb_clear
    xor r13d, r13d
1:  mov rdi, r12
    call json_len
    cmp r13, rax
    jae 9f
    cmp r13, 64
    jae 9f
    mov rdi, r12
    mov rsi, r13
    call json_at
    mov r14, rax
    mov rdi, rax
    lea rsi, [rip + .Lcategory]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Lmodel_category]
    call json_is
    test eax, eax
    jnz 2f
    mov rdi, r14
    lea rsi, [rip + .Lid]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Lmodel_category]
    call json_is
    test eax, eax
    jz 3f
2:  mov rdi, r14
    lea rsi, [rip + .Lid]
    call json_get
    mov rdi, rax
    call json_str
    mov rsi, rax
    lea rdi, [rip + model_config_id]
    call sb_push
    mov rdi, r14
    lea rsi, [rip + .Loptions]
    call json_get
    mov rdi, rax
    xor esi, esi
    call collect_model_values
    jmp 9f
3:  inc r13
    jmp 1b
9:  EPILOGUE

collect_model_values:
    PROLOGUE
    mov r12, rdi
    mov r14d, esi
    xor r13d, r13d
1:  cmp dword ptr [rip + catalog_count], 100
    jae 9f
    mov rdi, r12
    call json_len
    cmp r13, rax
    jae 9f
    cmp r13, 100
    jae 9f
    mov rdi, r12
    mov rsi, r13
    call json_at
    mov rbx, rax
    mov rdi, rax
    lea rsi, [rip + .Lvalue]
    call json_get
    mov rdi, rax
    call json_str
    test rdx, rdx
    jz 2f
    mov rsi, rax
    lea rdi, [rip + models]
    call sb_push
    lea rdi, [rip + models]
    mov esi, 10
    call sb_push_byte
    inc dword ptr [rip + catalog_count]
    jmp 3f
2:  test r14d, r14d
    jnz 3f
    mov rdi, rbx
    lea rsi, [rip + .Loptions]
    call json_get
    mov rdi, rax
    mov esi, 1
    call collect_model_values
3:  inc r13
    jmp 1b
9:  EPILOGUE

# Consume one complete raw frame; copy retained values out of the JSON arena.
FN chat_acp_record
    PROLOGUE
    mov r14, rdi
    mov r15, rsi
    call json_parse_complete
    test rax, rax
    jz .Lbad
    mov rbx, rax
    mov rdi, rax
    call json_type
    cmp eax, JT_OBJ
    jne .Lbad
    mov rdi, rbx
    lea rsi, [rip + .Lmethod]
    call json_get
    mov r12, rax
    test rax, rax
    jnz .Lnotification
    mov rdi, rbx
    lea rsi, [rip + .Lid]
    call json_get
    mov r12, rax
    test rax, rax
    jz .Ldone
    mov rdi, rbx
    lea rsi, [rip + .Lerror]
    call json_get
    test rax, rax
    jnz .Lrpc_error
    mov rdi, rbx
    lea rsi, [rip + .Lresult]
    call json_get
    mov r13, rax
    mov rdi, r12
    lea rsi, [rip + .Lsetmodel_id]
    call json_is
    test eax, eax
    jz 1f
    cmp dword ptr [rip + chat_runtime_state], 5
    jne .Ldone
    mov rdi, r13
    call read_config_models
    mov dword ptr [rip + chat_runtime_state], 3
    lea rax, [rip + .Lready]
    mov [rip + chat_runtime_status], rax
    jmp .Ldone
1:  mov rdi, r12
    lea rsi, [rip + .Linit]
    call json_is
    test eax, eax
    jnz .Linitialized
    mov rdi, r12
    lea rsi, [rip + .Lthread]
    call json_is
    test eax, eax
    jnz .Lsession
    mov rdi, r12
    lea rsi, [rip + .Lturn]
    call json_is
    test eax, eax
    jz .Ldone
    cmp dword ptr [rip + chat_runtime_state], 4
    jne .Ldone
    mov rdi, r13
    lea rsi, [rip + .Lstop_reason]
    call json_get
    mov rdi, rax
    call json_str
    test rdx, rdx
    jz .Lbad
    lea rax, [rip + .Lready]
    mov [rip + chat_runtime_status], rax
    mov dword ptr [rip + chat_runtime_state], 3
    mov dword ptr [rip + chat_runtime_stop], 0
    call chat_interactions_clear
    jmp .Ldone
.Linitialized:
    lea rdi, [rip + mirror_previous]
    call sb_clear
    cmp dword ptr [rip + chat_runtime_state], 1
    jne .Ldone
    mov rdi, r13
    lea rsi, [rip + .Lversion]
    call json_get
    mov rdi, rax
    call json_number_text
    cmp rdx, 1
    jne .Lbad
    cmp byte ptr [rax], '1'
    jne .Lbad
    mov rdi, r13
    lea rsi, [rip + .Lcapabilities]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Lprompt_capabilities]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Limage_capability]
    call json_get
    mov rdi, rax
    call json_type
    cmp eax, JT_TRUE
    sete al
    movzx eax, al
    mov [rip + chat_acp_image_supported], eax
    mov rdi, r13
    lea rsi, [rip + .Lcapabilities]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Lload_capability]
    call json_get
    mov rdi, rax
    call json_type
    cmp eax, JT_TRUE
    sete al
    movzx eax, al
    mov [rip + load_supported], eax
    lea rdi, [rip + models]
    call sb_clear
    lea rdi, [rip + chat_runtime_request]
    call sb_clear
    mov rax, [rip + chat_resume_id]
    test rax, rax
    jz 2f
    cmp byte ptr [rax], 0
    je 2f
    cmp dword ptr [rip + load_supported], 0
    je .Lbad
    lea rdi, [rip + .Lload_prefix]
    call chat_runtime_append
    mov rdi, [rip + chat_resume_id]
    call chat_runtime_quote
    lea rdi, [rip + .Lload_cwd]
    call chat_runtime_append
    jmp 3f
2:  lea rdi, [rip + .Lnew_prefix]
    call chat_runtime_append
3:  mov rdi, [rip + g_project]
    call chat_runtime_quote
    lea rdi, [rip + .Lnew_suffix]
    call chat_runtime_append
    call chat_runtime_send
    test rax, rax
    js .Lbad
    mov dword ptr [rip + chat_runtime_state], 2
    jmp .Ldone
.Lsession:
    cmp dword ptr [rip + chat_runtime_state], 2
    jne .Ldone
    mov rdi, r13
    lea rsi, [rip + .Lsession_id]
    call json_get
    mov rdi, rax
    call json_str
    test rdx, rdx
    jnz 1f
    mov rax, [rip + chat_resume_id]
    test rax, rax
    jz .Lbad
    cmp byte ptr [rax], 0
    je .Lbad
    mov rdi, rax
    call strlen
    mov rdx, rax
    mov rax, [rip + chat_resume_id]
1:  mov rdi, rax
    mov rsi, rdx
    call mem_dup
    mov [rip + chat_runtime_session], rax
    mov rdi, rax
    call chat_store_native_id
    mov rdi, r13
    call read_config_models
    cmp qword ptr [rip + models + SB_len], 0
    jne .Lsession_ready
    mov dword ptr [rip + model_legacy], 1
    mov rdi, r13
    lea rsi, [rip + .Lmodels]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Lavailable]
    call json_get
    mov r12, rax
    xor r13d, r13d
.Lmodel_loop:
    mov rdi, r12
    call json_len
    cmp r13, rax
    jae .Lsession_ready
    cmp r13, 100
    jae .Lsession_ready
    mov rdi, r12
    mov rsi, r13
    call json_at
    mov rdi, rax
    lea rsi, [rip + .Lmodel_id]
    call json_get
    mov rdi, rax
    call json_str
    mov rsi, rax
    lea rdi, [rip + models]
    call sb_push
    lea rdi, [rip + models]
    mov esi, 10
    call sb_push_byte
    inc r13
    jmp .Lmodel_loop
.Lsession_ready:
    call chat_store_dirty
    mov dword ptr [rip + chat_runtime_state], 3
    lea rax, [rip + .Lready]
    mov [rip + chat_runtime_status], rax
    jmp .Ldone
.Lnotification:
    mov rdi, rbx
    lea rsi, [rip + .Lid]
    call json_get
    test rax, rax
    jnz .Lserver_request
    mov dword ptr [rip + notification_source], 1
    mov dword ptr [rip + notification_wrapped], 0
    mov rdi, r12
    lea rsi, [rip + .Lupdate_method]
    call json_is
    test eax, eax
    jnz 11f
    cmp dword ptr [rip + chat_provider], 2
    jne .Ldone
    mov dword ptr [rip + notification_source], 2
    mov rdi, r12
    lea rsi, [rip + .Lgrok_update]
    call json_is
    test eax, eax
    jnz 11f
    mov rdi, r12
    lea rsi, [rip + .Lgrok_update_alt]
    call json_is
    test eax, eax
    jnz 11f
    mov rdi, r12
    lea rsi, [rip + .Lgrok_wrapped]
    call json_is
    test eax, eax
    jz .Ldone
    mov dword ptr [rip + notification_wrapped], 1
11: mov rdi, rbx
    lea rsi, [rip + .Lparams]
    call json_get
    cmp dword ptr [rip + notification_wrapped], 0
    je 12f
    mov r13, rax
    mov rdi, rax
    lea rsi, [rip + .Lmethod]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Lgrok_inner]
    call json_is
    test eax, eax
    jz .Ldone
    mov rdi, r13
    lea rsi, [rip + .Lparams]
    call json_get
12: mov r13, rax
    cmp dword ptr [rip + chat_provider], 2
    jne 13f
    mov rdi, rax
    call dedup_mirror
    test eax, eax
    jz .Ldone
13: mov rax, r13
    mov rdi, rax
    lea rsi, [rip + .Lsession_id]
    call json_get
    mov rdi, rax
    mov rsi, [rip + chat_runtime_session]
    test rsi, rsi
    jz .Ldone
    call json_is
    test eax, eax
    jz .Ldone
    mov rdi, r13
    lea rsi, [rip + .Lupdate]
    call json_get
    mov r13, rax
    mov rdi, rax
    lea rsi, [rip + .Lupdate_type]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Lconfig_update]
    call json_is
    test eax, eax
    jz 1f
    mov rdi, r13
    call read_config_models
    jmp .Ldone
1:  cmp dword ptr [rip + chat_runtime_state], 4
    jne .Ldone
    mov rdi, r13
    lea rsi, [rip + .Lupdate_type]
    call json_get
    mov r12, rax
    mov rdi, rax
    lea rsi, [rip + .Ltool_call]
    call json_is
    test eax, eax
    jnz .Ltool_update
    mov rdi, r12
    lea rsi, [rip + .Ltool_call_update]
    call json_is
    test eax, eax
    jnz .Ltool_update
    mov rdi, r12
    lea rsi, [rip + .Lagent_chunk]
    call json_is
    test eax, eax
    jz .Ldone
    mov rdi, r13
    lea rsi, [rip + .Lcontent]
    call json_get
    mov r13, rax
    mov rdi, rax
    lea rsi, [rip + .Ltype]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Ltext]
    call json_is
    test eax, eax
    jz .Ldone
    mov rdi, r13
    lea rsi, [rip + .Ltext]
    call json_get
    mov rdi, rax
    call json_str
    test rdx, rdx
    jz .Ldone
    mov rcx, [rip + chat_runtime_answer + SB_len]
    add rcx, rdx
    cmp rcx, CHAT_FRAME_LIMIT
    ja .Lbad
    lea rdi, [rip + chat_runtime_answer]
    mov rsi, rax
    call sb_push
    mov edi, 2
    mov rsi, [rip + chat_runtime_answer + SB_ptr]
    mov rdx, [rip + chat_runtime_answer + SB_len]
    call agents_chat_event
    jmp .Ldone
.Ltool_update:
    lea rdi, [rip + chat_runtime_answer]
    call sb_clear
    call agents_chat_answer_boundary
    mov rdi, r13
    call chat_render_acp_tool
    jmp .Ldone
.Lserver_request:
    mov rdi, r14
    mov rsi, r15
    call chat_interaction_receive
    test eax, eax
    js .Lbad
    jmp .Ldone
.Lrpc_error:
    mov rdi, rax
    lea rsi, [rip + .Lmessage]
    call json_get
    mov rdi, rax
    call json_str
    test rdx, rdx
    jz 1f
    mov rsi, rax
    mov edi, 3
    call agents_chat_event
1:  cmp dword ptr [rip + chat_runtime_state], 5
    je 2f
    cmp dword ptr [rip + chat_runtime_state], 4
    jne .Lbad
2:
    mov dword ptr [rip + chat_runtime_state], 3
    mov dword ptr [rip + chat_runtime_stop], 0
    call chat_interactions_clear
    lea rax, [rip + .Lturn_error]
    mov [rip + chat_runtime_status], rax
    jmp .Ldone
.Lbad:
    call chat_shutdown
    lea rax, [rip + .Lprotocol_error]
    mov [rip + chat_runtime_status], rax
.Ldone:
    mov dword ptr [rip + g_dirty], 1
    EPILOGUE

# Suppress only a consecutive identical notification from the other wire alias.
dedup_mirror:
    PROLOGUE
    mov r12, rdi
    lea rdi, [rip + mirror_current]
    call sb_clear
    lea rdi, [rip + mirror_current]
    mov rsi, r12
    call json_dump
    mov eax, [rip + notification_source]
    cmp eax, [rip + mirror_source]
    je 2f
    mov rdx, [rip + mirror_current + SB_len]
    cmp rdx, [rip + mirror_previous + SB_len]
    jne 2f
    mov rdi, [rip + mirror_current + SB_ptr]
    mov rsi, [rip + mirror_previous + SB_ptr]
    call memeq
    test eax, eax
    jz 2f
    lea rdi, [rip + mirror_previous]
    call sb_clear
    xor eax, eax
    EPILOGUE
2:  lea rdi, [rip + mirror_previous]
    call sb_clear
    lea rdi, [rip + mirror_previous]
    mov rsi, [rip + mirror_current + SB_ptr]
    mov rdx, [rip + mirror_current + SB_len]
    call sb_push
    mov eax, [rip + notification_source]
    mov [rip + mirror_source], eax
    mov eax, 1
    EPILOGUE

.section .rodata
.globl acp_initialize_packet
acp_initialize_packet: .asciz "{\"jsonrpc\":\"2.0\",\"id\":\"init\",\"method\":\"initialize\",\"params\":{\"protocolVersion\":1,\"clientCapabilities\":{},\"clientInfo\":{\"name\":\"rhun\",\"version\":\"0.1.0\"}}}\n"
.Lnew_prefix: .asciz "{\"jsonrpc\":\"2.0\",\"id\":\"thread\",\"method\":\"session/new\",\"params\":{\"cwd\":"
.Lnew_suffix: .asciz ",\"mcpServers\":[]}}\n"
.Lprompt_prefix: .asciz "{\"jsonrpc\":\"2.0\",\"id\":\"turn\",\"method\":\"session/prompt\",\"params\":{\"sessionId\":"
.Lprompt_text: .asciz ",\"prompt\":[{\"type\":\"text\",\"text\":"
.Lprompt_suffix: .asciz "}]}}\n"
.Lcancel_prefix: .asciz "{\"jsonrpc\":\"2.0\",\"method\":\"session/cancel\",\"params\":{\"sessionId\":"
.Lobject_suffix: .asciz "}}\n"
.Linit: .asciz "init"
.Lthread: .asciz "thread"
.Lturn: .asciz "turn"
.Lid: .asciz "id"
.Lversion: .asciz "protocolVersion"
.Lmethod: .asciz "method"
.Lparams: .asciz "params"
.Lresult: .asciz "result"
.Lerror: .asciz "error"
.Lmessage: .asciz "message"
.Lsession_id: .asciz "sessionId"
.Lupdate_method: .asciz "session/update"
.Lupdate: .asciz "update"
.Lupdate_type: .asciz "sessionUpdate"
.Lagent_chunk: .asciz "agent_message_chunk"
.Lcontent: .asciz "content"
.Ltype: .asciz "type"
.Ltext: .asciz "text"
.Lmodels: .asciz "models"
.Lavailable: .asciz "availableModels"
.Lmodel_id: .asciz "modelId"
.Lstop_reason: .asciz "stopReason"
.Lready: .asciz "ACP agent ready"
.Lturn_error: .asciz "OpenCode turn failed. You can try another message."
.Lprotocol_error: .asciz "Invalid ACP agent response or failed initialization"
.Lno_models: .asciz "OpenCode did not advertise a model catalog. Configure the model in its CLI."

.Lconfig_options: .asciz "configOptions"
.Lcategory: .asciz "category"
.Lmodel_category: .asciz "model"
.Loptions: .asciz "options"
.Lvalue: .asciz "value"
.Lconfig_update: .asciz "config_option_update"

.Lchoose_model: .asciz "Choose OpenCode model"
.Lsetting_model: .asciz "Changing OpenCode model..."
.Lsetmodel_id: .asciz "setmodel"
.Lset_config_prefix: .asciz "{\"jsonrpc\":\"2.0\",\"id\":\"setmodel\",\"method\":\"session/set_config_option\",\"params\":{\"sessionId\":"
.Lset_model_prefix: .asciz "{\"jsonrpc\":\"2.0\",\"id\":\"setmodel\",\"method\":\"session/set_model\",\"params\":{\"sessionId\":"
.Lconfig_id_prefix: .asciz ",\"configId\":"
.Lvalue_prefix: .asciz ",\"value\":"
.Lmodel_id_prefix: .asciz ",\"modelId\":"

.Lcapabilities: .asciz "agentCapabilities"
.Lload_capability: .asciz "loadSession"
.Lload_prefix: .asciz "{\"jsonrpc\":\"2.0\",\"id\":\"thread\",\"method\":\"session/load\",\"params\":{\"sessionId\":"
.Lload_cwd: .asciz ",\"cwd\":"

.Ltext_end: .asciz "}"
.Larray_end: .asciz "]}}\n"
.Lprompt_capabilities: .asciz "promptCapabilities"
.Limage_capability: .asciz "image"

.Ltool_call: .asciz "tool_call"
.Ltool_call_update: .asciz "tool_call_update"

.section .rodata
.Lgrok_update: .asciz "_x.ai/session/update"

.section .rodata
.Lgrok_update_alt: .asciz "x.ai/session/update"
.Lgrok_wrapped: .asciz "_x.ai/session_notification"
.Lgrok_inner: .asciz "x.ai/session_notification"
