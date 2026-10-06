# Explicit context attachments. Text lives in the draft; image markers survive tabs.
.include "rhun.inc"
.bss
.p2align 3
block: .zero SB_SIZE
image_path: .zero SB_SIZE
image_bytes: .quad 0
image_length: .quad 0
image_mime: .quad 0
.text
FN chat_attach_file
    lea rdi, [rip + attach_picked_file]
    lea rsi, [rip + .Lchoose_file]
    jmp palette_choose_file

attach_picked_file:
    PROLOGUE
    mov rsi, rdi
    mov rdi, [rip + g_project]
    call path_join
    mov r12, rax
    mov rdi, r12
    call chat_attach_path
    mov rdi, r12
    call mem_free
    EPILOGUE

# chat_attach_path(absolute path): shared picker/drop/clipboard ingestion.
FN chat_attach_path
    PROLOGUE
    mov r12, rdi
    call strlen
    cmp rax, 4095
    ja .Lpath_invalid
    test rax, rax
    jz .Lpath_invalid
    cmp byte ptr [r12], '/'
    jne .Lpath_invalid
    mov rsi, rax
    mov rdi, r12
    call chat_text_valid
    test eax, eax
    jnz .Lpath_invalid
    mov rdi, r12
    call strlen
    mov rsi, rax
    mov rdi, r12
    call mem_dup
    mov r12, rax
    mov rdi, rax
    call file_type
    cmp eax, 0x4000
    je .Lattach_reference
    cmp eax, 0x8000
    jne .Lpath_missing
    mov rdi, r12
    mov ecx, 1 << 20
    call file_read_limited
    test rax, rax
    jz 8f
    mov r13, rax
    mov r14, rdx
    cmp rdx, 8
    jb 1f
    mov rcx, 0x0a1a0a0d474e5089
    cmp [rax], rcx
    je .Lattach_image
    cmp byte ptr [rax], 0xff
    jne 1f
    cmp byte ptr [rax + 1], 0xd8
    je .Lattach_image
1:  mov rdi, rax
    mov rsi, rdx
    call doc_is_binary
    test eax, eax
    jnz .Lattach_reference_bytes
    cmp r14, 32768
    ja 7f
    mov rdi, r13
    mov rsi, r14
    call chat_text_valid
    test eax, eax
    jnz .Lbad_attachment_text
    mov rdi, r12
    mov rsi, r13
    mov rdx, r14
    call append_file_block
    jmp 6f
.Lattach_image:
    lea rdi, [rip + block]
    call sb_clear
    lea rdi, [rip + block]
    lea rsi, [rip + .Limage_prefix]
    call sb_push_cstr
    mov rdi, r12
    call strlen
    mov rdx, rax
    mov rsi, r12
    lea rdi, [rip + block]
    call chat_json_quote
    lea rdi, [rip + block]
    mov esi, 10
    call sb_push_byte
    call append_block
6:  mov rdi, r13
    call mem_free
    mov rdi, r12
    call mem_free
    EPILOGUE
.Lbad_attachment_text:
    lea rdi, [rip + .Linvalid_text]
    call app_toast
    jmp 6b
7:  jmp .Lattach_reference_bytes
.Lattach_reference_bytes:
    mov rdi, r13
    call mem_free
.Lattach_reference:
    lea rdi, [rip + block]
    call sb_clear
    lea rdi, [rip + block]
    lea rsi, [rip + .Lfile_reference]
    call sb_push_cstr
    mov rdi, r12
    call strlen
    mov rdx, rax
    mov rsi, r12
    lea rdi, [rip + block]
    call chat_json_quote
    lea rdi, [rip + block]
    mov esi, 10
    call sb_push_byte
    call append_block
    mov rdi, r12
    call mem_free
    EPILOGUE
8:  cmp rdx, -27
    je .Lattach_reference
    lea rdi, [rip + .Lread_error]
    call app_toast
    mov rdi, r12
    call mem_free
    EPILOGUE

.Lpath_missing:
    lea rdi, [rip + .Lread_error]
    call app_toast
    mov rdi, r12
    call mem_free
    EPILOGUE
.Lpath_invalid:
    lea rdi, [rip + .Lread_error]
    call app_toast
    EPILOGUE

FN chat_attach_active_file
    PROLOGUE
    mov r12, [rip + g_doc]
    test r12, r12
    jz 8f
    mov rdi, r12
    call doc_len
    cmp rax, 32768
    ja 7f
    mov r13, rax
    mov rdi, r12
    call doc_contiguous
    mov rsi, rax
    mov rdx, r13
    mov rdi, [r12 + DOC_path]
    test rdi, rdi
    jnz 1f
    lea rdi, [rip + .Luntitled]
1:  call append_file_block
    EPILOGUE
7:  lea rdi, [rip + .Llarge_text]
    call app_toast
    EPILOGUE
8:  lea rdi, [rip + .Lno_document]
    call app_toast
    EPILOGUE

FN chat_attach_selection
    PROLOGUE
    mov r12, [rip + g_doc]
    test r12, r12
    jz 8f
    mov r13, [r12 + DOC_cur]
    mov r14, [r12 + DOC_anchor]
    cmp r13, r14
    jbe 1f
    xchg r13, r14
