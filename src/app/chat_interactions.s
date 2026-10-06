# Owned interaction queue. Native request IDs are preserved across JSON parses.
.include "rhun.inc"
STRUCT
F IQ_id, 8
F IQ_text, 8
ENDSTRUCT IQ_SIZE
.bss
.p2align 3
pending: .zero VEC_SIZE         # owned raw JSON records
questions: .zero VEC_SIZE       # IQ entries, owned strings
head: .quad 0
question_index: .quad 0
kind: .long 0                  # 0 none, 1 approval, 2 questions
rpc_id: .zero SB_SIZE
summary: .zero SB_SIZE
reply: .zero SB_SIZE
answers: .zero SB_SIZE
acp_is_permission: .long 0
.p2align 3
acp_allow: .zero SB_SIZE
acp_reject: .zero SB_SIZE
.text
FN chat_pending_kind
    mov eax, [rip + kind]
    ret
FN chat_pending_label
    cmp dword ptr [rip + kind], 2
    jne 1f
    mov rax, [rip + question_index]
    imul rax, IQ_SIZE
    add rax, [rip + questions + VEC_ptr]
    mov rax, [rax + IQ_text]
    ret
1:  lea rax, [rip + .Lapproval_hint]
    ret

clear_questions:
    PROLOGUE
    xor ebx, ebx
1:  cmp rbx, [rip + questions + VEC_len]
    jae 2f
    imul r12, rbx, IQ_SIZE
    add r12, [rip + questions + VEC_ptr]
    mov rdi, [r12 + IQ_id]
    call mem_free
    mov rdi, [r12 + IQ_text]
    call mem_free
    inc rbx
    jmp 1b
2:  mov qword ptr [rip + questions + VEC_len], 0
    mov qword ptr [rip + question_index], 0
    lea rdi, [rip + answers]
    call sb_clear
    EPILOGUE

FN chat_interactions_clear
    PROLOGUE
    mov rbx, [rip + head]
1:  cmp rbx, [rip + pending + VEC_len]
    jae 2f
    mov rax, [rip + pending + VEC_ptr]
    mov rdi, [rax + rbx*8]
    call mem_free
    inc rbx
    jmp 1b
2:  mov qword ptr [rip + pending + VEC_len], 0
    mov qword ptr [rip + head], 0
    mov dword ptr [rip + kind], 0
    call clear_questions
    EPILOGUE

# Serialize string/integer RPC id. Reject malformed number tokens.
copy_id:
    PROLOGUE
    mov rbx, rdi
    lea rdi, [rip + rpc_id]
    call sb_clear
    mov rdi, rbx
    call json_type
    cmp eax, JT_STR
    je 4f
    cmp eax, JT_NUM
    jne 8f
    mov rdi, rbx
    call json_number_text
    test rdx, rdx
    jz 8f
    cmp rdx, 20
    ja 8f
    xor ecx, ecx
    cmp byte ptr [rax], '-'
    jne 1f
    inc rcx
1:  cmp rcx, rdx
    jae 8f
2:  movzx esi, byte ptr [rax + rcx]
    sub esi, '0'
    cmp esi, 9
    ja 8f
    inc rcx
    cmp rcx, rdx
    jb 2b
    mov rsi, rax
    lea rdi, [rip + rpc_id]
    call sb_push
    jmp 5f
4:  mov rdi, rbx
    call json_str
    lea rdi, [rip + rpc_id]
    mov rsi, rax
    call chat_json_quote
5:  xor eax, eax
    EPILOGUE
8:  mov eax, -1
    EPILOGUE

# summary_field(params,key,label): optional string field, no arena ownership.
summary_field:
    PROLOGUE
    mov r12, rdx
    call json_get
    mov rdi, rax
    call json_str
    test rdx, rdx
    jz 9f
    mov r13, rax
    mov r14, rdx
    lea rdi, [rip + summary]
    mov rsi, r12
    call sb_push_cstr
    lea rdi, [rip + summary]
    mov rsi, r13
    mov rdx, r14
    call sb_push
9:  EPILOGUE

show_summary:
    mov edi, 3
    mov rsi, [rip + summary + SB_ptr]
    mov rdx, [rip + summary + SB_len]
    jmp agents_chat_event
show_question:
    call chat_pending_label
    mov rdi, rax
    push rax
    call strlen
    mov rdx, rax
    pop rsi
    mov edi, 3
    jmp agents_chat_event

