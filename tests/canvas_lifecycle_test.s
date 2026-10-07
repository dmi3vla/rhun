.include "rhun.inc"
.include "canvas/canvas.inc"
.text
FN main
    PROLOGUE
    xor r15d, r15d
.Lcycle:
    lea rdi, [rip + .Lsource]
    mov esi, .Lsource_end - .Lsource
    call scene_parse
    test rax, rax
    jz .Lfail
    mov rbx, rax
    lea rdi, [rip + .Lproposal]
    mov esi, .Lproposal_end - .Lproposal
    mov rdx, rbx
    call canvas_proposal_parse
    test rax, rax
    jz .Lfail
    mov rdi, rax
    call canvas_proposal_free
    mov rdi, rbx
    call scene_clone
    mov rsi, rax
    mov rdi, rbx
    call scene_commit
    test eax, eax
    jz .Lfail
    mov rdi, rbx
    call scene_undo
    mov rdi, rbx
    call scene_redo
    mov rdi, rbx
    call scene_free
    lea rdi, [rip + .Lgraph]
    mov esi, .Lgraph_end - .Lgraph
    call canvas_graph_import
    test rax, rax
    jz .Lfail
    mov rbx, rax
    mov rdi, rbx
    call scene_clone
    mov r13, rax
    lea rdi, [rip + .Lreset]
    mov esi, 2
    call mem_dup
    mov [rbx + SC_ui], rax
    mov rdi, rbx
    mov rsi, r13
    call scene_commit
    test eax, eax
    jnz .Lfail
    cmp qword ptr [rbx + SC_graph_view], 0
    je .Lfail
    mov rdi, [rbx + SC_graph_view]
    call canvas_graph_projection
    mov rdi, rbx
    call scene_free
    lea rdi, [rip + .Lreset]
    mov esi, 2
    call json_parse_complete
    cmp r15d, 0
    jne 1f
    mov r14, [rip + g_mem_live]
1:  inc r15d
    cmp r15d, 101
    jb .Lcycle
    cmp r14, [rip + g_mem_live]
    jne .Lleak
    lea rdi, [rip + .Lok]
    call log_cstr
    xor eax, eax
    EPILOGUE
.Lleak:
    mov rdi, [rip + g_mem_live]
    sub rdi, r14
    call log_u64
.Lfail:
    lea rdi, [rip + .Lerror]
    call log_cstr
    mov eax, 1
    EPILOGUE
.section .rodata
.Lreset: .asciz "{}"
.Lok: .asciz "canvas lifecycle: 100 cycles, zero live owned-byte growth\n"
.Lerror: .asciz "canvas lifecycle failed\n"
.Lsource: .incbin "examples/canvas/proposal-source.rhun-canvas"
.Lsource_end:
.Lproposal: .incbin "examples/canvas/detail-proposal.json"
.Lproposal_end:
.Lgraph: .incbin "examples/canvas/distributed-state.rhun-graph"
.Lgraph_end:
