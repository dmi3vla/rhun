# Explicit selection edits: capture, review, stale-buffer guard, one undo group.
.include "rhun.inc"
.bss
.p2align 3
origin: .quad 0
version: .quad 0
start: .quad 0
length: .quad 0
before: .zero SB_SIZE
replacement: .zero SB_SIZE
preview: .zero SB_SIZE
reviewed: .long 0
.text
FN chat_edit_selection
    PROLOGUE
    call chat_busy
    test eax, eax
    jnz 8f
    mov r12, [rip + g_doc]
    test r12, r12
    jz 8f
    test dword ptr [r12 + DOC_flags], DF_READONLY
    jnz 8f
    mov r13, [r12 + DOC_cur]
    mov r14, [r12 + DOC_anchor]
    cmp r13, r14
    jbe 1f
    xchg r13, r14
1:  sub r14, r13
    jz 8f
    cmp r14, 32768
    ja 8f
    mov [rip + origin], r12
    mov rax, [r12 + DOC_version]
    mov [rip + version], rax
    mov [rip + start], r13
    mov [rip + length], r14
    mov dword ptr [rip + reviewed], 0
    lea rdi, [rip + before]
    call sb_clear
    mov rdi, r12
    mov rsi, r13
    mov rdx, r14
    call doc_range
    lea rdi, [rip + before]
    mov rsi, rax
    mov rdx, r14
    call sb_push
    lea rdi, [rip + chat_runtime_answer]
    call sb_clear
    lea rdi, [rip + .Linstruction]
    call strlen
    mov rsi, rax
    lea rdi, [rip + .Linstruction]
    call agents_chat_append
    call chat_attach_selection
    EPILOGUE
8:  lea rdi, [rip + .Lselect]
    call app_toast
    EPILOGUE

FN chat_edit_preview
    PROLOGUE
    mov dword ptr [rip + reviewed], 0
    cmp qword ptr [rip + origin], 0
    je 8f
    cmp dword ptr [rip + chat_runtime_state], 3
    jne 8f
    mov r12, [rip + chat_runtime_answer + SB_ptr]
    mov r13, [rip + chat_runtime_answer + SB_len]
    test r13, r13
    jz 8f
    cmp r13, 65536
    ja 8f
    # Strip a single outer fenced code block; retain exact code bytes.
    cmp r13, 6
    jb 3f
    cmp word ptr [r12], 0x6060
    jne 3f
    cmp byte ptr [r12 + 2], 0x60
    jne 3f
    xor ebx, ebx
1:  cmp rbx, r13
    jae 8f
    cmp byte ptr [r12 + rbx], 10
    je 2f
    inc rbx
    jmp 1b
2:  inc rbx
    add r12, rbx
    sub r13, rbx
    cmp byte ptr [r12 + r13 - 1], 10
    jne 21f
    dec r13
21: cmp r13, 3
    jb 8f
    cmp word ptr [r12 + r13 - 3], 0x6060
    jne 8f
    cmp byte ptr [r12 + r13 - 1], 0x60
    jne 8f
    sub r13, 3
3:  lea rdi, [rip + replacement]
    call sb_clear
    lea rdi, [rip + replacement]
    mov rsi, r12
    mov rdx, r13
    call sb_push
    lea rdi, [rip + preview]
    call sb_clear
    lea rdi, [rip + preview]
    lea rsi, [rip + .Lbefore]
    call sb_push_cstr
    lea rdi, [rip + preview]
    mov rsi, [rip + before + SB_ptr]
    mov rdx, [rip + before + SB_len]
    call sb_push
    lea rdi, [rip + preview]
    lea rsi, [rip + .Lafter]
    call sb_push_cstr
    lea rdi, [rip + preview]
    mov rsi, [rip + replacement + SB_ptr]
    mov rdx, [rip + replacement + SB_len]
    call sb_push
    call doc_new
    mov r12, rax
    mov rdi, rax
    xor esi, esi
    mov rdx, [rip + preview + SB_ptr]
    mov rcx, [rip + preview + SB_len]
    mov r8d, EK_OTHER
    call doc_insert
    or dword ptr [r12 + DOC_flags], DF_READONLY
    lea rax, [rip + .Ltitle]
    mov [r12 + DOC_name], rax
    mov rdi, r12
    mov esi, TAB_DOC
    call app_add_tab
    mov dword ptr [rip + reviewed], 1
    EPILOGUE
8:  lea rdi, [rip + .Lno_answer]
    call app_toast
    EPILOGUE

FN chat_edit_apply
    PROLOGUE
    cmp dword ptr [rip + reviewed], 1
    jne 8f
    mov r12, [rip + origin]
    # Never dereference a closed document. Find it among currently live tabs.
    xor ebx, ebx
1:  cmp rbx, [rip + g_tabs + VEC_len]
    jae 8f
    mov rdi, rbx
    call tab_at
    cmp qword ptr [rax + TAB_kind], TAB_DOC
    jne 2f
    cmp [rax + TAB_doc], r12
    je 3f
2:  inc rbx
    jmp 1b
3:  mov rax, [rip + version]
    cmp [r12 + DOC_version], rax
    jne 8f
    test dword ptr [r12 + DOC_flags], DF_READONLY
    jnz 8f
    mov rdi, rbx
    call app_activate_tab
    mov rdi, r12
    call doc_begin_group
    mov rdi, r12
    mov rsi, [rip + start]
    mov rdx, [rip + length]
    mov ecx, EK_OTHER
    call doc_delete
    mov rdi, r12
    mov rsi, [rip + start]
    mov rdx, [rip + replacement + SB_ptr]
    mov rcx, [rip + replacement + SB_len]
    mov r8d, EK_OTHER
    call doc_insert
    mov rdi, r12
    call doc_end_group
    mov rax, [rip + start]
    mov [r12 + DOC_anchor], rax
    add rax, [rip + replacement + SB_len]
    mov [r12 + DOC_cur], rax
    mov dword ptr [rip + reviewed], 0
    mov qword ptr [rip + origin], 0
    lea rdi, [rip + .Lapplied]
    call app_toast
    EPILOGUE
8:  lea rdi, [rip + .Lstale]
    call app_toast
    EPILOGUE
FN chat_edit_document_closed
    cmp rdi, [rip + origin]
    jne 1f
    mov dword ptr [rip + reviewed], 0
    mov qword ptr [rip + origin], 0
1:  ret
FN chat_edit_discard
    mov dword ptr [rip + reviewed], 0
    mov qword ptr [rip + origin], 0
    ret
.section .rodata
.Linstruction: .asciz "Edit the selected text according to my instructions below. Return only the replacement text, optionally in one fenced code block. Do not change files directly.\nInstructions: "
.Lselect: .asciz "Select editable text (up to 32 KiB), then prepare an edit"
.Lno_answer: .asciz "Prepare a selection edit and wait for a completed answer before previewing"
.Lstale: .asciz "Preview required; source buffer must remain open and unchanged"
.Lapplied: .asciz "Applied reviewed selection edit; Undo restores the original"
.Lbefore: .asciz "--- Original selection ---\n"
.Lafter: .asciz "\n--- Proposed replacement ---\n"
.Ltitle: .asciz "Chat edit preview"