# Accept raw bytes, copy before the transport framing buffer is reused.
FN chat_interaction_receive
    PROLOGUE
    mov r12, rdi
    mov r13, rsi
    cmp rsi, 65536
    ja 8f
    mov rax, [rip + pending + VEC_len]
    sub rax, [rip + head]
    cmp rax, 32
    jae 8f
    mov rdi, r12
    mov rsi, r13
    call mem_dup
    mov rbx, rax
    lea rdi, [rip + pending]
    mov esi, 8
    call vec_push
    mov [rax], rbx
    cmp dword ptr [rip + kind], 0
    jne 7f
    call activate
    test eax, eax
    js 8f
7:  mov dword ptr [rip + g_dirty], 1
    xor eax, eax
    EPILOGUE
8:  mov eax, -1
    EPILOGUE

# Activate next queued request. All borrowed fields are consumed before return.
activate:
    PROLOGUE
    mov dword ptr [rip + acp_is_permission], 0
    call clear_questions
    lea rdi, [rip + summary]
    call sb_clear
    mov rax, [rip + head]
    cmp rax, [rip + pending + VEC_len]
    jae .Lempty
    mov rcx, [rip + pending + VEC_ptr]
    mov rbx, [rcx + rax*8]
    mov rdi, rbx
    call strlen
    mov rsi, rax
    mov rdi, rbx
    call json_parse_complete
    mov rbx, rax
    test rax, rax
    jz .Linvalid
    mov rdi, rbx
    lea rsi, [rip + .Lid]
    call json_get
    mov rdi, rax
    call copy_id
    test eax, eax
    js .Linvalid
    mov rdi, rbx
    lea rsi, [rip + .Lparams]
    call json_get
    mov r13, rax
    mov rdi, rbx
    lea rsi, [rip + .Lmethod]
    call json_get
    mov r12, rax
    cmp dword ptr [rip + chat_provider], 1
    je .Lacp_request
    mov rdi, rax
    lea rsi, [rip + .Lcommand_method]
    call json_is
    test eax, eax
    jnz .Lcommand
    mov rdi, r12
    lea rsi, [rip + .Lfile_method]
    call json_is
    test eax, eax
    jnz .Lfile
    mov rdi, r12
    lea rsi, [rip + .Lquestion_method]
    call json_is
    test eax, eax
    jnz .Lquestions
    jmp .Lunsupported
# ACP permission options are opaque IDs. Only offer explicit once decisions.
.Lacp_request:
    mov rdi, r12
    lea rsi, [rip + .Lacp_permission]
    call json_is
    test eax, eax
    jz .Lunsupported
    mov dword ptr [rip + acp_is_permission], 1
    mov rdi, r13
    lea rsi, [rip + .Lacp_session]
    call json_get
    mov rdi, rax
    mov rsi, [rip + chat_runtime_session]
    test rsi, rsi
    jz .Lunsupported
    call json_is
    test eax, eax
    jz .Lunsupported
    mov rdi, r13
    lea rsi, [rip + .Lacp_tool]
    call json_get
    mov rbx, rax
    lea rdi, [rip + summary]
    lea rsi, [rip + .Lacp_title]
    call sb_push_cstr
    mov rdi, rbx
    lea rsi, [rip + .Lacp_title_key]
    lea rdx, [rip + .Lnewline]
    call summary_field
    mov rdi, rbx
    lea rsi, [rip + .Lacp_input]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Lcommand_key]
    lea rdx, [rip + .Lnewline]
    call summary_field
    lea rdi, [rip + acp_allow]
    call sb_clear
    lea rdi, [rip + acp_reject]
    call sb_clear
    mov rdi, r13
    lea rsi, [rip + .Loptions]
    call json_get
    mov r12, rax
    xor r14d, r14d
.Lacp_option_loop:
    mov rdi, r12
    call json_len
    cmp r14, rax
    jae .Lacp_options_done
    cmp r14, 32
    jae .Lunsupported
    mov rdi, r12
    mov rsi, r14
    call json_at
    mov r13, rax
    mov rdi, rax
    lea rsi, [rip + .Lacp_kind]
    call json_get
    mov rbx, rax
    mov rdi, rax
    lea rsi, [rip + .Lallow_once]
    call json_is
    test eax, eax
    lea r15, [rip + acp_allow]
    jnz .Lacp_option_id
    mov rdi, rbx
    lea rsi, [rip + .Lreject_once]
    call json_is
    test eax, eax
    jz .Lacp_next_option
    lea r15, [rip + acp_reject]
