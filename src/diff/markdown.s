.include "rhun.inc"
.include "canvas/canvas.inc"
.include "diff/diff.inc"
.text
# Untrusted IDs/text are emitted as indented code, never Markdown directives.
FN diff_markdown_dump
    PROLOGUE SB_SIZE
    mov rbx, rdi
    mov r12, rsi
    mov r13, [rbx + SC_diff]
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, r12
    lea rsi, [rip + .Lheader]
    call sb_push_cstr
    mov rdi, rbx
    mov rsi, r13
    call diff_stale
    test eax, eax
    jz 1f
    mov rdi, r12
    lea rsi, [rip + .Lstale]
    call sb_push_cstr
1:  mov rax, [r13 + DF_base]
    mov rdi, r12
    mov rsi, [rax + DG_base]
    call radare_md_text
    xor r14d, r14d
2:  cmp r14, [r13 + DF_results + VEC_len]
    jae 9f
    imul r15, r14, DR_SIZE
    add r15, [r13 + DF_results + VEC_ptr]
    mov rdi, r12
    lea rsi, [rip + .Lsection]
    call sb_push_cstr
    mov eax, [r15 + DR_status]
    lea rcx, [rip + diff_status_names]
    mov rdi, r12
    mov rsi, [rcx + rax*8]
    call radare_md_text
    mov eax, [r15 + DR_reason]
    lea rcx, [rip + diff_reason_names]
    mov rdi, r12
    mov rsi, [rcx + rax*8]
    call radare_md_text
    mov rdi, rsp
    call sb_clear
    mov rdi, rsp
    lea rsi, [rip + .Lbase]
    call sb_push_cstr
    mov rdi, rsp
    mov rsi, [r13 + DF_base]
    mov edx, [r15 + DR_base]
    mov ecx, [r15 + DR_type]
    call diff_item_text
    mov rdi, rsp
    lea rsi, [rip + .Lai]
    call sb_push_cstr
    mov rdi, rsp
    mov rsi, [r13 + DF_target]
    mov edx, [r15 + DR_target]
    mov ecx, [r15 + DR_type]
    call diff_item_text
    mov rdi, r12
    mov rsi, [rsp + SB_ptr]
    call radare_md_text
    inc r14
    jmp 2b
9:  mov rdi, rsp
    call sb_free
    EPILOGUE
.section .rodata
.Lheader: .asciz "# Native Visual Diff\n\nBase is supplied evidence, not complete ELF truth. Structural matches do not verify prose semantics. Confidence is model metadata, not proof. Numeric properties below: kind, size, capacity, state; -1 means not asserted. Binding is FNV-1a over native scene content, not an ELF authenticity hash.\n\nSource binding:\n\n"
.Lstale: .asciz "**STALE: source revision or snapshot changed.**\n\n"
.Lsection: .asciz "\n## Comparison item\n\n"
.Lbase: .asciz "Base: "
.Lai: .asciz "\nAI: "
