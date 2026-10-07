.include "rhun.inc"
.include "canvas/canvas.inc"
.include "radare/trace.inc"
.text
# A displayed instruction text resolves through its group; a review note through from.
FN radare_selected_block
    PROLOGUE
    mov rbx, rdi
    mov rsi, [rbx + SC_selected]
    call scene_find
    test rax, rax
    jz .Lsb_none
    mov r12, rax
    mov rdi, [rax + CE_gxid]
    test rdi, rdi
    jz .Lsb_group
    lea rsi, [rip + r2_block_marker]
    call strcmp_eq
    test eax, eax
    jnz .Lsb_yes
.Lsb_group:
    mov rsi, [r12 + CE_group]
    test rsi, rsi
    jnz .Lsb_resolve
    mov rsi, [r12 + CE_from]
.Lsb_resolve:
    mov rdi, rbx
    call scene_find
    test rax, rax
    jz .Lsb_none
    mov r12, rax
    mov rdi, [rax + CE_gxid]
    test rdi, rdi
    jz .Lsb_none
    lea rsi, [rip + r2_block_marker]
    call strcmp_eq
    test eax, eax
    jz .Lsb_none
.Lsb_yes: mov rax, r12
    EPILOGUE
.Lsb_none: xor eax, eax
    EPILOGUE
FN cmd_radare_note
    lea rdi, [rip + .Lnote_prompt]
    mov esi, 16
    jmp prompt_open
FN radare_note_add
    PROLOGUE SB_SIZE+32
    mov r12, rdi
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    call canvas_active
    mov rbx, rax
    test rax, rax
    jz .Lnote_done
    cmp qword ptr [rax + SC_before], 0
    jne .Lnote_error
    cmp qword ptr [rax + SC_elements + VEC_len], 4094
    ja .Lnote_error
    mov rdi, rax
    call radare_selected_block
    test rax, rax
    jz .Lnote_error
    mov r13, [rax + CE_id]
    mov r14, [rax + CE_xid]
    mov r15, [rax + CE_frame]
    mov [rsp + SB_SIZE], r15
    mov rdi, rsp
    lea rsi, [rip + .Lsource]
    call sb_push_cstr
    mov rdi, rsp
    mov rsi, r14
    call sb_push_cstr
    mov rdi, rsp
    mov esi, 10
    call sb_push_byte
    mov rdi, rsp
    mov rsi, r12
    call sb_push_cstr
    mov rdi, rbx
    call scene_clone
    mov r12, rax
    xor ecx, ecx
.Lnote_frame_scan:
    cmp rcx, [rbx + SC_elements + VEC_len]
    jae .Lnote_frame_new
    imul rax, rcx, CE_SIZE
    add rax, [rbx + SC_elements + VEC_ptr]
    cmp dword ptr [rax + CE_kind], CT_FRAME
    jne .Lnote_frame_next
    cmp [rax + CE_from], r15
    jne .Lnote_frame_next
    mov [rsp + SB_SIZE+8], rcx
    mov [rsp + SB_SIZE+16], rax
    mov rdi, [rax + CE_gxid]
    test rdi, rdi
    jz .Lnote_frame_restore
    lea rsi, [rip + r2_review_marker]
    call strcmp_eq
    test eax, eax
    mov rax, [rsp + SB_SIZE+16]
    mov rcx, [rsp + SB_SIZE+8]
    jnz .Lnote_frame_ready
.Lnote_frame_restore:
    mov rcx, [rsp + SB_SIZE+8]
.Lnote_frame_next: inc rcx
    jmp .Lnote_frame_scan
.Lnote_frame_new:
    mov rdi, rbx
    mov rsi, r15
    call scene_find
    mov edx, [rax + CE_x]
    add edx, [rax + CE_w]
    add edx, 40
    mov ecx, [rax + CE_y]
    mov rdi, rbx
    mov esi, CT_FRAME
    mov r8d, 520
    mov r9d, 80
    call scene_add
    mov [rax + CE_from], r15
    mov r15, rax
    lea rdi, [rip + r2_review_marker]
    mov esi, 9
    call mem_dup
    mov [r15 + CE_gxid], rax
    lea rdi, [rip + .Lreview_label]
    mov esi, 13
    call mem_dup
    mov [r15 + CE_text], rax
    mov rax, r15
