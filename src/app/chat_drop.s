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
.bss
.p2align 3
clip_image_path: .zero SB_SIZE
clip_image_seq: .quad 0
.text
# app_on_clipboard(ptr, len, kind): 0=text, 1=URI list, 2=PNG, 3=JPEG.
# Never route binary bytes to text widgets or a provider's question field.
FN app_on_clipboard
    test edx, edx
    jz app_on_paste
    PROLOGUE
    mov r12, rdi
    mov r13, rsi
    mov ebx, edx
    call agents_chat_accept_objects
    test eax, eax
    jz .Lclip_unavailable
    cmp ebx, 1
    jne .Lclip_image
    mov rdi, r12
    mov rsi, r13
    call chat_paste_uris
    jmp .Lclip_done
.Lclip_image:
    cmp r13, 1 << 20
    ja .Lclip_bad
    cmp r13, 8
    jb .Lclip_bad
    cmp ebx, 2
    jne 1f
    mov rax, 0x0a1a0a0d474e5089
    cmp [r12], rax
    jne .Lclip_bad
    jmp 2f
1:  cmp ebx, 3
    jne .Lclip_bad
    cmp word ptr [r12], 0xd8ff
    jne .Lclip_bad
2:  lea rdi, [rip + clip_image_path]
    call sb_clear
    call config_dir
    mov rsi, rax
    lea rdi, [rip + clip_image_path]
    call sb_push_cstr
    lea rdi, [rip + clip_image_path]
    lea rsi, [rip + .Lclip_directory]
    call sb_push_cstr
    SYS SYS_getpid
    mov rsi, rax
    lea rdi, [rip + clip_image_path]
    call sb_push_u64
    lea rdi, [rip + clip_image_path]
    mov esi, '-'
    call sb_push_byte
    call time_ms
    mov rsi, rax
    lea rdi, [rip + clip_image_path]
    call sb_push_u64
    lea rdi, [rip + clip_image_path]
    mov esi, '-'
    call sb_push_byte
    inc qword ptr [rip + clip_image_seq]
    mov rsi, [rip + clip_image_seq]
    lea rdi, [rip + clip_image_path]
    call sb_push_u64
    lea rdi, [rip + clip_image_path]
    lea rsi, [rip + .Lclip_png]
    cmp ebx, 2
    je 3f
    lea rsi, [rip + .Lclip_jpeg]
3:  call sb_push_cstr
    mov rdi, [rip + clip_image_path + SB_ptr]
    call mkdir_parent
    mov rdi, [rip + clip_image_path + SB_ptr]
    mov rsi, r12
    mov rdx, r13
    call file_write_private
    test rax, rax
    js .Lclip_bad
    mov rdi, [rip + clip_image_path + SB_ptr]
    call chat_attach_path
    jmp .Lclip_done
.Lclip_unavailable:
    lea rdi, [rip + .Lclip_target]
    call app_toast
    jmp .Lclip_done
.Lclip_bad:
    lea rdi, [rip + .Lclip_limit]
    call app_toast
.Lclip_done:
    mov dword ptr [rip + g_dirty], 1
    EPILOGUE
.section .rodata
.Lclip_directory: .asciz "/chat-attachments/clipboard-"
.Lclip_png: .asciz ".png"
.Lclip_jpeg: .asciz ".jpg"
.Lclip_target: .asciz "Paste files/images into the chat message, outside question dialogs."
.Lclip_limit: .asciz "Clipboard image unreadable or too large (PNG/JPEG, max 1 MiB)."

.text
# A slow desktop transfer must not attach to a different chat after tab switching.
FN app_on_clipboard_delivery
    test rcx, rcx
    jz app_on_clipboard
    PROLOGUE
    mov r12, rdi
    mov r13, rsi
    mov r14d, edx
    mov r15, rcx
    call agents_chat_clipboard_token
    cmp rax, r15
    jne 1f
    mov rdi, r12
    mov rsi, r13
    mov edx, r14d
    call app_on_clipboard
    EPILOGUE
1:  lea rdi, [rip + .Lclip_changed]
    call app_toast
    EPILOGUE
.section .rodata
.Lclip_changed: .asciz "Clipboard target changed; paste again in the intended chat."