.Lacp_option_id:
    cmp qword ptr [r15 + SB_len], 0
    jne .Lacp_next_option
    mov rdi, r13
    lea rsi, [rip + .Loption_id]
    call json_get
    mov rdi, rax
    call json_str
    test rdx, rdx
    jz .Lunsupported
    mov rdi, r15
    mov rsi, rax
    call chat_json_quote
.Lacp_next_option:
    inc r14
    jmp .Lacp_option_loop
.Lacp_options_done:
    cmp qword ptr [rip + acp_allow + SB_len], 0
    je .Lunsupported
    cmp qword ptr [rip + acp_reject + SB_len], 0
    je .Lunsupported
    mov dword ptr [rip + kind], 1
    call show_summary
    jmp .Lok
.Lcommand:
    lea rdi, [rip + summary]
    lea rsi, [rip + .Lcommand_title]
    call sb_push_cstr
    mov rdi, r13
    lea rsi, [rip + .Lcommand_key]
    lea rdx, [rip + .Lnewline]
    call summary_field
    mov rdi, r13
    lea rsi, [rip + .Lcwd]
    lea rdx, [rip + .Lcwd_label]
    call summary_field
    jmp .Lapproval
.Lfile:
    lea rdi, [rip + summary]
    lea rsi, [rip + .Lfile_title]
    call sb_push_cstr
    mov rdi, r13
    lea rsi, [rip + .Lgrant_root]
    lea rdx, [rip + .Lroot_label]
    call summary_field
.Lapproval:
    mov rdi, r13
    lea rsi, [rip + .Lreason]
    lea rdx, [rip + .Lnewline]
    call summary_field
    mov dword ptr [rip + kind], 1
    call show_summary
    jmp .Lok
.Lquestions:
    mov rdi, r13
    lea rsi, [rip + .Lquestions_key]
    call json_get
    mov r12, rax
    mov rdi, rax
    call json_len
    test rax, rax
    jz .Lunsupported
    cmp rax, 16
    ja .Lunsupported
    mov r15, rax
    xor r14d, r14d
.Lquestion_loop:
    mov rdi, r12
    mov rsi, r14
    call json_at
    mov r13, rax
    mov rdi, rax
    lea rsi, [rip + .Lsecret]
    call json_get
    mov rdi, rax
    call json_type
    cmp eax, JT_TRUE
    je .Lunsupported          # no masked composer yet: never display secret input
    lea rdi, [rip + questions]
    mov esi, IQ_SIZE
    call vec_push
    mov rbx, rax
    mov rdi, r13
    lea rsi, [rip + .Lid]
    call json_get
    mov rdi, rax
    call json_str
    test rdx, rdx
    jz .Linvalid
    mov rdi, rax
    mov rsi, rdx
    call mem_dup
    mov [rbx + IQ_id], rax
    lea rdi, [rip + summary]
    call sb_clear
    mov rdi, r13
    lea rsi, [rip + .Lquestion]
    lea rdx, [rip + .Lempty_label]
    call summary_field
    # Options are shown with descriptions; answer can be a label or free text.
    mov rdi, r13
    lea rsi, [rip + .Loptions]
    call json_get
    mov r13, rax
    xor ecx, ecx
    push r15
    push r14
    mov r14, r13
    xor r15d, r15d
.Loption_loop:
    mov rdi, r14
    call json_len
    cmp r15, rax
    jae .Loptions_done
    cmp r15, 32
    jae .Loptions_done
    mov rdi, r14
    mov rsi, r15
    call json_at
    mov r13, rax
    mov rdi, rax
    lea rsi, [rip + .Llabel]
    lea rdx, [rip + .Loption_label]
    call summary_field
    mov rdi, r13
    lea rsi, [rip + .Ldescription]
    lea rdx, [rip + .Ldescription_label]
    call summary_field
    inc r15
    jmp .Loption_loop
.Loptions_done:
    pop r14
    pop r15
    mov rdi, [rip + summary + SB_ptr]
    mov rsi, [rip + summary + SB_len]
    call mem_dup
    mov [rbx + IQ_text], rax
    inc r14
    cmp r14, r15
    jb .Lquestion_loop
    mov dword ptr [rip + kind], 2
    call show_question
    jmp .Lok
.Lunsupported:
    call reply_prefix
    lea rdi, [rip + reply]
    lea rsi, [rip + .Lunsupported_reply]
    cmp dword ptr [rip + acp_is_permission], 0
    je 1f
    lea rsi, [rip + .Lacp_cancelled]