.Lnote_frame_ready:
    mov r15, [rax + CE_id]
    mov edx, [rax + CE_x]
    add edx, 16
    mov ecx, [rax + CE_y]
    add ecx, [rax + CE_h]
    sub ecx, 30
    add dword ptr [rax + CE_h], 220
    mov rdi, rbx
    mov esi, CT_TEXT
    mov r8d, 480
    mov r9d, 200
    call scene_add
    mov [rax + CE_from], r13
    mov [rax + CE_frame], r15
    mov dword ptr [rax + CE_fontsize], 24
    mov r15, rax
    lea rdi, [rip + r2_note_marker]
    mov esi, 7
    call mem_dup
    mov [r15 + CE_gxid], rax
    mov rdi, r14
    call strlen
    mov rsi, rax
    mov rdi, r14
    call mem_dup
    mov [r15 + CE_xid], rax
    mov rdi, [rsp + SB_ptr]
    mov rsi, [rsp + SB_len]
    call mem_dup
    mov [r15 + CE_text], rax
    mov r15, [r15 + CE_id]
    mov rdi, rbx
    mov rsi, r12
    call scene_commit
    test eax, eax
    jz .Lnote_done
    mov rdi, rbx
    call scene_deselect
    mov rdi, rbx
    mov rsi, r15
    call scene_find
    or dword ptr [rax + CE_flags], 1
    mov [rbx + SC_selected], r15
    # Bring the review frame into view, not a source mutation.
    mov ecx, 40
    sub ecx, [rax + CE_x]
    mov [rbx + SC_pan_x], ecx
    mov ecx, 40
    sub ecx, [rax + CE_y]
    mov [rbx + SC_pan_y], ecx
    lea rdi, [rip + .Lnote_ready]
    call radare_notify
    jmp .Lnote_done
.Lnote_error: lea rdi, [rip + .Lnote_bad]
    call radare_notify
.Lnote_done: mov rdi, rsp
    call sb_free
    EPILOGUE
# Indented code blocks prevent arbitrary source/note text from becoming Markdown markup.
FN radare_md_text
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    test r12, r12
    jz .Lmd_done
    lea rsi, [rip + .Lindent]
    call sb_push_cstr
.Lmd_byte:
    movzx esi, byte ptr [r12]
    test esi, esi
    jz .Lmd_newline
    mov rdi, rbx
    call sb_push_byte
    cmp byte ptr [r12], 10
    jne .Lmd_next
    mov rdi, rbx
    lea rsi, [rip + .Lindent]
    call sb_push_cstr
.Lmd_next: inc r12
    jmp .Lmd_byte
.Lmd_newline: mov rdi, rbx
    lea rsi, [rip + .Lnewline]
    call sb_push_cstr
.Lmd_done: EPILOGUE
FN cmd_radare_review_export
    lea rdi, [rip + .Lreview_prompt]
    mov esi, 17
    jmp prompt_open
FN radare_review_write
    PROLOGUE SB_SIZE
    mov r12, rdi
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    call canvas_active
    mov rbx, rax
    test rax, rax
    jz .Lrw_done
    mov rdi, rax
    call radare_trace_prepare
    test rax, rax
    jz .Lrw_error
    mov r13, rax
    mov rdi, rsp
    lea rsi, [rip + .Lreview_header]
    call sb_push_cstr
    mov rdi, [rbx + SC_analysis]
    call strlen
    mov rsi, rax
    mov rdi, [rbx + SC_analysis]
    call json_parse_complete
    mov rdi, rax
    lea rsi, [rip + r2_binary]
    call json_get
    mov rdi, rax
    call json_str
    mov rdi, rsp
    mov rsi, rax
    call radare_md_text
    mov rdi, rsp
    lea rsi, [rip + .Levidence]
    call sb_push_cstr
    mov rdi, rsp
    mov rsi, [r13 + RV_events + VEC_len]
    call sb_push_u64
    mov rdi, rsp
    lea rsi, [rip + .Lunmapped]
    call sb_push_cstr
    mov rdi, rsp
    mov rsi, [r13 + RV_unmapped]
    call sb_push_u64
    mov rdi, rsp
    lea rsi, [rip + .Lnewline]
    call sb_push_cstr
    xor r14d, r14d
