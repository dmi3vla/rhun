.include "rhun.inc"
.include "canvas/canvas.inc"
.data
r2_fd: .long -1
r2_exit: .long -1
.bss
.p2align 3
r2_pid: .long 0
r2_out: .zero SB_SIZE
r2_path: .quad 0
r2_project: .quad 0
r2_deadline: .quad 0
r2_mtime: .quad 0
r2_message: .quad 0
.text
FN cmd_radare_analyze
    lea rdi, [rip + .Lbinary_prompt]
    mov esi, 13
    jmp prompt_open
FN cmd_radare_address
    lea rdi, [rip + .Laddress_prompt]
    mov esi, 14
    jmp prompt_open
FN radare_analyze_file
    lea rsi, [rip + .Lentry_cmd]
    jmp radare_start
# Only strict numeric addresses can enter the fixed Radare command.
FN radare_analyze_address
    PROLOGUE SB_SIZE
    mov rbx, rdi
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, rbx
    call strlen
    mov r12, rax
    mov rdi, rbx
    mov rsi, r12
    cmp r12, 2
    jb .Laddress_decimal
    cmp word ptr [rbx], 0x7830
    jne .Laddress_decimal
    add rdi, 2
    sub rsi, 2
    mov r12, rsi
    cmp rsi, 16
    ja .Laddress_bad
    call parse_hex
    jmp .Laddress_check
.Laddress_decimal:
    cmp r12, 16
    ja .Laddress_bad
    call parse_u64
.Laddress_check:
    test rdx, rdx
    jz .Laddress_bad
    cmp rdx, r12
    jne .Laddress_bad
    mov rcx, 9007199254740991
    cmp rax, rcx
    ja .Laddress_bad
    mov r13, rax
    call canvas_active
    test rax, rax
    jz .Laddress_bad
    mov rdi, [rax + SC_analysis]
    test rdi, rdi
    jz .Laddress_bad
    mov rbx, rdi
    call strlen
    mov rsi, rax
    mov rdi, rbx
    call json_parse_complete
    mov rdi, rax
    lea rsi, [rip + r2_binary]
    call json_get
    mov rdi, rax
    mov esi, 4096
    call scene_owned_json_string
    test rax, rax
    jz .Laddress_bad
    mov rbx, rax
    mov rdi, rsp
    lea rsi, [rip + .Lfunction_cmd]
    call sb_push_cstr
    mov rdi, rsp
    mov rsi, r13
    call radare_push_address
    mov rdi, rsp
    lea rsi, [rip + .Lfunction_graph]
    call sb_push_cstr
    mov rdi, rsp
    mov rsi, r13
    call radare_push_address
    mov rdi, rbx
    mov rsi, [rsp + SB_ptr]
    call radare_start
    mov rdi, rbx
    call mem_free
    jmp .Laddress_free
.Laddress_bad:
    lea rdi, [rip + .Lbad_address]
    call radare_notify
.Laddress_free: mov rdi, rsp
    call sb_free
    EPILOGUE
FN radare_notify
    mov [rip + r2_message], rdi
    jmp app_toast
FN radare_start
.ifdef WINDOWS
    lea rdi, [rip + .Lunsupported]
    jmp radare_notify
.else
    PROLOGUE 80
    mov rbx, rdi
    mov r12, rsi
    cmp dword ptr [rip + r2_pid], 0
    jne .Lstart_busy
    # Palette provides an absolute path; require a regular file, never an IO URI.
    cmp byte ptr [rbx], '/'
    jne .Lstart_path
    mov rdi, rbx
    call file_type
    cmp eax, 0x8000
    jne .Lstart_path
    lea rdi, [rip + .Lenv_bin]
    call getenv
    test rax, rax
    jz .Lstart_default
    cmp byte ptr [rax], 0
    jne .Lstart_discover
.Lstart_default: lea rax, [rip + .Lr2]
.Lstart_discover: mov rdi, rax
    call proc_which
    test rax, rax
    jz .Lstart_missing
    mov r13, rax
    mov rdi, rax
    mov esi, 1
    SYS SYS_access
    test rax, rax
    jns .Lstart_access_ok
    mov rdi, r13
    call mem_free
    jmp .Lstart_missing
.Lstart_access_ok:
    mov [rsp], r13
    lea rax, [rip + .Lno_config]
    mov [rsp + 8], rax
    lea rax, [rip + .Lquiet_errors]
    mov [rsp + 16], rax
    lea rax, [rip + .Lquiet]
    mov [rsp + 24], rax
    lea rax, [rip + .Lcmdflag]
    mov [rsp + 32], rax
    mov [rsp + 40], r12
    mov [rsp + 48], rbx
    mov qword ptr [rsp + 56], 0
    lea rdi, [rip + .Lextras]
    call env_make
    mov r14, rax
    mov rdi, rsp
    mov rsi, rax
    xor edx, edx
    call run_piped
    mov r15, rax
    mov r12d, edx
    mov rdi, r14
    call mem_free
    mov rdi, r13
    call mem_free
    test r15, r15
    jle .Lstart_missing
    mov [rip + r2_pid], r15d
    mov [rip + r2_fd], r12d
    mov dword ptr [rip + r2_exit], -1
    mov rdi, rbx
    call strlen
    mov rsi, rax
    mov rdi, rbx
    call mem_dup
    mov [rip + r2_path], rax
    mov rdi, rax
    call file_mtime_ns
    mov [rip + r2_mtime], rax
    mov rdi, [rip + g_project]
    test rdi, rdi
    jnz .Lstart_project
    lea rdi, [rip + .Lempty]
.Lstart_project:
    mov rbx, rdi
    call strlen
    mov rsi, rax
    mov rdi, rbx
    call mem_dup
    mov [rip + r2_project], rax
    mov ebx, 30000
    lea rdi, [rip + .Lenv_timeout]
    call getenv
    test rax, rax
    jz .Lstart_time
    mov rdi, rax
    mov esi, 8
    call parse_u64
    cmp rax, 50
    jb .Lstart_time
    cmp rax, 30000
    ja .Lstart_time
    mov ebx, eax
.Lstart_time:
    call time_ms
    add rax, rbx
    mov [rip + r2_deadline], rax
    mov edi, [rip + r2_fd]
    mov esi, POLLIN
    lea rdx, [rip + radare_read]
    xor ecx, ecx
    call watch_add
    lea rdi, [rip + .Lrunning]
    call radare_notify
    EPILOGUE
.Lstart_busy: lea rdi, [rip + .Lbusy]
    jmp .Lstart_error
.Lstart_path: lea rdi, [rip + .Lbad_path]
    jmp .Lstart_error
.Lstart_missing: lea rdi, [rip + .Lmissing]
.Lstart_error: call radare_notify
    EPILOGUE
.endif
# Read bounded chunks; EOF closes the pipe, exit is reaped separately, never wait-blocks UI.
radare_read:
    PROLOGUE
.Lread_next:
    lea rdi, [rip + r2_out]
    mov esi, 8192
    call sb_reserve
    mov rsi, rax
    mov edi, [rip + r2_fd]
    mov edx, 8192
    SYS SYS_read
    cmp rax, -EINTR
    je .Lread_next
    cmp rax, -EAGAIN
    je .Lread_done
    test rax, rax
    jle .Lread_eof
    add [rip + r2_out + SB_len], rax
    cmp qword ptr [rip + r2_out + SB_len], 8 << 20
    jbe .Lread_next
    call cmd_radare_cancel
    lea rdi, [rip + .Loversize]
    call radare_notify
    jmp .Lread_done
.Lread_eof: call radare_close_pipe
.Lread_done: EPILOGUE
radare_close_pipe:
    push rbx
    mov ebx, [rip + r2_fd]
    test ebx, ebx
    js .Lpipe_done
    mov edi, ebx
    call watch_remove
    mov edi, ebx
    SYS SYS_close
    mov dword ptr [rip + r2_fd], -1
.Lpipe_done: pop rbx
    ret
FN cmd_radare_cancel
    PROLOGUE
    cmp dword ptr [rip + r2_pid], 0
    je .Lcancel_done
    call radare_close_pipe
    cmp dword ptr [rip + r2_exit], -1
    jne .Lcancel_clear
    mov edi, [rip + r2_pid]
    mov esi, 9
    SYS SYS_kill
    mov edi, [rip + r2_pid]
    xor esi, esi
    call proc_wait
.Lcancel_clear:
    mov dword ptr [rip + r2_pid], 0
    mov rdi, [rip + r2_path]
    call mem_free
    mov qword ptr [rip + r2_path], 0
    mov rdi, [rip + r2_project]
    call mem_free
    mov qword ptr [rip + r2_project], 0
    lea rdi, [rip + r2_out]
    call sb_free
    lea rdi, [rip + .Lcancelled]
    call radare_notify
.Lcancel_done: EPILOGUE
FN radare_timeout
    mov eax, -1
    cmp dword ptr [rip + r2_pid], 0
    je .Ltimeout_done
    mov eax, 20
.Ltimeout_done: ret
FN radare_tick
    PROLOGUE SB_SIZE
    cmp dword ptr [rip + r2_pid], 0
    je .Ltick_done
    mov rdi, [rip + g_project]
    test rdi, rdi
    jnz .Ltick_project
    lea rdi, [rip + .Lempty]
.Ltick_project:
    mov rsi, [rip + r2_project]
    call strcmp_eq
    test eax, eax
    jz .Ltick_cancel
    call time_ms
    cmp rax, [rip + r2_deadline]
    jae .Ltick_timeout
    cmp dword ptr [rip + r2_exit], -1
    jne .Ltick_wait_eof
    mov edi, [rip + r2_pid]
    mov esi, 1
    call proc_wait
    cmp eax, -1
    je .Ltick_done
    mov [rip + r2_exit], eax
