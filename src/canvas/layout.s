# Native UI layout: bounded integer pixels, no CSS interpreter.
.include "rhun.inc"
.include "canvas/canvas.inc"
.text
# Text metric: one UTF-8 scalar = 8 logical pixels, line=20. Rendering uses native font.
FN canvas_ui_text_height
    PROLOGUE
    mov rbx, rdi
    mov r12d, esi
    cmp r12d, 8
    jge 1f
    mov r12d, 8
1:  shr r12d, 3
    xor r13d, r13d
    mov r14d, 1
    mov r15, rbx
    call strlen
    mov rbx, rax
2:  test rbx, rbx
    jz 8f
    cmp byte ptr [r15], 10
    jne 3f
    inc r15
    dec rbx
    inc r14d
    xor r13d, r13d
    jmp 2b
3:  mov rdi, r15
    mov rsi, rbx
    call utf8_decode
    add r15, rdx
    sub rbx, rdx
    cmp r13d, r12d
    jb 4f
    inc r14d
    xor r13d, r13d
4:  inc r13d
    jmp 2b
8:  imul eax, r14d, 20
    EPILOGUE

# layout(model,scene). Root anchors to its source figure/frame.
FN canvas_ui_layout
    PROLOGUE
    mov rbx, rdi
    mov r12, rsi
    mov rsi, [rbx + UM_root]
    call canvas_ui_find
    mov r13, rax
    mov rdi, r12
    mov rsi, [r13 + UC_source]
    call scene_find
    test rax, rax
    jz 9f
    mov r14, rax
    mov rdi, rbx
    mov rsi, r13
    mov edx, [rax + CE_x]
    mov ecx, [rax + CE_y]
    mov r8d, [rax + CE_w]
    call canvas_ui_layout_node
    cmp dword ptr [r13 + UC_height], 0
    jne 9f
    cmp dword ptr [r14 + CE_kind], CT_FRAME
    jne 9f
    mov eax, [r14 + CE_h]
    mov [r13 + UC_h], eax
9:  EPILOGUE

# node layout(model,node,x,y,availablew). Width/height explicit > auto > min1.
canvas_ui_layout_node:
    PROLOGUE 48
    mov rbx, rdi
    mov r12, rsi
    mov [r12 + UC_x], edx
    mov [r12 + UC_y], ecx
    mov eax, [r12 + UC_width]
    test eax, eax
    jnz 1f
    mov eax, r8d
1:  cmp eax, 1
    jge 2f
    mov eax, 1
2:  mov [r12 + UC_w], eax
    mov esi, [r12 + UC_padding]
    add esi, esi
    sub eax, esi
    cmp eax, 1
    jge 3f
    mov eax, 1
3:  mov [rsp], eax                # inner width
    mov rdi, [r12 + UC_text]
    mov esi, eax
    call canvas_ui_text_height
    mov [rsp + 4], eax            # text header height
    cmp dword ptr [r12 + UC_type], U_TEXT
    jae .Llayout_leaf
    mov rax, [r12 + UC_text]
    cmp byte ptr [rax], 0
    jne 4f
    mov dword ptr [rsp + 4], 0
4:  xor r13d, r13d
    xor r14d, r14d
    xor r15d, r15d
    mov dword ptr [rsp + 8], 0    # fixed row widths
5:  cmp r13, [rbx + UM_nodes + VEC_len]
    jae 6f
    imul rax, r13, UC_SIZE
    add rax, [rbx + UM_nodes + VEC_ptr]
    mov rcx, [r12 + UC_id]
    cmp rcx, [rax + UC_parent]
    jne 51f
    inc r14d
    mov eax, [rax + UC_width]
    test eax, eax
    jnz 52f
    inc r15d
52: add [rsp + 8], eax
51: inc r13
    jmp 5b
6:  mov [rsp + 12], r14d         # child count
    mov eax, [rsp]
    test r14d, r14d
    jz 61f
    dec r14d
    imul r14d, [r12 + UC_gap]
    sub eax, r14d
    sub eax, [rsp + 8]
61: test r15d, r15d
    jz 62f
    cdq
    idiv r15d
62: cmp eax, 1
    jge 63f
    mov eax, 1
63: mov [rsp + 16], eax         # row auto width
    mov eax, [r12 + UC_x]
    add eax, [r12 + UC_padding]
    mov [rsp + 20], eax         # cursor x
    mov eax, [r12 + UC_y]
    add eax, [r12 + UC_padding]
    add eax, [rsp + 4]
    mov [rsp + 24], eax         # cursor y
    mov dword ptr [rsp + 28], 0 # accumulated child height
    mov dword ptr [rsp + 32], 0 # visited child count
    xor r13d, r13d
.Llayout_child:
    cmp r13, [rbx + UM_nodes + VEC_len]
    jae .Llayout_container_end
    imul r14, r13, UC_SIZE
    add r14, [rbx + UM_nodes + VEC_ptr]
    mov rax, [r12 + UC_id]
    cmp rax, [r14 + UC_parent]
    jne 8f
    mov r8d, [rsp]
    cmp dword ptr [r12 + UC_type], U_ROW
    jne 7f
    mov r8d, [rsp + 16]
7:  mov rdi, rbx
    mov rsi, r14
    mov edx, [rsp + 20]
    mov ecx, [rsp + 24]
    call canvas_ui_layout_node
    mov eax, [r14 + UC_h]
    cmp dword ptr [r12 + UC_type], U_ROW
    jne 71f
    cmp eax, [rsp + 28]
    jle 72f
    mov [rsp + 28], eax
72: mov eax, [r14 + UC_w]
    add eax, [r12 + UC_gap]
    add [rsp + 20], eax
    jmp 73f
71: add [rsp + 28], eax
    add eax, [r12 + UC_gap]
    add [rsp + 24], eax
    cmp dword ptr [rsp + 32], 0
    je 73f
    mov eax, [r12 + UC_gap]
    add [rsp + 28], eax
73: inc dword ptr [rsp + 32]
8:  inc r13
    jmp .Llayout_child
.Llayout_container_end:
    mov eax, [rsp + 28]
    add eax, [rsp + 4]
    jmp .Llayout_height
.Llayout_leaf:
    mov eax, [rsp + 4]
.Llayout_height:
    mov ecx, [r12 + UC_padding]
    lea eax, [rax + rcx*2]
    cmp dword ptr [r12 + UC_height], 0
    je 1f
    mov eax, [r12 + UC_height]
1:  cmp eax, 1
    jge 2f
    mov eax, 1
2:  mov [r12 + UC_h], eax
    EPILOGUE
