# Native tool summaries and proposed diffs, copied before the JSON arena resets.
.include "rhun.inc"
.bss
.p2align 3
notice: .zero SB_SIZE
.text
# append a named string field to the notice, limited to 16 KiB per field.
field:
    PROLOGUE
    call json_get
    mov rdi, rax
    call json_str
    test rdx, rdx
    jz 9f
    cmp rdx, 16384
    jbe 1f
    mov edx, 16384
2:  movzx ecx, byte ptr [rax + rdx]
    and ecx, 0xc0
    cmp ecx, 0x80
    jne 1f
    dec rdx
    jmp 2b
1:  lea rdi, [rip + notice]
    mov rsi, rax
    call sb_push
    lea rdi, [rip + notice]
    mov esi, 10
    call sb_push_byte
9:  EPILOGUE

FN chat_render_codex_tool
    PROLOGUE
    mov r12, rdi
    lea rsi, [rip + .Ltype]
    call json_get
    mov rbx, rax
    mov rdi, rax
    lea rsi, [rip + .Lcommand_type]
    call json_is
    test eax, eax
    jnz 1f
    mov rdi, rbx
    lea rsi, [rip + .Lfile_type]
    call json_is
    test eax, eax
    jz 9f
1:  lea rdi, [rip + notice]
    call sb_clear
    mov rdi, r12
    lea rsi, [rip + .Ltype]
    call field
    mov rdi, r12
    lea rsi, [rip + .Lstatus]
    call field
    mov rdi, r12
    lea rsi, [rip + .Lcommand]
    call field
    mov rdi, r12
    lea rsi, [rip + .Loutput]
    call field
    mov rdi, r12
    lea rsi, [rip + .Lchanges]
    call json_get
    mov r12, rax
    xor r13d, r13d
2:  mov rdi, r12
    call json_len
    cmp r13, rax
    jae 3f
    cmp r13, 8
    jae 3f
    mov rdi, r12
    mov rsi, r13
    call json_at
    mov r14, rax
    mov rdi, rax
    lea rsi, [rip + .Lpath]
    call field
    mov rdi, r14
    lea rsi, [rip + .Ldiff]
    call field
    inc r13
    jmp 2b
3:  call show
9:  EPILOGUE

FN chat_render_acp_tool
    PROLOGUE
    mov r12, rdi
    lea rdi, [rip + notice]
    call sb_clear
    mov rdi, r12
    lea rsi, [rip + .Ltitle]
    call field
    mov rdi, r12
    lea rsi, [rip + .Lstatus]
    call field
    mov rdi, r12
    lea rsi, [rip + .Linput]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Lcommand]
    call field
    mov rdi, r12
    lea rsi, [rip + .Lcontent]
    call json_get
    mov r12, rax
    xor r13d, r13d
1:  mov rdi, r12
    call json_len
    cmp r13, rax
    jae 3f
    cmp r13, 8
    jae 3f
    mov rdi, r12
    mov rsi, r13
    call json_at
    mov r14, rax
    mov rdi, rax
    lea rsi, [rip + .Lpath]
    call field
    mov rdi, r14
    lea rsi, [rip + .Lold]
    call field
    mov rdi, r14
    lea rsi, [rip + .Lnew]
    call field
    mov rdi, r14
    lea rsi, [rip + .Lcontent]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Ltext]
    call field
    inc r13
    jmp 1b
3:  call show
    EPILOGUE

show:
    cmp qword ptr [rip + notice + SB_len], 0
    je 1f
    mov edi, 3
    mov rsi, [rip + notice + SB_ptr]
    mov rdx, [rip + notice + SB_len]
    jmp agents_chat_event
1:  ret
.section .rodata
.Ltype: .asciz "type"
.Lcommand_type: .asciz "commandExecution"
.Lfile_type: .asciz "fileChange"
.Lstatus: .asciz "status"
.Lcommand: .asciz "command"
.Loutput: .asciz "aggregatedOutput"
.Lchanges: .asciz "changes"
.Lpath: .asciz "path"
.Ldiff: .asciz "diff"
.Ltitle: .asciz "title"
.Linput: .asciz "rawInput"
.Lcontent: .asciz "content"
.Lold: .asciz "oldText"
.Lnew: .asciz "newText"
.Ltext: .asciz "text"
