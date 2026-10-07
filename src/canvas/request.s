.include "rhun.inc"
.include "canvas/canvas.inc"
.text
# Only selected elements, up to 64 / 48 KiB. Never auto-sends a project.
FN canvas_request_build
    PROLOGUE SB_SIZE
    mov rbx, rdi
    mov r12, rsi
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, rbx
    mov rsi, rsp
    call scene_serialize
    mov rdi, [rsp + SB_ptr]
    mov rsi, [rsp + SB_len]
    call json_parse_complete
    test rax, rax
    jz 8f
    mov rdi, rax
    lea rsi, [rip + .Lelements]
    call json_get
    mov r13, rax
    mov rdi, r12
    lea rsi, [rip + .Lheader]
    call sb_push_cstr
    mov rdi, r12
    mov rsi, [rbx + SC_revision]
    call sb_push_u64
    mov rdi, r12
    lea rsi, [rip + .Lselected]
    call sb_push_cstr
    xor r14d, r14d
    xor r15d, r15d
1:  cmp r14, [rbx + SC_elements + VEC_len]
    jae 3f
    imul rax, r14, CE_SIZE
    add rax, [rbx + SC_elements + VEC_ptr]
    test dword ptr [rax + CE_flags], 1
    jz 2f
    cmp r15d, 64
    jae 8f
    test r15d, r15d
    jz 11f
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
    imul rax, r14, CE_SIZE
    add rax, [rbx + SC_elements + VEC_ptr]
11: mov rdi, r12
    mov rsi, [rax + CE_id]
    call sb_push_u64
    inc r15d
2:  inc r14
    jmp 1b
3:  test r15d, r15d
    jz 8f
    mov rdi, r12
    lea rsi, [rip + .Lcontext]
    call sb_push_cstr
    xor r14d, r14d
    xor r15d, r15d
4:  cmp r14, [rbx + SC_elements + VEC_len]
    jae 7f
    imul rax, r14, CE_SIZE
    add rax, [rbx + SC_elements + VEC_ptr]
    test dword ptr [rax + CE_flags], 1
    jz 6f
    test r15d, r15d
    jz 5f
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
5:  mov rdi, r13
    mov esi, r14d
    call json_at
    mov rdi, r12
    mov rsi, rax
    call json_dump
    inc r15d
6:  inc r14
    jmp 4b
7:  mov rdi, r12
    lea rsi, [rip + .Lend]
    call sb_push_cstr
    cmp qword ptr [r12 + SB_len], 48 << 10
    ja 8f
    mov r15d, 1
    jmp 9f
8:  xor r15d, r15d
9:  mov rdi, rsp
    call sb_free
    mov eax, r15d
    EPILOGUE
FN cmd_canvas_request_export
    lea rdi, [rip + .Lprompt]
    mov esi, 10
    jmp prompt_open
FN canvas_request_write
    PROLOGUE SB_SIZE
    mov r12, rdi
    call canvas_active
    test rax, rax
    jz 9f
    mov rbx, rax
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, rbx
    mov rsi, rsp
    call canvas_request_build
    test eax, eax
    jz 8f
    mov rdi, r12
    mov rsi, [rsp + SB_ptr]
    mov rdx, [rsp + SB_len]
    call file_write_all
    test rax, rax
    js 8f
    lea rdi, [rip + .Lready]
    call app_toast
    jmp 7f
8:  lea rdi, [rip + .Lerror]
    call app_toast
7:  mov rdi, rsp
    call sb_free
9:  EPILOGUE
FN cmd_canvas_request_chat
    PROLOGUE SB_SIZE
    call canvas_active
    test rax, rax
    jz 9f
    mov rbx, rax
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, rbx
    mov rsi, rsp
    call canvas_request_build
    test eax, eax
    jz 8f
    mov rdi, [rsp + SB_ptr]
    mov rsi, [rsp + SB_len]
    call chat_send
    test eax, eax
    jz 8f
    call cmd_chat_focus
    jmp 7f
8:  lea rdi, [rip + .Lchat_error]
    call app_toast
7:  mov rdi, rsp
    call sb_free
9:  EPILOGUE
.section .rodata
.Lelements: .asciz "elements"
.Lheader: .asciz "{\"type\":\"rhun-canvas-request\",\"version\":1,\"revision\":"
.Lselected: .asciz ",\"selected\":["
.Lcontext: .asciz "],\"elements\":["
.Lend: .asciz "],\"allowed\":[\"add\",\"replace\",\"delete\",\"ui\"],\"task\":\"Detail selected nodes or map a frame to rhun-ui. Return rhun-proposal v1 with the same revision, explanation, and operations. add/replace use complete native element records, delete uses id, ui uses value. Preserve external references. New IDs must exceed existing IDs. No executable code.\"}"
.Lprompt: .asciz "Export selected canvas request JSON path"
.Lready: .asciz "Selected context request exported; load agent result with Canvas: Load Model Proposal"
.Lerror: .asciz "Request rejected: select 1-64 elements with total context under 48 KiB"
.Lchat_error: .asciz "Start a chat and wait until ready, then send selected canvas context again"