1:  call sb_push_cstr
    call send_reply
    test rax, rax
    js .Linvalid
    mov edi, 3
    lea rsi, [rip + .Lunsupported_text]
    mov edx, .Lunsupported_text_end - .Lunsupported_text - 1
    call agents_chat_event
    call release_front
    call activate
    EPILOGUE
.Lempty:
    mov dword ptr [rip + kind], 0
.Lok:
    xor eax, eax
    EPILOGUE
.Linvalid:
    mov eax, -1
    EPILOGUE

reply_prefix:
    push rbx
    lea rdi, [rip + reply]
    call sb_clear
    lea rdi, [rip + reply]
    lea rsi, [rip + .Lreply_prefix]
    cmp dword ptr [rip + chat_provider], 1
    jne 1f
    lea rsi, [rip + .Lacp_reply_prefix]
1:  call sb_push_cstr
    lea rdi, [rip + reply]
    mov rsi, [rip + rpc_id + SB_ptr]
    mov rdx, [rip + rpc_id + SB_len]
    call sb_push
    pop rbx
    ret
send_reply:
    mov rdi, [rip + reply + SB_ptr]
    mov rsi, [rip + reply + SB_len]
    jmp chat_send_packet
release_front:
    PROLOGUE
    mov rax, [rip + head]
    mov rcx, [rip + pending + VEC_ptr]
    mov rdi, [rcx + rax*8]
    call mem_free
    inc qword ptr [rip + head]
    mov rax, [rip + head]
    cmp rax, [rip + pending + VEC_len]
    jne 1f
    mov qword ptr [rip + pending + VEC_len], 0
    mov qword ptr [rip + head], 0
1:  cmp qword ptr [rip + head], 32
    jb 2f
    mov rax, [rip + head]
    mov r12, [rip + pending + VEC_len]
    sub r12, rax
    mov rdi, [rip + pending + VEC_ptr]
    lea rsi, [rdi + rax*8]
    lea rdx, [r12*8]
    call memmove
    mov [rip + pending + VEC_len], r12
    mov qword ptr [rip + head], 0
2:  mov dword ptr [rip + kind], 0
    EPILOGUE

FN chat_approve
    mov edi, 1
    jmp chat_interaction_decide
FN chat_decline
    xor edi, edi
FN chat_interaction_decide
    PROLOGUE
    cmp dword ptr [rip + kind], 1
    jne 9f
    mov ebx, edi
    call reply_prefix
    cmp dword ptr [rip + chat_provider], 1
    je .Lacp_decision
    lea rsi, [rip + .Ldecline]
    test ebx, ebx
    jz 1f
    lea rsi, [rip + .Laccept]
1:  lea rdi, [rip + reply]
    call sb_push_cstr
.Ldecision_send:
    call send_reply
    test rax, rax
    js .Ldecision_failed
    call release_front
    call activate
    mov dword ptr [rip + g_dirty], 1
9:  EPILOGUE
.Lacp_decision:
    lea rdi, [rip + reply]
    lea rsi, [rip + .Lacp_selected]
    call sb_push_cstr
    lea rax, [rip + acp_reject]
    test ebx, ebx
    jz 1f
    lea rax, [rip + acp_allow]
1:  lea rdi, [rip + reply]
    mov rsi, [rax + SB_ptr]
    mov rdx, [rax + SB_len]
    call sb_push
    lea rdi, [rip + reply]
    lea rsi, [rip + .Lacp_selected_end]
    call sb_push_cstr
    jmp .Ldecision_send
.Ldecision_failed:
    call chat_shutdown
    EPILOGUE

FN chat_acp_cancel_permissions
    PROLOGUE
1:  cmp dword ptr [rip + kind], 1
    jne 9f
    call reply_prefix
    lea rdi, [rip + reply]
    lea rsi, [rip + .Lacp_cancelled]
    call sb_push_cstr
    call send_reply
    test rax, rax
    js 8f
    call release_front
    call activate
    test eax, eax
    js 8f
    jmp 1b
8:  mov eax, -1
    EPILOGUE
9:  xor eax, eax
    EPILOGUE

FN chat_interaction_answer
    PROLOGUE
    mov r12, rdi
    mov r13, rsi
    cmp dword ptr [rip + kind], 2
    jne 8f
    test rsi, rsi
    jz 8f
    cmp rsi, 16384
    ja 8f
    mov rax, [rip + question_index]
    imul rbx, rax, IQ_SIZE
    add rbx, [rip + questions + VEC_ptr]
    lea rdi, [rip + answers]
    cmp qword ptr [rip + question_index], 0
    je 1f
    mov esi, ','
    call sb_push_byte
