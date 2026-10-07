# Portable scene geometry export. SVG is an artifact, never a runtime renderer.
.include "rhun.inc"
.include "canvas/canvas.inc"
.text
# Escape UTF-8 text/attribute bytes; reused by semantic HTML generation.
FN canvas_xml_escape
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
1:  test r13, r13
    jz 9f
    movzx esi, byte ptr [r12]
    inc r12
    dec r13
    cmp esi, '&'
    je 2f
    cmp esi, '<'
    je 3f
    cmp esi, '>'
    je 4f
    cmp esi, '"'
    je 5f
    cmp esi, 39
    je 6f
    mov rdi, rbx
    call sb_push_byte
    jmp 1b
2:  lea rsi, [rip + .Lamp]
    jmp 7f
3:  lea rsi, [rip + .Llt]
    jmp 7f
4:  lea rsi, [rip + .Lgt]
    jmp 7f
5:  lea rsi, [rip + .Lquot]
    jmp 7f
6:  lea rsi, [rip + .Lapos]
7:  mov rdi, rbx
    call sb_push_cstr
    jmp 1b
9:  EPILOGUE

# sb, key, signed integer -> space key="integer".
canvas_svg_attr:
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov esi, ' '
    call sb_push_byte
    mov rdi, rbx
    mov rsi, r12
    call sb_push_cstr
    mov rdi, rbx
    lea rsi, [rip + .Lattr_open]
    call sb_push_cstr
    mov rdi, rbx
    mov rsi, r13
    call canvas_dump_int
    mov rdi, rbx
    mov esi, '"'
    call sb_push_byte
    EPILOGUE

FN canvas_export_svg
    PROLOGUE 48
    mov rbx, rdi
    mov r12, rsi
    mov qword ptr [rsp + 32], 0
    mov rdi, rbx
    mov rsi, [rbx + SC_selected]
    call scene_find
    test rax, rax
    jz 1f
    cmp dword ptr [rax + CE_kind], CT_FRAME
    jne 1f
    mov rcx, [rax + CE_id]
    mov [rsp + 32], rcx
    mov rcx, [rax + CE_x]
    mov [rsp], ecx
    mov ecx, [rax + CE_y]
    mov [rsp + 4], ecx
    mov ecx, [rax + CE_w]
    mov [rsp + 8], ecx
    mov ecx, [rax + CE_h]
    mov [rsp + 12], ecx
    jmp 2f
1:  mov dword ptr [rsp], 0
    mov dword ptr [rsp + 4], 0
    mov dword ptr [rsp + 8], 1024
    mov dword ptr [rsp + 12], 768
    xor r13d, r13d
11: cmp r13, [rbx + SC_elements + VEC_len]
    jae 2f
    imul rax, r13, CE_SIZE
    add rax, [rbx + SC_elements + VEC_ptr]
    mov ecx, [rax + CE_x]
    cmp ecx, [rsp]
    jge 12f
    mov [rsp], ecx
12: add ecx, [rax + CE_w]
    cmp ecx, [rsp + 8]
    jle 13f
    mov [rsp + 8], ecx
13: mov ecx, [rax + CE_y]
    cmp ecx, [rsp + 4]
    jge 14f
    mov [rsp + 4], ecx
14: add ecx, [rax + CE_h]
    cmp ecx, [rsp + 12]
    jle 15f
    mov [rsp + 12], ecx
15: inc r13
    jmp 11b
2:  mov rdi, r12
    lea rsi, [rip + .Lsvg_header]
    call sb_push_cstr
    cmp qword ptr [rsp + 32], 0
    jne 21f
    mov eax, [rsp]
    sub [rsp + 8], eax
    mov eax, [rsp + 4]
    sub [rsp + 12], eax
21: xor r13d, r13d
3:  mov rdi, r12
    movsxd rsi, dword ptr [rsp + r13*4]
    call canvas_dump_int
    mov rdi, r12
    mov esi, ' '
    call sb_push_byte
    inc r13
    cmp r13d, 4
    jb 3b
    mov rdi, r12
    lea rsi, [rip + .Lsvg_defs]
    call sb_push_cstr
    xor r13d, r13d
.Lsvg_element:
    cmp r13, [rbx + SC_elements + VEC_len]
    jae .Lsvg_end
    imul r14, r13, CE_SIZE
    add r14, [rbx + SC_elements + VEC_ptr]
    mov rax, [rsp + 32]
    test rax, rax
    jz 1f
    cmp rax, [r14 + CE_frame]
    jne .Lsvg_next
