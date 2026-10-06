# Typed clipboard and internal tree drops share the owned attachment ingestion.
.include "rhun.inc"
.bss
.p2align 3
uri_path: .zero SB_SIZE
.text
# chat_paste_uris(bytes, len): LF/CRLF uri-list, at most 64 local files.
FN chat_paste_uris
    PROLOGUE
    mov r12, rdi
    mov r13, rsi
    cmp rsi, 65536
    ja .Luri_bad
    call chat_text_valid
    test eax, eax
    jnz .Luri_bad
    xor r14d, r14d
    xor ebx, ebx
.Luri_next:
    cmp r14, r13
    jae .Luri_done
    mov r15, r14
1:  cmp r15, r13
    jae 2f
    cmp byte ptr [r12 + r15], 10
    je 2f
    inc r15
    jmp 1b
2:  mov rax, r15
    cmp rax, r14
    je .Luri_skip
    cmp byte ptr [r12 + rax - 1], 13
    jne 3f
    dec rax
3:  cmp rax, r14
    je .Luri_skip
    cmp byte ptr [r12 + r14], '#'
    je .Luri_skip
    sub rax, r14
    cmp rax, 8
    jb .Luri_bad
    lea rdi, [r12 + r14]
    mov rsi, rax
    lea rdx, [rip + .Llocal_uri]
    mov ecx, 7
    call str_starts
    test eax, eax
    jz .Luri_bad
    add r14, 7
    cmp byte ptr [r12 + r14], '/'
    je 4f
    lea rdi, [r12 + r14]
    mov rsi, r15
    sub rsi, r14
    lea rdx, [rip + .Llocalhost]
    mov ecx, 10
    call str_starts
    test eax, eax
    jz .Luri_bad
    add r14, 9
4:  lea rdi, [rip + uri_path]
    call sb_clear
.Luri_decode:
    cmp r14, r15
    jae .Luri_attach
    movzx esi, byte ptr [r12 + r14]
    cmp esi, 13
    je .Luri_attach
    inc r14
    cmp esi, '%'
    jne 6f
    lea rax, [r14 + 1]
    cmp rax, r15
    jae .Luri_bad
    movzx edi, byte ptr [r12 + r14]
    call uri_hex
    test eax, eax
    js .Luri_bad
    shl eax, 4
    push rax
    movzx edi, byte ptr [r12 + r14 + 1]
    call uri_hex
    pop rsi
    test eax, eax
    js .Luri_bad
    or esi, eax
    add r14, 2
6:  test esi, esi
    jz .Luri_bad
    lea rdi, [rip + uri_path]
    call sb_push_byte
    cmp qword ptr [rip + uri_path + SB_len], 4095
    ja .Luri_bad
    jmp .Luri_decode
.Luri_attach:
    inc ebx
    cmp ebx, 64
    ja .Luri_bad
    mov rdi, [rip + uri_path + SB_ptr]
    call chat_attach_path
.Luri_skip:
    lea r14, [r15 + 1]
    jmp .Luri_next
.Luri_bad:
    lea rdi, [rip + .Luri_error]
    call app_toast
.Luri_done:
    EPILOGUE
uri_hex:
    lea eax, [rdi - '0']
    cmp eax, 9
    jbe 1f
    or edi, 32
    lea eax, [rdi - 'a']
    cmp eax, 5
    ja 2f
    add eax, 10
1:  ret
2:  mov eax, -1
    ret
.section .rodata
.Llocal_uri: .asciz "file://"
.Llocalhost: .asciz "localhost/"
.Luri_error: .asciz "Clipboard: expected local file URLs (max 64 files / 64 KiB)."