1:  mov rdi, [rbx + IQ_id]
    call strlen
    lea rdi, [rip + answers]
    mov rsi, [rbx + IQ_id]
    mov rdx, rax
    call chat_json_quote
    lea rdi, [rip + answers]
    lea rsi, [rip + .Lanswer_prefix]
    call sb_push_cstr
    lea rdi, [rip + answers]
    mov rsi, r12
    mov rdx, r13
    call chat_json_quote
    lea rdi, [rip + answers]
    lea rsi, [rip + .Lanswer_suffix]
    call sb_push_cstr
    inc qword ptr [rip + question_index]
    mov rax, [rip + question_index]
    cmp rax, [rip + questions + VEC_len]
    jb 6f
    call reply_prefix
    lea rdi, [rip + reply]
    lea rsi, [rip + .Lanswers_prefix]
    call sb_push_cstr
    lea rdi, [rip + reply]
    mov rsi, [rip + answers + SB_ptr]
    mov rdx, [rip + answers + SB_len]
    call sb_push
    lea rdi, [rip + reply]
    lea rsi, [rip + .Lanswers_suffix]
    call sb_push_cstr
    call send_reply
    test rax, rax
    js .Lanswer_failed
    call release_front
    call activate
    jmp 7f
6:  call show_question
7:  mov dword ptr [rip + g_dirty], 1
    mov eax, 1
    EPILOGUE
8:  xor eax, eax
    EPILOGUE
.Lanswer_failed:
    call chat_shutdown
    xor eax, eax
    EPILOGUE

.section .rodata
.Lid: .asciz "id"
.Lparams: .asciz "params"
.Lmethod: .asciz "method"
.Lcommand_method: .asciz "item/commandExecution/requestApproval"
.Lfile_method: .asciz "item/fileChange/requestApproval"
.Lquestion_method: .asciz "item/tool/requestUserInput"
.Lcommand_key: .asciz "command"
.Lcwd: .asciz "cwd"
.Lreason: .asciz "reason"
.Lgrant_root: .asciz "grantRoot"
.Lquestions_key: .asciz "questions"
.Lquestion: .asciz "question"
.Lsecret: .asciz "isSecret"
.Loptions: .asciz "options"
.Llabel: .asciz "label"
.Ldescription: .asciz "description"
.Lempty_label: .asciz ""
.Lnewline: .asciz "\n"
.Lcwd_label: .asciz "\nDirectory: "
.Lroot_label: .asciz "\nRequested write root: "
.Loption_label: .asciz "\n- "
.Ldescription_label: .asciz ": "
.Lcommand_title: .asciz "Approve command?"
.Lfile_title: .asciz "Approve file changes requested by Codex?"
.Lapproval_hint: .asciz "Action pending: Approve once / Reject"
.Lreply_prefix: .asciz "{\"id\":"
.Laccept: .asciz ",\"result\":{\"decision\":\"accept\"}}\n"
.Ldecline: .asciz ",\"result\":{\"decision\":\"decline\"}}\n"
.Lanswer_prefix: .asciz ":{\"answers\":["
.Lanswer_suffix: .asciz "]}"
.Lanswers_prefix: .asciz ",\"result\":{\"answers\":{"
.Lanswers_suffix: .asciz "}}}\n"
.Lunsupported_reply: .asciz ",\"error\":{\"code\":-32601,\"message\":\"Interaction not supported by rhun\"}}\n"
.Lunsupported_text: .asciz "Unsupported provider interaction (or secret input). Request declined."
.Lunsupported_text_end:

.section .rodata
.Lacp_permission: .asciz "session/request_permission"
.Lacp_session: .asciz "sessionId"
.Lacp_tool: .asciz "toolCall"
.Lacp_title_key: .asciz "title"
.Lacp_input: .asciz "rawInput"
.Lacp_kind: .asciz "kind"
.Loption_id: .asciz "optionId"
.Lallow_once: .asciz "allow_once"
.Lreject_once: .asciz "reject_once"
.Lacp_title: .asciz "OpenCode requests permission:"
.Lacp_reply_prefix: .asciz "{\"jsonrpc\":\"2.0\",\"id\":"
.Lacp_selected: .asciz ",\"result\":{\"outcome\":{\"outcome\":\"selected\",\"optionId\":"
.Lacp_selected_end: .asciz "}}}\n"
.Lacp_cancelled: .asciz ",\"result\":{\"outcome\":{\"outcome\":\"cancelled\"}}}\n"