1:  mov rdi, r12
    lea rsi, [rip + .Lgroup_open]
    call sb_push_cstr
    mov rdi, r12
    mov rsi, [r14 + CE_id]
    call sb_push_u64
    mov rdi, r12
    mov esi, '"'
    call sb_push_byte
    cmp dword ptr [r14 + CE_angle], 0
    je 2f
    mov rdi, r12
    lea rsi, [rip + .Lrotate]
    call sb_push_cstr
    mov rdi, r12
    movsxd rsi, dword ptr [r14 + CE_angle]
    call canvas_dump_int
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
    mov esi, [r14 + CE_w]
    sar esi, 1
    add esi, [r14 + CE_x]
    movsxd rsi, esi
    mov rdi, r12
    call canvas_dump_int
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
    mov esi, [r14 + CE_h]
    sar esi, 1
    add esi, [r14 + CE_y]
    movsxd rsi, esi
    mov rdi, r12
    call canvas_dump_int
    mov rdi, r12
    lea rsi, [rip + .Lrotate_end]
    call sb_push_cstr
2:  mov rdi, r12
    mov esi, '>'
    call sb_push_byte
    cmp dword ptr [r14 + CE_kind], CT_ELLIPSE
    je .Lsvg_ellipse
    cmp dword ptr [r14 + CE_kind], CT_IMAGE
    jne 104f
    mov rdi, r12
    mov rsi, r14
    call canvas_svg_image
    test eax, eax
    jnz .Lsvg_group_end
104: cmp dword ptr [r14 + CE_kind], CT_ELLIPSE
    je .Lsvg_ellipse
    cmp dword ptr [r14 + CE_kind], CT_ARROW
    je .Lsvg_line
    cmp dword ptr [r14 + CE_kind], CT_LINE
    je .Lsvg_line
    cmp dword ptr [r14 + CE_kind], CT_STROKE
    je .Lsvg_stroke
    cmp dword ptr [r14 + CE_kind], CT_TEXT
    je .Lsvg_text
    mov rdi, r12
    lea rsi, [rip + .Lrect]
    call sb_push_cstr
    lea r15, [rip + .Lrect_attrs]
3:  cmp qword ptr [r15], 0
    je .Lsvg_style
    mov rcx, [r15 + 8]
    movsxd rdx, dword ptr [r14 + rcx]
    mov rdi, r12
    mov rsi, [r15]
    call canvas_svg_attr
    add r15, 16
    jmp 3b
.Lsvg_ellipse:
    mov rdi, r12
    lea rsi, [rip + .Lellipse]
    call sb_push_cstr
    mov edx, [r14 + CE_w]
    sar edx, 1
    add edx, [r14 + CE_x]
    movsxd rdx, edx
    mov rdi, r12
    lea rsi, [rip + .Lcx]
    call canvas_svg_attr
    mov edx, [r14 + CE_h]
    sar edx, 1
    add edx, [r14 + CE_y]
    movsxd rdx, edx
    mov rdi, r12
    lea rsi, [rip + .Lcy]
    call canvas_svg_attr
    mov edx, [r14 + CE_w]
    sar edx, 1
    mov rdi, r12
    lea rsi, [rip + .Lrx]
    call canvas_svg_attr
    mov edx, [r14 + CE_h]
    sar edx, 1
    mov rdi, r12
    lea rsi, [rip + .Lry]
    call canvas_svg_attr
    jmp .Lsvg_style
.Lsvg_line:
    mov rdi, r12
    lea rsi, [rip + .Lline]
    call sb_push_cstr
    mov rdi, r12
    lea rsi, [rip + .Lx1]
    movsxd rdx, dword ptr [r14 + CE_x]
    call canvas_svg_attr
    mov rdi, r12
    lea rsi, [rip + .Ly1]
    movsxd rdx, dword ptr [r14 + CE_y]
    call canvas_svg_attr
    mov edx, [r14 + CE_x]
    add edx, [r14 + CE_w]
    movsxd rdx, edx
    mov rdi, r12
    lea rsi, [rip + .Lx2]
    call canvas_svg_attr
    mov edx, [r14 + CE_y]
    add edx, [r14 + CE_h]
    movsxd rdx, edx
    mov rdi, r12
    lea rsi, [rip + .Ly2]
    call canvas_svg_attr
    cmp dword ptr [r14 + CE_kind], CT_ARROW
    jne .Lsvg_style
    mov rdi, r12
    lea rsi, [rip + .Lmarker]
    call sb_push_cstr
    jmp .Lsvg_style
.Lsvg_stroke:
    mov rdi, r12
    lea rsi, [rip + .Lpolyline]
    call sb_push_cstr
    xor r15d, r15d
1:  cmp r15, [r14 + CE_points + VEC_len]
    jae 2f
    mov rax, [r14 + CE_points + VEC_ptr]
    mov esi, [rax + r15*8]
    add esi, [r14 + CE_x]
    movsxd rsi, esi
    mov rdi, r12
    call canvas_dump_int
    mov rdi, r12
    mov esi, ','
    call sb_push_byte
    mov rax, [r14 + CE_points + VEC_ptr]
    mov esi, [rax + r15*8 + 4]
    add esi, [r14 + CE_y]
    movsxd rsi, esi
    mov rdi, r12
    call canvas_dump_int
    mov rdi, r12
    mov esi, ' '
    call sb_push_byte
    inc r15
    jmp 1b
2:  mov rdi, r12
    mov esi, '"'
    call sb_push_byte
.Lsvg_style:
    mov rdi, r12
    lea rsi, [rip + .Lstroke]
    call sb_push_cstr
    mov rdi, r12
    mov esi, [r14 + CE_color]
    call canvas_export_color
    mov rdi, r12
    lea rsi, [rip + .Lfill]
    call sb_push_cstr
    mov rdi, r12
    mov esi, [r14 + CE_fill]
    test esi, esi
    jz 1f
    call canvas_export_color
    jmp 2f
1:  lea rsi, [rip + .Lnone]
    call sb_push_cstr
2:  mov rdi, r12
    lea rsi, [rip + .Lshape_end]
    call sb_push_cstr
    jmp .Lsvg_group_end
.Lsvg_text:
    mov rdi, r12
    lea rsi, [rip + .Ltext]
    call sb_push_cstr
    mov rdi, r12
    lea rsi, [rip + .Lx]
    movsxd rdx, dword ptr [r14 + CE_x]
    call canvas_svg_attr
    mov edx, [r14 + CE_y]
    add edx, [r14 + CE_fontsize]
    movsxd rdx, edx
    mov rdi, r12
    lea rsi, [rip + .Ly]
    call canvas_svg_attr
    mov rdi, r12
    lea rsi, [rip + .Lfont]
    mov edx, [r14 + CE_fontsize]
    call canvas_svg_attr
    mov rdi, r12
    lea rsi, [rip + .Ltext_fill]
    call sb_push_cstr
    mov r15, [r14 + CE_text]
    test r15, r15
    jz 3f
    xor r15d, r15d
101: mov rax, [r14 + CE_text]
    add rax, r15
    xor edx, edx
102: cmp byte ptr [rax + rdx], 0
    je 103f
    cmp byte ptr [rax + rdx], 10
    je 103f
    inc rdx
    jmp 102b
103: mov [rsp + 40], rdx
    mov rdi, r12
    mov rsi, rax
    call canvas_xml_escape
    add r15, [rsp + 40]
    mov rax, [r14 + CE_text]
    cmp byte ptr [rax + r15], 0
    je 3f
    inc r15
    mov rdi, r12
    lea rsi, [rip + .Ltspan]
    call sb_push_cstr
    mov rdi, r12
    lea rsi, [rip + .Lx]
    movsxd rdx, dword ptr [r14 + CE_x]
    call canvas_svg_attr
    mov rdi, r12
    lea rsi, [rip + .Ltspan_dy]
    call sb_push_cstr
    # Close every new line immediately after text; nested tspans inherit x.
    jmp 101b
3:  mov rdi, r12
    lea rsi, [rip + .Ltext_end]
    call sb_push_cstr
.Lsvg_group_end:
    mov rdi, r12
    lea rsi, [rip + .Lgroup_end]
    call sb_push_cstr
.Lsvg_next:
    inc r13
    jmp .Lsvg_element
.Lsvg_end:
    mov rdi, r12
    lea rsi, [rip + .Lsvg_tail]
    call sb_push_cstr
    mov eax, 1
    cmp qword ptr [r12 + SB_len], 8 << 20
    jbe 9f
    xor eax, eax