.Lrw_element:
    cmp r14, [rbx + SC_elements + VEC_len]
    jae .Lrw_write
    imul r15, r14, CE_SIZE
    add r15, [rbx + SC_elements + VEC_ptr]
    cmp dword ptr [r15 + CE_kind], CT_TEXT
    jne .Lrw_element_next
    mov rdi, rsp
    lea rsi, [rip + .Lsection]
    call sb_push_cstr
    mov rdi, rsp
    mov rsi, [r15 + CE_text]
    call radare_md_text
    cmp qword ptr [rsp + SB_len], 8 << 20
    ja .Lrw_error
.Lrw_element_next: inc r14
    jmp .Lrw_element
.Lrw_write:
    mov rdi, r12
    mov rsi, [rsp + SB_ptr]
    mov rdx, [rsp + SB_len]
    call file_write_all
    test rax, rax
    js .Lrw_error
    lea rdi, [rip + .Lreview_ready]
    call radare_notify
    jmp .Lrw_done
.Lrw_error: lea rdi, [rip + .Lreview_bad]
    call radare_notify
.Lrw_done: mov rdi, rsp
    call sb_free
    EPILOGUE
# Selected-context requests get evidence counts, not an unbounded whole trace.
FN radare_request_evidence
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    call radare_trace_prepare
    test rax, rax
    jz .Lreq_done
    mov r13, rax
    mov rdi, r12
    lea rsi, [rip + .Lrequest_evidence]
    call sb_push_cstr
    mov rdi, r12
    mov rsi, [r13 + RV_events + VEC_len]
    call sb_push_u64
    mov rdi, r12
    lea rsi, [rip + .Lrequest_unmapped]
    call sb_push_cstr
    mov rdi, r12
    mov rsi, [r13 + RV_unmapped]
    call sb_push_u64
    mov rdi, r12
    mov esi, '}'
    call sb_push_byte
.Lreq_done: EPILOGUE
.section .rodata
.globl r2_note_marker, r2_review_marker
r2_note_marker: .asciz "r2:note"
r2_review_marker: .asciz "r2:review"
.Lreview_label: .asciz "Source review"
.Lsource: .asciz "Source address: "
.Lnote_prompt: .asciz "Radare2: review note for selected source block"
.Lreview_prompt: .asciz "Radare2: export review Markdown path"
.Lnote_ready: .asciz "Radare2: source-linked review note added (one undo)"
.Lnote_bad: .asciz "Radare2: select a source block before adding a review note"
.Lreview_ready: .asciz "Radare2: review exported; static CFG and imported trace distinguished"
.Lreview_bad: .asciz "Radare2: review export failed or exceeded limits"
.Lindent: .asciz "    "
.Lnewline: .asciz "\n\n"
.Lsection: .asciz "## Displayed assembly / source-linked note\n\n"
.Lreview_header: .asciz "# Radare2 source review\n\nStatic CFG, not a recorded execution. Assembly display is capped at 32 instructions per block; full block JSON stays in the native document. Notes are manual review, not automatic findings.\n\nSource binary:\n\n"
.Levidence: .asciz "Imported address events (not recorded by rhun): "
.Lunmapped: .asciz "; unmapped or ambiguous: "
.Lrequest_evidence: .asciz ",\"evidence\":{\"kind\":\"imported-address-sequence\",\"events\":"
.Lrequest_unmapped: .asciz ",\"unmapped\":"
