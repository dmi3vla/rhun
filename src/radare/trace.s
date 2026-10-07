.include "rhun.inc"
.include "canvas/canvas.inc"
.include "radare/trace.inc"
.text
FN radare_trace_free
    PROLOGUE
    mov rbx, rdi
    test rbx, rbx
    jz .Ltf_done
    lea rdi, [rbx + RV_events]
    call vec_free
    lea rdi, [rbx + RV_blocks]
    call vec_free
    mov rdi, rbx
    call mem_free
.Ltf_done: EPILOGUE
# Rebuild only on a content revision; all addresses copied before parsing block metadata.
FN radare_trace_prepare
    PROLOGUE 32
    mov rbx, rdi
    mov r12, [rbx + SC_trace_view]
    test r12, r12
    jz .Ltp_new
    mov rax, [rbx + SC_revision]
    cmp [r12 + RV_revision], rax
    jne .Ltp_new
    mov rax, r12
    EPILOGUE
.Ltp_new:
    mov rdi, r12
    call radare_trace_free
    mov qword ptr [rbx + SC_trace_view], 0
    mov rdi, [rbx + SC_analysis]
    test rdi, rdi
    jz .Ltp_none
    cmp byte ptr [rdi], 0
    je .Ltp_none
    call strlen
    mov rsi, rax
    mov rdi, [rbx + SC_analysis]
    call json_parse_complete
    test rax, rax
    jz .Ltp_none
    mov rdi, rax
    lea rsi, [rip + r2_trace]
    call json_get
    mov r13, rax
    mov edi, RV_SIZE
    call mem_alloc
    mov r12, rax
    xor r14d, r14d
.Ltp_event:
    mov rdi, r13
    mov esi, r14d
    call json_at
    test rax, rax
    jz .Ltp_blocks_start
    mov rdi, rax
    call radare_number
    test edx, edx
    jz .Ltp_bad
    mov r15, rax
    lea rdi, [r12 + RV_events]
    mov esi, RT_SIZE
    call vec_push
    mov [rax + RT_address], r15
    mov qword ptr [rax + RT_block], 0
    inc r14d
    jmp .Ltp_event
.Ltp_blocks_start: xor r13d, r13d
.Ltp_block:
    cmp r13, [rbx + SC_elements + VEC_len]
    jae .Ltp_resolve_start
    imul r14, r13, CE_SIZE
    add r14, [rbx + SC_elements + VEC_ptr]
    mov rdi, [r14 + CE_gxid]
    test rdi, rdi
    jz .Ltp_block_next
    lea rsi, [rip + r2_block_marker]
    call strcmp_eq
    test eax, eax
    jz .Ltp_block_next
    mov rdi, [r14 + CE_raw]
    test rdi, rdi
    jz .Ltp_block_next
    call strlen
    mov rsi, rax
    mov rdi, [r14 + CE_raw]
    call json_parse_complete
    mov rdi, rax
    lea rsi, [rip + .Lr2]
    call json_get
    mov r15, rax
    mov rdi, rax
    call radare_address
    test edx, edx
    jz .Ltp_bad
    mov [rsp], rax
    mov rdi, r15
    lea rsi, [rip + .Lsize]
    call json_get
    mov rdi, rax
    call radare_number
    test edx, edx
    jz .Ltp_bad
    mov [rsp + 8], rax
    lea rdi, [r12 + RV_blocks]
    mov esi, RC_SIZE
    call vec_push
    mov rcx, [r14 + CE_id]
    mov [rax + RC_id], rcx
    mov rcx, [rsp]
    mov [rax + RC_address], rcx
    mov rcx, [rsp + 8]
    mov [rax + RC_size], rcx
    mov qword ptr [rax + RC_count], 0
.Ltp_block_next: inc r13
    jmp .Ltp_block
.Ltp_resolve_start: xor r13d, r13d
.Ltp_resolve:
    cmp r13, [r12 + RV_events + VEC_len]
    jae .Ltp_ready
    imul r14, r13, RT_SIZE
    add r14, [r12 + RV_events + VEC_ptr]
    xor r15d, r15d
    mov qword ptr [rsp + 16], 0
.Ltp_interval:
    cmp r15, [r12 + RV_blocks + VEC_len]
    jae .Ltp_match_done
    imul rcx, r15, RC_SIZE
    add rcx, [r12 + RV_blocks + VEC_ptr]
    mov rax, [r14 + RT_address]
    sub rax, [rcx + RC_address]
    cmp rax, [rcx + RC_size]
    jae .Ltp_interval_next
    cmp qword ptr [rsp + 16], 0
    jne .Ltp_unmapped
    mov [rsp + 16], rcx
.Ltp_interval_next: inc r15
    jmp .Ltp_interval
