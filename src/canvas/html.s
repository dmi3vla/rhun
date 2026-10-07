.include "rhun.inc"
.include "canvas/canvas.inc"
.text
FN cmd_canvas_export_html
    lea rdi, [rip + .Lhtml_prompt]
    mov esi, 8
    jmp prompt_open

# Deterministic HTML from UI IR, never executes HTML/JS in rhun.
FN canvas_export_html
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    mov rdi, rbx
    call canvas_ui_model
    mov r13, rax
    test rax, rax
    jz .Lhtml_bad
    mov rax, [r13 + UM_revision]
    cmp rax, [rbx + SC_revision]
    jne .Lhtml_free_bad
    mov rdi, r13
    mov rsi, [rbx + SC_selected]
    call canvas_ui_source
    test rax, rax
    jnz 1f
    mov rdi, r13
    mov rsi, [r13 + UM_root]
    call canvas_ui_find
1:  mov r14, rax
    mov rdi, r12
    lea rsi, [rip + .Lhtml_header]
    call sb_push_cstr
    mov rdi, r12
    mov rsi, [r13 + UM_revision]
    call sb_push_u64
    mov rdi, r12
    lea rsi, [rip + .Lhtml_style]
    call sb_push_cstr
    mov rdi, r12
    mov rsi, r13
    mov rdx, r14
    call canvas_html_node
    mov rdi, r12
    lea rsi, [rip + .Lhtml_end]
    call sb_push_cstr
    mov rdi, r13
    call canvas_ui_free
    mov eax, 1
    EPILOGUE
.Lhtml_free_bad:
    mov rdi, r13
    call canvas_ui_free
.Lhtml_bad:
    xor eax, eax
    EPILOGUE

canvas_html_node:
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov eax, [r13 + UC_type]
    lea rcx, [rip + .Ltags]
    mov r14, [rcx + rax*8]
    mov esi, '<'
    call sb_push_byte
    mov rdi, rbx
    mov rsi, r14
    call sb_push_cstr
    mov rdi, rbx
    lea rsi, [rip + .Lid_open]
    call sb_push_cstr
    mov rdi, rbx
    mov rsi, [r13 + UC_id]
    call sb_push_u64
    mov rdi, rbx
    lea rsi, [rip + .Lsource_open]
    call sb_push_cstr
    mov rdi, rbx
    mov rsi, [r13 + UC_source]
    call sb_push_u64
    mov rdi, rbx
    lea rsi, [rip + .Lclass_open]
    call sb_push_cstr
    mov eax, [r13 + UC_type]
    lea rcx, [rip + .Lclasses]
    mov rdi, rbx
    mov rsi, [rcx + rax*8]
    call sb_push_cstr
    mov rdi, rbx
    lea rsi, [rip + .Laction_open]
    call sb_push_cstr
    mov rdi, [r13 + UC_action]
    call strlen
    mov rdx, rax
    mov rdi, rbx
    mov rsi, [r13 + UC_action]
    call canvas_xml_escape
    mov rdi, rbx
    lea rsi, [rip + .Lstyle_open]
    call sb_push_cstr
    lea r15, [rip + .Lstyles]
1:  cmp qword ptr [r15], 0
    je 2f
    mov rcx, [r15 + 8]
    cmp dword ptr [r13 + rcx], 0
    je 11f
    mov rdi, rbx
    mov rsi, [r15]
    call sb_push_cstr
    mov rcx, [r15 + 8]
    mov esi, [r13 + rcx]
    mov rdi, rbx
    call sb_push_u64
    mov rdi, rbx
    lea rsi, [rip + .Lpx]
    call sb_push_cstr
11: add r15, 16
    jmp 1b
2:  mov rdi, rbx
    lea rsi, [rip + .Lstyle_end]
    call sb_push_cstr
    cmp dword ptr [r13 + UC_type], U_INPUT
    jne 3f
    mov rdi, rbx
    lea rsi, [rip + .Linput_value]
    call sb_push_cstr
    mov rdi, [r13 + UC_text]
    call strlen
    mov rdx, rax
    mov rdi, rbx
    mov rsi, [r13 + UC_text]
    call canvas_xml_escape
    mov rdi, rbx
    lea rsi, [rip + .Linput_end]
    call sb_push_cstr
    jmp 9f
3:  mov rdi, rbx
    mov esi, '>'
    call sb_push_byte
    mov rdi, [r13 + UC_text]
    call strlen
    mov rdx, rax
    mov rdi, rbx
    mov rsi, [r13 + UC_text]
    call canvas_xml_escape
    mov rdi, rbx
    mov esi, 10
    call sb_push_byte
    xor r15d, r15d
4:  cmp r15, [r12 + UM_nodes + VEC_len]
    jae 8f
    imul rdx, r15, UC_SIZE
    add rdx, [r12 + UM_nodes + VEC_ptr]
    mov rax, [r13 + UC_id]
    cmp rax, [rdx + UC_parent]
    jne 5f
    mov rdi, rbx
    mov rsi, r12
    call canvas_html_node
5:  inc r15
    jmp 4b
8:  mov rdi, rbx
    lea rsi, [rip + .Lclose]
    call sb_push_cstr
    mov rdi, rbx
    mov rsi, r14
    call sb_push_cstr
    mov rdi, rbx
    lea rsi, [rip + .Ltag_end]
    call sb_push_cstr
9:  EPILOGUE