9:  EPILOGUE
.section .rodata
.Lamp: .asciz "&amp;"
.Llt: .asciz "&lt;"
.Lgt: .asciz "&gt;"
.Lquot: .asciz "&quot;"
.Lapos: .asciz "&#39;"
.Lattr_open: .asciz "=\""
.Lsvg_header: .asciz "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\""
.Lsvg_defs: .asciz "\" overflow=\"hidden\"><defs><marker id=\"rhun-arrow\" markerWidth=\"10\" markerHeight=\"10\" refX=\"9\" refY=\"5\" orient=\"auto\"><path d=\"M0,0 L10,5 L0,10\" fill=\"none\" stroke=\"#8da4ff\"/></marker></defs>\n"
.Lgroup_open: .asciz "<g data-scene-id=\""
.Lgroup_end: .asciz "</g>\n"
.Lrotate: .asciz " transform=\"rotate("
.Lrotate_end: .asciz ")\""
.Lrect: .asciz "<rect"
.Lellipse: .asciz "<ellipse"
.Lline: .asciz "<line"
.Lpolyline: .asciz "<polyline points=\""
.Lmarker: .asciz " marker-end=\"url(#rhun-arrow)\""
.Lstroke: .asciz " stroke="
.Lfill: .asciz " fill="
.Lnone: .asciz "\"none\""
.Lshape_end: .asciz " stroke-width=\"2\"/>"
.Ltext: .asciz "<text xml:space=\"preserve\""
.Ltext_fill: .asciz " fill=\"#d8dee9\" font-family=\"sans-serif\"><tspan>"
.Ltext_end: .asciz "</tspan></text>"
.Ltspan: .asciz "</tspan><tspan"
.Ltspan_dy: .asciz " dy=\"1.25em\">"
.Lsvg_tail: .asciz "</svg>\n"
.Lx: .asciz "x"
.Ly: .asciz "y"
.Lw: .asciz "width"
.Lh: .asciz "height"
.Lcx: .asciz "cx"
.Lcy: .asciz "cy"
.Lrx: .asciz "rx"
.Lry: .asciz "ry"
.Lx1: .asciz "x1"
.Ly1: .asciz "y1"
.Lx2: .asciz "x2"
.Ly2: .asciz "y2"
.Lfont: .asciz "font-size"
.p2align 3
.Lrect_attrs: .quad .Lx, CE_x, .Ly, CE_y, .Lw, CE_w, .Lh, CE_h, 0

.text
canvas_svg_image:
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    mov rdi, [r12 + CE_image]
    test rdi, rdi
    jz 8f
    call image_probe
    cmp eax, 1
    je 1f
    cmp eax, 2
    jne 8f
1:  mov r15d, eax
    mov rdi, [r12 + CE_image]
    mov ecx, 4 << 20
    call file_read_limited
    test rax, rax
    jz 8f
    mov r13, rax
    mov r14, rdx
    mov rdi, rbx
    lea rsi, [rip + .Limage_tag]
    call sb_push_cstr
    lea r15, [rip + .Lrect_attrs]
2:  cmp qword ptr [r15], 0
    je 3f
    mov rcx, [r15 + 8]
    movsxd rdx, dword ptr [r12 + rcx]
    mov rdi, rbx
    mov rsi, [r15]
    call canvas_svg_attr
    add r15, 16
    jmp 2b
3:  mov rdi, [r12 + CE_image]
    call image_probe
    lea rsi, [rip + .Lpng_uri]
    cmp eax, 1
    je 4f
    lea rsi, [rip + .Ljpeg_uri]
4:  mov rdi, rbx
    call sb_push_cstr
    mov rdi, rbx
    mov rsi, r13
    mov rdx, r14
    call chat_base64
    mov rdi, rbx
    lea rsi, [rip + .Limage_end]
    call sb_push_cstr
    mov rdi, r13
    call mem_free
    mov eax, 1
    EPILOGUE
8:  xor eax, eax
    EPILOGUE
.section .rodata
.Limage_tag: .asciz "<image"
.Lpng_uri: .asciz " href=\"data:image/png;base64,"
.Ljpeg_uri: .asciz " href=\"data:image/jpeg;base64,"
.Limage_end: .asciz "\"/>"