.Ltp_match_done:
    mov rcx, [rsp + 16]
    test rcx, rcx
    jz .Ltp_unmapped
    mov rax, [rcx + RC_id]
    mov [r14 + RT_block], rax
    inc qword ptr [rcx + RC_count]
    jmp .Ltp_resolve_next
.Ltp_unmapped: inc qword ptr [r12 + RV_unmapped]
.Ltp_resolve_next: inc r13
    jmp .Ltp_resolve
.Ltp_ready:
    mov rax, [rbx + SC_revision]
    mov [r12 + RV_revision], rax
    mov [rbx + SC_trace_view], r12
    mov rax, r12
    EPILOGUE
.Ltp_bad: mov rdi, r12
    call radare_trace_free
.Ltp_none: xor eax, eax
    EPILOGUE
FN cmd_radare_trace_import
    lea rdi, [rip + .Ltrace_prompt]
    mov esi, 15
    jmp prompt_open
FN radare_trace_import_file
    PROLOGUE SB_SIZE+16
    mov r12, rdi
    mov qword ptr [rsp + SB_SIZE], 0
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    call canvas_active
    mov rbx, rax
    test rax, rax
    jz .Lti_done
    mov rdi, [rax + SC_analysis]
    test rdi, rdi
    jz .Lti_error
    call strlen
    mov rsi, rax
    mov rdi, [rbx + SC_analysis]
    call json_parse_complete
    mov rdi, rax
    lea rsi, [rip + r2_binary]
    call json_get
    mov rdi, rax
    mov esi, 4096
    call scene_owned_json_string
    test rax, rax
    jz .Lti_error
    mov r13, rax
    mov rdi, r12
    mov ecx, 1 << 20
    call file_read_limited
    test rax, rax
    jz .Lti_free_binary
    mov r12, rax
    mov [rsp + SB_SIZE], rax
    mov rdi, rax
    mov rsi, rdx
    call json_parse_complete
    mov r14, rax
    test r14, r14
    jz .Lti_free_binary
    cmp dword ptr [r14], JT_OBJ
    jne .Lti_free_binary
    cmp dword ptr [r14 + 4], 4
    jne .Lti_free_binary
    mov rdi, r14
    lea rsi, [rip + r2_type]
    call json_get
    mov rdi, rax
    lea rsi, [rip + .Ltrace_type]
    call json_is
    test eax, eax
    jz .Lti_free_binary
    mov rdi, r14
    lea rsi, [rip + r2_version]
    call json_get
    mov rdi, rax
    call json_u64
    cmp rax, 1
    jne .Lti_free_binary
    mov rdi, r14
    lea rsi, [rip + r2_binary]
    call json_get
    mov rdi, rax
    mov rsi, r13
    call json_is
    test eax, eax
    jz .Lti_free_binary
    mov rdi, r14
    lea rsi, [rip + .Laddresses]
    call json_get
    mov r14, rax
    mov rdi, rax
    call json_type
    cmp eax, JT_ARR
    jne .Lti_free_binary
    mov rdi, r14
    call json_len
    cmp eax, 8192
    ja .Lti_free_binary
    xor r15d, r15d
.Lti_validate:
    mov rdi, r14
    mov esi, r15d
    call json_at
    test rax, rax
    jz .Lti_build
    mov rdi, rax
    call radare_number
    test edx, edx
    jz .Lti_free_binary
    inc r15d
    jmp .Lti_validate
.Lti_build:
    mov rdi, rsp
    lea rsi, [rip + .Lanalysis_start]
    call sb_push_cstr
    mov rdi, r13
    call strlen
    mov rdx, rax
    mov rdi, rsp
    mov rsi, r13
    call chat_json_quote
    mov rdi, rsp
    lea rsi, [rip + .Lanalysis_trace]
    call sb_push_cstr
    mov rdi, rsp
    mov rsi, r14
    call json_dump
    mov rdi, rsp
    mov esi, '}'
    call sb_push_byte
    mov rdi, r13
    call mem_free
    mov rdi, rbx
    call scene_clone
    mov r12, rax
    mov rdi, [rbx + SC_analysis]
    call mem_free
    mov rdi, [rsp + SB_ptr]
    mov rsi, [rsp + SB_len]
    call mem_dup
    mov [rbx + SC_analysis], rax
    mov dword ptr [rbx + SC_trace_cursor], 0
    mov rdi, rbx
    mov rsi, r12
    call scene_commit
    test eax, eax
    jz .Lti_error
    lea rdi, [rip + .Lloaded]
    call radare_notify
    jmp .Lti_done
.Lti_free_binary: mov rdi, r13
    call mem_free
.Lti_error: lea rdi, [rip + .Lbad_trace]
    call radare_notify
.Lti_done: mov rdi, [rsp + SB_SIZE]
    call mem_free
    mov rdi, rsp
    call sb_free
    EPILOGUE
FN cmd_radare_trace_next
    mov edi, 1
    jmp radare_trace_step
FN cmd_radare_trace_prev
    mov edi, -1
radare_trace_step:
    PROLOGUE
    mov r15d, edi
    call canvas_active
    mov rbx, rax
    test rax, rax
    jz .Lts_done
    mov rdi, rax
    call radare_trace_prepare
    test rax, rax
    jz .Lts_done
    mov rcx, [rax + RV_events + VEC_len]
    test rcx, rcx
    jz .Lts_done
    mov edx, [rbx + SC_trace_cursor]
    add edx, r15d
    test edx, edx
    jns .Lts_high
    xor edx, edx
.Lts_high: cmp rdx, rcx
    jb .Lts_set
    lea edx, [rcx - 1]
.Lts_set: mov [rbx + SC_trace_cursor], edx
    shl rdx, 4
    add rdx, [rax + RV_events + VEC_ptr]
    mov rsi, [rdx + RT_block]
    test rsi, rsi
    jz .Lts_unmapped
    mov rdi, rbx
    call scene_find
    test rax, rax
    jz .Lts_unmapped
    mov r12, rax
    mov rdi, rbx
    call scene_deselect
    or dword ptr [r12 + CE_flags], 1
    mov rax, [r12 + CE_id]
    mov [rbx + SC_selected], rax
    mov eax, 40
    sub eax, [r12 + CE_x]
    mov [rbx + SC_pan_x], eax
    mov eax, 40
    sub eax, [r12 + CE_y]
    mov [rbx + SC_pan_y], eax
    jmp .Lts_dirty
.Lts_unmapped:
    mov rdi, rbx
    call scene_deselect
    lea rdi, [rip + .Lunmapped]
    call radare_notify
.Lts_dirty: mov dword ptr [rip + g_dirty], 1
.Lts_done: EPILOGUE
FN radare_trace_dump
    PROLOGUE
    mov r12, rsi
    mov rbx, rdi
    call radare_trace_prepare
    test rax, rax
    jz .Ltd_none
    mov r13, rax
    mov rdi, r12
    lea rsi, [rip + .Ldump_head]
    call sb_push_cstr
    mov rdi, r12
    mov rsi, [r13 + RV_events + VEC_len]
    call sb_push_u64
    mov rdi, r12
    lea rsi, [rip + .Ldump_unmapped]
    call sb_push_cstr
    mov rdi, r12
    mov rsi, [r13 + RV_unmapped]
    call sb_push_u64
    mov rdi, r12
    lea rsi, [rip + .Ldump_cursor]
    call sb_push_cstr
    mov rdi, r12
    mov esi, [rbx + SC_trace_cursor]
    call sb_push_u64
    mov rdi, r12
    lea rsi, [rip + .Ldump_blocks]
    call sb_push_cstr
    xor r14d, r14d
.Ltd_each:
    cmp r14, [r13 + RV_blocks + VEC_len]
    jae .Ltd_end
    imul r15, r14, RC_SIZE
    add r15, [r13 + RV_blocks + VEC_ptr]
    test r14, r14
    jz .Ltd_record
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
.Ltd_record:
    mov rdi, r12
    lea rsi, [rip + .Ldump_id]
    call sb_push_cstr
    mov rdi, r12
    mov rsi, [r15 + RC_id]
    call sb_push_u64
    mov rdi, r12
    lea rsi, [rip + .Ldump_count]
    call sb_push_cstr
    mov rdi, r12
    mov rsi, [r15 + RC_count]
    call sb_push_u64
    mov rdi, r12
    mov esi, '}'
    call sb_push_byte
    inc r14
    jmp .Ltd_each
.Ltd_end:
    mov rdi, r12
    lea rsi, [rip + .Ldump_end]
    call sb_push_cstr
.Ltd_none: EPILOGUE
.section .rodata
.Lr2: .asciz "r2"
.Lsize: .asciz "size"
.Ltrace_prompt: .asciz "Radare2: import address trace JSON"
.Ltrace_type: .asciz "rhun-r2-trace"
.Laddresses: .asciz "addresses"
.Lanalysis_start: .asciz "{\"type\":\"rhun-radare2\",\"version\":1,\"binary\":"
.Lanalysis_trace: .asciz ",\"trace\":"
.Lloaded: .asciz "Radare2: imported address sequence loaded (not recorded by rhun)"
.Lbad_trace: .asciz "Radare2: invalid trace or binary mismatch; previous evidence kept"
.Lunmapped: .asciz "Radare2: current trace address is unmapped or ambiguous"
.Ldump_head: .asciz "{\"type\":\"rhun-r2-trace-view\",\"events\":"
.Ldump_unmapped: .asciz ",\"unmapped\":"
.Ldump_cursor: .asciz ",\"cursor\":"
.Ldump_blocks: .asciz ",\"blocks\":["
.Ldump_id: .asciz "{\"id\":"
.Ldump_count: .asciz ",\"visits\":"
.Ldump_end: .asciz "]}\n"