1:  sub r14, r13
    test r14, r14
    jz 8f
    cmp r14, 32768
    ja 8f
    mov rdi, r12
    mov rsi, r13
    mov rdx, r14
    call doc_range
    lea rdi, [rip + .Lselection]
    mov rsi, rax
    mov rdx, r14
    call append_file_block
    EPILOGUE
8:  lea rdi, [rip + .Lno_selection]
    call app_toast
    EPILOGUE

# name, bytes, len: materialize the exact buffer contents into a bounded draft.
append_file_block:
    PROLOGUE
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    lea rdi, [rip + block]
    call sb_clear
    lea rdi, [rip + block]
    lea rsi, [rip + .Lcontext_prefix]
    call sb_push_cstr
    lea rdi, [rip + block]
    mov rsi, r12
    call sb_push_cstr
    lea rdi, [rip + block]
    lea rsi, [rip + .Lfence]
    call sb_push_cstr
    lea rdi, [rip + block]
    mov rsi, r13
    mov rdx, r14
    call sb_push
    lea rdi, [rip + block]
    lea rsi, [rip + .Lfence_end]
    call sb_push_cstr
    call append_block
    EPILOGUE
append_block:
    mov rdi, [rip + block + SB_ptr]
    mov rsi, [rip + block + SB_len]
    jmp agents_chat_append

# Parse one optional @image: JSON-string line before constructing a native turn.
# The JSON arena is not in use by a turn sender. Keep owned file bytes/path only.
FN chat_context_prepare
    PROLOGUE
    mov r12, rdi
    mov r13, rsi
    call chat_text_valid
    test eax, eax
    jnz 8f
    mov rdi, [rip + image_bytes]
    call mem_free
    mov qword ptr [rip + image_bytes], 0
    mov qword ptr [rip + image_length], 0
    lea rdi, [rip + image_path]
    call sb_clear
    xor r14d, r14d
1:  cmp r14, r13
    jae 9f
    mov r15, r14
2:  cmp r15, r13
    jae 3f
    cmp byte ptr [r12 + r15], 10
    je 3f
    inc r15
    jmp 2b
3:  mov rsi, r15
    sub rsi, r14
    cmp rsi, 8
    jb 7f
    lea rdi, [r12 + r14]
    lea rdx, [rip + .Limage_prefix]
    mov ecx, 8
    call str_starts
    test eax, eax
    jz 7f
    cmp qword ptr [rip + image_path + SB_len], 0
    jne 8f
    lea rdi, [r12 + r14 + 8]
    mov rsi, r15
    sub rsi, r14
    sub rsi, 8
    call json_parse_complete
    mov rdi, rax
    call json_str
    test rdx, rdx
    jz 8f
    cmp rdx, 4095
    ja 8f
    mov rsi, rdx
    mov rdi, rax
    call chat_text_valid
    test eax, eax
    jnz 8f
    # Re-read the parsed string: validation does not reset the JSON arena.
    lea rdi, [r12 + r14 + 8]
    mov rsi, r15
    sub rsi, r14
    sub rsi, 8
    call json_parse_complete
    mov rdi, rax
    call json_str
    lea rdi, [rip + image_path]
    mov rsi, rax
    call sb_push
    mov rdi, [rip + image_path + SB_ptr]
    mov ecx, 1 << 20
    call file_read_limited
    test rax, rax
    jz 8f
    mov [rip + image_bytes], rax
    mov [rip + image_length], rdx
    cmp rdx, 8
    jb 8f
    mov rcx, 0x0a1a0a0d474e5089
    cmp [rax], rcx
    lea rcx, [rip + .Lpng]
    je 4f
    cmp byte ptr [rax], 0xff
    jne 8f
    cmp byte ptr [rax + 1], 0xd8
    jne 8f
    lea rcx, [rip + .Ljpeg]
4:  mov [rip + image_mime], rcx
    cmp dword ptr [rip + chat_provider], 3
    je 8f
    cmp dword ptr [rip + chat_provider], 0
    je 7f
    cmp dword ptr [rip + chat_acp_image_supported], 0
    je 8f
7:  lea r14, [r15 + 1]
    jmp 1b
8:  lea rdi, [rip + .Limage_error]
    call app_toast
    mov eax, -1
    EPILOGUE
9:  xor eax, eax
    EPILOGUE

FN chat_context_images
    PROLOGUE
    cmp qword ptr [rip + image_path + SB_len], 0
    je 9f
    cmp dword ptr [rip + chat_provider], 0
    jne 1f
    lea rdi, [rip + .Llocal_image]
    call chat_runtime_append
    mov rdi, [rip + image_path + SB_ptr]
    call chat_runtime_quote
    lea rdi, [rip + .Lclose_image]
    call chat_runtime_append
    jmp 9f
1:  lea rdi, [rip + .Lacp_image]
    call chat_runtime_append
    lea rdi, [rip + chat_runtime_request]
    mov rsi, [rip + image_bytes]
    mov rdx, [rip + image_length]
    call chat_base64
    lea rdi, [rip + .Lmime_prefix]
    call chat_runtime_append
    mov rdi, [rip + image_mime]
    call chat_runtime_quote
    lea rdi, [rip + .Lclose_image]
    call chat_runtime_append
9:  EPILOGUE

# Base64 into a string builder; no shell, subprocess, or credential handling.
FN chat_base64
    PROLOGUE
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    xor ebx, ebx
1:  cmp rbx, r14
    jae 9f
    movzx r15d, byte ptr [r13 + rbx]
    shl r15d, 16
    lea rax, [rbx + 1]
    cmp rax, r14
    jae 2f
    movzx eax, byte ptr [r13 + rbx + 1]
    shl eax, 8
    or r15d, eax
2:  lea rax, [rbx + 2]
    cmp rax, r14
    jae 3f
    movzx eax, byte ptr [r13 + rbx + 2]
    or r15d, eax
3:  lea rcx, [rip + .Lbase64]
    mov eax, r15d
    shr eax, 18
    movzx esi, byte ptr [rcx + rax]
    mov rdi, r12
    call sb_push_byte
    lea rcx, [rip + .Lbase64]
    mov eax, r15d
    shr eax, 12
    and eax, 63
    movzx esi, byte ptr [rcx + rax]
    mov rdi, r12
    call sb_push_byte
    mov esi, '='
    lea rax, [rbx + 1]
    cmp rax, r14
    jae 4f
    lea rcx, [rip + .Lbase64]
    mov eax, r15d
    shr eax, 6
    and eax, 63
    movzx esi, byte ptr [rcx + rax]
4:  mov rdi, r12
    call sb_push_byte
    mov esi, '='
    lea rax, [rbx + 2]
    cmp rax, r14
    jae 5f
    lea rcx, [rip + .Lbase64]
    mov eax, r15d
    and eax, 63
    movzx esi, byte ptr [rcx + rax]
5:  mov rdi, r12
    call sb_push_byte
    add rbx, 3
    jmp 1b
9:  EPILOGUE
.section .rodata
.Lchoose_file: .asciz "Attach project file"
.Lcontext_prefix: .asciz "\nContext: "
.Lfence: .asciz "\n```\n"
.Lfence_end: .asciz "\n```\n"
.Limage_prefix: .asciz "@image: "
.Llocal_image: .asciz ",{\"type\":\"localImage\",\"path\":"
.Lacp_image: .asciz ",{\"type\":\"image\",\"data\":\""
.Lmime_prefix: .asciz "\",\"mimeType\":"
.Lclose_image: .asciz "}"
.Lpng: .asciz "image/png"
.Ljpeg: .asciz "image/jpeg"
.Lbase64: .asciz "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
.Llarge_text: .asciz "Text attachments are limited to 32 KiB"
.Lread_error: .asciz "Could not read the selected file (limit: 1 MiB)"
.Limage_error: .asciz "Attach one PNG/JPEG up to 1 MiB; the agent must advertise image support"
.Lno_document: .asciz "Open a text document to attach its current buffer"
.Lno_selection: .asciz "Select up to 32 KiB of text to attach"
.Lselection: .asciz "Editor selection"
.Luntitled: .asciz "Unsaved document"

.text
FN chat_prompt_template
    PROLOGUE
    lea rdi, [rip + insert_prompt_file]
    lea rsi, [rip + .Lchoose_prompt]
    call palette_choose_file
    call palette_field
    mov rdi, rax
    lea rsi, [rip + .Lprompt_query]
    mov edx, .Lprompt_query_end - .Lprompt_query - 1
    call tf_set
    call palette_changed
    EPILOGUE

FN chat_project_skill
    PROLOGUE
    lea rdi, [rip + attach_picked_file]
    lea rsi, [rip + .Lchoose_skill]
    call palette_choose_file
    call palette_field
    mov rdi, rax
    lea rsi, [rip + .Lskill_query]
    mov edx, 8
    call tf_set
    call palette_changed
    EPILOGUE

insert_prompt_file:
    PROLOGUE
    mov rsi, rdi
    mov rdi, [rip + g_project]
    call path_join
    mov r12, rax
    mov rdi, rax
    mov ecx, 32768
    call file_read_limited
    test rax, rax
    jz 8f
    mov r13, rax
    mov r14, rdx
    mov rdi, rax
    mov rsi, rdx
    call doc_is_binary
    test eax, eax
    jnz 7f
    mov rdi, r13
    mov rsi, r14
    call agents_chat_append
7:  mov rdi, r13
    call mem_free
8:  mov rdi, r12
    call mem_free
    EPILOGUE
.section .rodata
.Lchoose_prompt: .asciz "Insert project prompt template"
.Lprompt_query: .asciz ".rhun/prompts/"
.Lprompt_query_end:
.Lchoose_skill: .asciz "Attach project SKILL.md"
.Lskill_query: .asciz "SKILL.md"

.section .rodata
.Linvalid_text: .asciz "Attachment must contain valid UTF-8 text without NUL bytes"

.section .rodata
.Lfile_reference: .asciz "@file: "
