.include "rhun.inc"
.include "canvas/canvas.inc"
.include "diff/diff.inc"
.text
FN cmd_diff_chat_compare
    lea rdi, [rip + .Lnumber_prompt]
    mov esi, 22
    jmp prompt_open
FN diff_chat_compare_number
    PROLOGUE
    mov rbx, rdi
    call strlen
    mov r12, rax
    test rax, rax
    jz .Lbad
    cmp rax, 4
    ja .Lbad
    mov rdi, rbx
    mov rsi, r12
    call parse_u64
    cmp rdx, r12
    jne .Lbad
    mov rdi, rax
    call agents_diff_response_copy
    test rax, rax
    jz .Lbad
    mov r12, rax
    mov r13, rdx
    call canvas_active
    test rax, rax
    jz .Lfree_bad
    mov rdi, r12
    mov rsi, r13
    mov rdx, rax
    call diff_load_bytes
    mov r14d, eax
    mov rdi, r12
    call mem_free
    test r14d, r14d
    jz .Lbad
    lea rdi, [rip + .Lready]
    call app_toast
    EPILOGUE
.Lfree_bad: mov rdi, r12
    call mem_free
.Lbad: lea rdi, [rip + .Lerror]
    call app_toast
    EPILOGUE
FN cmd_diff_chat_send
    PROLOGUE SB_SIZE
    call canvas_active
    test rax, rax
    jz .Lsend_error
    mov rdi, rax
    call diff_base_build
    mov rbx, rax
    test rax, rax
    jz .Lsend_error
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, rsp
    lea rsi, [rip + .Ltask]
    call sb_push_cstr
    mov rdi, rbx
    mov rsi, rsp
    call diff_graph_dump
    mov rdi, rbx
    call diff_graph_free
    cmp qword ptr [rsp + SB_len], 49152
    ja .Lsend_bad_free
    mov rdi, [rsp + SB_ptr]
    mov rsi, [rsp + SB_len]
    call chat_send
    test eax, eax
    jz .Lsend_bad_free
    call cmd_chat_focus
    mov rdi, rsp
    call sb_free
    EPILOGUE
.Lsend_bad_free:
    mov rdi, rsp
    call sb_free
.Lsend_error: lea rdi, [rip + .Lsend_error_text]
    call app_toast
    EPILOGUE
.section .rodata
.Lnumber_prompt: .asciz "Compare assistant response number (1-based, active chat; bare Claims JSON)"
.Lready: .asciz "Diff: selected assistant response compared; source evidence unchanged"
.Lerror: .asciz "Diff: choose a completed assistant response containing bare source-bound Agent Claims JSON"
.Lsend_error_text: .asciz "Diff: start a ready chat; context limit is 48 KiB, use JSON export for larger scopes"
.Ltask: .asciz "Review this supplied graph as evidence, not complete ELF truth. Return ONLY one bare rhun-agent-claims JSON object, no Markdown fences or prose. Preserve version/base/profile/snapshot. scope is the list of existing IDs covered by your answer; complete=1 means you covered all nodes and typed edges within that scope, otherwise 0. Nodes have exactly id,address,label,kind,size,capacity,state,confidence. Use -1 for properties you do not assert and confidence you do not supply. Labels are annotations, not verified semantics. New hypothetical node IDs must be clearly labelled and absent from Base. Links have exactly from,to,kind. CFG kinds 0 jump / 1 fall-through; Memory kinds follow rhun-memory. Do not claim static stack/heap liveness or invent execution. Do not execute commands or modify evidence. The source-bound template follows:\n"