FN canvas_write_html
    PROLOGUE SB_SIZE
    mov r12, rdi
    call canvas_active
    mov rbx, rax
    test rax, rax
    jz 9f
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, rbx
    mov rsi, rsp
    call canvas_export_html
    test eax, eax
    jz 8f
    mov rdi, r12
    mov ecx, 8 << 20
    call file_read_limited
    test rax, rax
    jnz 101f
    mov rdi, r12
    call file_type
    test eax, eax
    jnz 8f
    jmp 2f
101:
    mov r13, rax
    cmp rdx, [rsp + SB_len]
    jne 1f
    mov rdi, rax
    mov rsi, [rsp + SB_ptr]
    call strcmp_eq
    test eax, eax
    jnz 11f
1:  mov rdi, r12
    lea rsi, [rip + .Lsafe_suffix]
    call canvas_path_suffix
    mov r12, rax
    lea rdi, [rip + .Lmanual]
    call app_toast
    # Never overwrite even the alternate path if it already exists.
    mov rdi, r12
    call file_type
    test eax, eax
    jnz 12f
    mov rdi, r13
    call mem_free
    mov r13, r12
    jmp 3f
11: mov rdi, r13
    call mem_free
    jmp 2f
12: mov rdi, r13
    call mem_free
    mov rdi, r12
    call mem_free
    jmp 7f
2:  mov rdi, r12
    call strlen
    mov rsi, rax
    mov rdi, r12
    call mem_dup
    mov r13, rax
3:  mov rdi, r13
    mov rsi, [rsp + SB_ptr]
    mov rdx, [rsp + SB_len]
    call file_write_all
    test rax, rax
    js 6f
    mov rdi, [rbx + SC_generated]
    call mem_free
    mov [rbx + SC_generated], r13
    mov rdi, r13
    call app_open_path
    jmp 7f
6:  mov rdi, r13
    call mem_free
8:  lea rdi, [rip + .Lexport_failed]
    call app_toast
7:  mov rdi, rsp
    call sb_free
9:  EPILOGUE
.section .rodata
.Lhtml_prompt: .asciz "Export UI subtree to HTML path"
.Lexport_failed: .asciz "HTML rejected: UI missing/stale; refresh source revision or import valid UI"
.Lmanual: .asciz "Existing HTML differs; keeping it and writing .rhun-generated.html separately"
.Lsafe_suffix: .asciz ".rhun-generated.html"
.Lhtml_header: .asciz "<!doctype html>\n<html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><meta name=\"rhun-ui-revision\" content=\""
.Lhtml_style: .asciz "\"><title>Rhun UI draft</title><style>\n*{box-sizing:border-box}body{background:#181b20;color:#d8dee9;font:16px sans-serif;margin:24px}.rhun-row{display:flex;flex-direction:row;overflow:hidden}.rhun-column,.rhun-card,.rhun-list{display:flex;flex-direction:column;overflow:hidden}.rhun-card{border:1px solid #8da4ff;border-radius:8px}.rhun-text{white-space:pre-wrap;overflow-wrap:anywhere}.rhun-button,.rhun-input{background:#252a33;color:inherit;border:1px solid #8da4ff;border-radius:4px;font:inherit}.rhun-button:hover{background:#35405b}\n</style></head><body>\n"
.Lhtml_end: .asciz "</body></html>\n"
.Ldiv: .asciz "div"
.Lp: .asciz "p"
.Lbutton: .asciz "button"
.Linput: .asciz "input"
.Lrow_class: .asciz "row"
.Lcolumn_class: .asciz "column"
.Lcard_class: .asciz "card"
.Llist_class: .asciz "list"
.Ltext_class: .asciz "text"
.Lbutton_class: .asciz "button"
.Linput_class: .asciz "input"
.Lid_open: .asciz " id=\"rhun-component-"
.Lsource_open: .asciz "\" data-scene-id=\""
.Lclass_open: .asciz "\" class=\"rhun-"
.Laction_open: .asciz "\" data-action=\""
.Lstyle_open: .asciz "\" style=\""
.Lstyle_end: .asciz "\""
.Linput_value: .asciz " value=\""
.Linput_end: .asciz "\">\n"
.Lclose: .asciz "</"
.Ltag_end: .asciz ">\n"
.Lwidth: .asciz "width:"
.Lheight: .asciz "height:"
.Lpadding: .asciz "padding:"
.Lgap: .asciz "gap:"
.Lpx: .asciz "px;"
.p2align 3
.Ltags: .quad .Ldiv,.Ldiv,.Ldiv,.Ldiv,.Lp,.Lbutton,.Linput
.Lclasses: .quad .Lrow_class,.Lcolumn_class,.Lcard_class,.Llist_class,.Ltext_class,.Lbutton_class,.Linput_class
.Lstyles: .quad .Lwidth, UC_width, .Lheight, UC_height, .Lpadding, UC_padding, .Lgap, UC_gap, 0

.text
FN canvas_path_suffix
    PROLOGUE SB_SIZE
    mov rbx, rdi
    mov r12, rsi
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, rsp
    mov rsi, rbx
    call sb_push_cstr
    mov rdi, rsp
    mov rsi, r12
    call sb_push_cstr
    mov rdi, [rsp + SB_ptr]
    mov rsi, [rsp + SB_len]
    call mem_dup
    mov rbx, rax
    mov rdi, rsp
    call sb_free
    mov rax, rbx
    EPILOGUE
