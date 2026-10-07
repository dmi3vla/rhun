.include "rhun.inc"
.include "canvas/canvas.inc"
.text
# Owned scene contract; no borrowed parser pointers survive publication.
FN radare_analysis_valid
    PROLOGUE
    mov rdi, [rdi + SC_analysis]
    test rdi, rdi
    jz .Lav_yes
    cmp byte ptr [rdi], 0
    je .Lav_yes
    mov rbx, rdi
    call strlen
    mov rsi, rax
    mov rdi, rbx
    call json_parse_complete
    test rax, rax
    jz .Lav_no
    mov rbx, rax
    cmp dword ptr [rax], JT_OBJ
    jne .Lav_no
    cmp dword ptr [rax + 4], 4
    jne .Lav_no
    mov rdi, rbx
    lea rsi, [rip + r2_type]
    call json_get
    mov rdi, rax
    lea rsi, [rip + r2_analysis_type]
    call json_is
    test eax, eax
    jz .Lav_no
    mov rdi, rbx
    lea rsi, [rip + r2_version]
    call json_get
    mov rdi, rax
    call json_u64
    cmp rax, 1
    jne .Lav_no
    mov rdi, rbx
    lea rsi, [rip + r2_binary]
    call json_get
    mov rdi, rax
    mov esi, 4096
    call scene_owned_json_string
    test rax, rax
    jz .Lav_no
    mov rdi, rax
    call mem_free
    mov rdi, rbx
    lea rsi, [rip + r2_trace]
    call json_get
    mov rbx, rax
    mov rdi, rax
    call json_type
    cmp eax, JT_ARR
    jne .Lav_no
    mov rdi, rbx
    call json_len
    cmp eax, 8192
    ja .Lav_no
    mov r12d, eax
    xor r13d, r13d
.Lav_each:
    cmp r13d, r12d
    jae .Lav_yes
    mov rdi, rbx
    mov esi, r13d
    call json_at
    mov rdi, rax
    call radare_number
    test edx, edx
    jz .Lav_no
    inc r13d
    jmp .Lav_each
.Lav_yes: mov eax, 1
    EPILOGUE
.Lav_no: xor eax, eax
    EPILOGUE
FN radare_number
    push rbx
    call json_u64
    test rdx, rdx
    jz .Lrn_bad
    mov rcx, 9007199254740991
    cmp rax, rcx
    ja .Lrn_bad
    mov edx, 1
    pop rbx
    ret
.Lrn_bad: xor edx, edx
    pop rbx
    ret
# Upstream agfj uses addr in 6.x and offset in older exports.
FN radare_address
    PROLOGUE
    mov rbx, rdi
    lea rsi, [rip + r2_addr]
    call json_get
    test rax, rax
    jnz .Lra_num
    mov rdi, rbx
    lea rsi, [rip + r2_offset]
    call json_get
.Lra_num: mov rdi, rax
    call radare_number
    EPILOGUE
# Owned decimal source address, separate from local scene IDs.
FN radare_id_string
    PROLOGUE SB_SIZE
    mov rbx, rdi
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, rsp
    mov rsi, rbx
    call sb_push_u64
    mov rdi, [rsp + SB_ptr]
    mov rsi, [rsp + SB_len]
    call mem_dup
    mov rbx, rax
    mov rdi, rsp
    call sb_free
    mov rax, rbx
    EPILOGUE
.section .rodata
.globl r2_type, r2_version, r2_binary, r2_trace, r2_addr, r2_offset
r2_type: .asciz "type"
r2_version: .asciz "version"
r2_binary: .asciz "binary"
r2_trace: .asciz "trace"
r2_addr: .asciz "addr"
r2_offset: .asciz "offset"
r2_analysis_type: .asciz "rhun-radare2"
.globl r2_empty_analysis, r2_block_marker, r2_function_marker
r2_empty_analysis: .asciz "{\"type\":\"rhun-radare2\",\"version\":1,\"binary\":\"Imported CFG\",\"trace\":[]}"
r2_block_marker: .asciz "r2:block"
r2_function_marker: .asciz "r2:function"