.Ltick_wait_eof:
    cmp dword ptr [rip + r2_fd], -1
    jne .Ltick_done
    cmp dword ptr [rip + r2_exit], 0
    jne .Ltick_fail
    mov rdi, [rip + r2_path]
    call file_mtime_ns
    cmp rax, [rip + r2_mtime]
    jne .Ltick_stale
    mov rdi, [rip + r2_out + SB_ptr]
    mov rsi, [rip + r2_out + SB_len]
    call radare_import_stream
    test rax, rax
    jz .Ltick_fail
    mov rbx, rax
    mov rdi, rsp
    xor esi, esi
    mov edx, SB_SIZE
    call memset
    mov rdi, rsp
    lea rsi, [rip + .Lanalysis_header]
    call sb_push_cstr
    mov rdi, [rip + r2_path]
    call strlen
    mov rdx, rax
    mov rdi, rsp
    mov rsi, [rip + r2_path]
    call chat_json_quote
    mov rdi, rsp
    lea rsi, [rip + .Lanalysis_tail]
    call sb_push_cstr
    mov rdi, [rbx + SC_analysis]
    call mem_free
    mov rdi, [rsp + SB_ptr]
    mov rsi, [rsp + SB_len]
    call mem_dup
    mov [rbx + SC_analysis], rax
    mov rdi, rsp
    call sb_free
    call cmd_radare_cancel
    mov rdi, rbx
    call radare_open_scene
    lea rdi, [rip + .Lready]
    call radare_notify
    jmp .Ltick_done
.Ltick_stale: call cmd_radare_cancel
    lea rdi, [rip + .Lstale]
    call radare_notify
    jmp .Ltick_done
.Ltick_fail: call cmd_radare_cancel
    lea rdi, [rip + .Lfailed]
    call radare_notify
    jmp .Ltick_done
.Ltick_timeout: call cmd_radare_cancel
    lea rdi, [rip + .Ltimed_out]
    call radare_notify
    jmp .Ltick_done
.Ltick_cancel: call cmd_radare_cancel
.Ltick_done: EPILOGUE
FN radare_dump
    PROLOGUE
    mov rbx, rdi
    lea rsi, [rip + .Lstatus]
    call sb_push_cstr
    mov rdi, rbx
    xor esi, esi
    cmp dword ptr [rip + r2_pid], 0
    setne sil
    call sb_push_u64
    mov rdi, rbx
    lea rsi, [rip + .Lbytes]
    call sb_push_cstr
    mov rdi, rbx
    mov rsi, [rip + r2_out + SB_len]
    call sb_push_u64
    mov rdi, rbx
    lea rsi, [rip + .Lmessage]
    call sb_push_cstr
    mov r12, [rip + r2_message]
    test r12, r12
    jnz .Ldump_message
    lea r12, [rip + .Lempty]
.Ldump_message:
    mov rdi, r12
    call strlen
    mov rdx, rax
    mov rdi, rbx
    mov rsi, r12
    call chat_json_quote
    mov rdi, rbx
    lea rsi, [rip + .Lend]
    call sb_push_cstr
    EPILOGUE
.section .rodata
.Lbinary_prompt: .asciz "Radare2: analyze binary (entry CFG)"
.Laddress_prompt: .asciz "Radare2: function address (decimal or 0x...)"
.Lentry_cmd: .asciz "aa;agfj @ entry0"
.Lfunction_cmd: .asciz "aa;af @ "
.Lfunction_graph: .asciz ";agfj @ "
.Lr2: .asciz "r2"
.Lenv_bin: .asciz "RHUN_RADARE2"
.Lenv_timeout: .asciz "RHUN_RADARE_TIMEOUT_MS"
.Lno_config: .asciz "-N"
.Lquiet_errors: .asciz "-2"
.Lquiet: .asciz "-q"
.Lcmdflag: .asciz "-c"
.Lno_args: .asciz "R2_ARGS="
.Lno_plugins: .asciz "R2_NOPLUGINS=1"
.p2align 3
.Lextras: .quad .Lno_plugins, .Lno_args, 0
.Lanalysis_header: .asciz "{\"type\":\"rhun-radare2\",\"version\":1,\"binary\":"
.Lanalysis_tail: .asciz ",\"trace\":[]}"
.Lempty: .asciz ""
.Lrunning: .asciz "Radare2: analyzing in background; Cancel Analysis stops it"
.Lready: .asciz "Radare2: CFG ready (static control flow, no target execution)"
.Lcancelled: .asciz "Radare2: analysis cancelled"
.Lstale: .asciz "Radare2: binary changed during analysis; result discarded"
.Lfailed: .asciz "Radare2: analyzer failed or CFG invalid/too large"
.Lmissing: .asciz "Radare2: executable missing; install r2 or set RHUN_RADARE2"
.Lbusy: .asciz "Radare2: analysis already running; cancel before retrying"
.Lbad_path: .asciz "Radare2: analysis requires an absolute regular file path"
.Lbad_address: .asciz "Radare2: select an analyzed tab and enter a numeric function address"
.Loversize: .asciz "Radare2: output exceeded 8 MiB; analysis stopped"
.Ltimed_out: .asciz "Radare2: analysis deadline exceeded"
.Lunsupported: .asciz "Radare2: native analyzer transport not available on Windows"
.Lstatus: .asciz "{\"running\":"
.Lbytes: .asciz ",\"bytes\":"
.Lmessage: .asciz ",\"message\":"
.Lend: .asciz "}\n"
