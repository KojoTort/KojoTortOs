
[org 0x7c00]
[bits 16]

init:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    mov ah, 0x00
    mov al, 0x03
    int 0x10

    mov ah, 0x02
    mov bh, 0
    mov dh, 12
    mov dl, 33
    int 0x10

    mov si, welcome_msg
    call print_string_no_newline

    mov ah, 0x00
    int 0x16

    call clear_screen
    mov si, console_msg
    call print_string
    
main_loop:
    mov si, prompt
    call print_string
    mov di, buffer
    call get_string
    
    mov si, buffer
    mov di, cmd_help
    call strcmp
    je .help_cmd
    
    mov si, buffer
    mov di, cmd_clear
    call strcmp
    je .clear_cmd
    
    mov si, buffer
    mov di, cmd_red
    call strcmp
    je .red_cmd
    
    mov si, buffer
    mov di, cmd_blue
    call strcmp
    je .blue_cmd
    
    mov si, buffer
    mov di, cmd_off
    call strcmp
    je .off_cmd
    
    mov si, buffer
    cmp byte [si], 0
    je main_loop
    
    mov si, unknown_cmd
    call print_string
    jmp main_loop
    
.help_cmd:
    mov si, help_text
    call print_string
    jmp main_loop

.clear_cmd:
    call clear_screen
    jmp main_loop

.red_cmd:
    mov bh, 0x4F
    call set_color
    jmp main_loop

.blue_cmd:
    mov bh, 0x1F
    call set_color
    jmp main_loop

.off_cmd:
    mov si, off_msg
    call print_string
    mov ah, 0x00
    int 0x16
    mov ax, 0x5307
    mov bx, 0x0001
    mov cx, 0x0003
    int 0x15
    ret

set_color:
    mov ah, 0x06
    xor al, al
    xor cx, cx
    mov dx, 0x184F
    int 0x10
    ret

print_string:
    call print_string_no_newline
    mov ax, 0x0e0d
    int 0x10
    mov al, 0x0a
    int 0x10
    ret

print_string_no_newline:
    mov ah, 0x0e
.loop:
    lodsb
    test al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    ret

get_string:
    xor cx, cx
.loop:
    mov ah, 0x00
    int 0x16
    
    cmp al, 0x0D
    je .done
    
    cmp al, 0x08
    je .backspace
    
    cmp cx, 32
    je .loop
    
    mov ah, 0x0e
    int 0x10
    
    stosb
    inc cx
    jmp .loop
    
.backspace:
    test cx, cx
    jz .loop
    
    dec di
    dec cx
    
    mov ah, 0x0e
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    
    jmp .loop
    
.done:
    mov al, 0
    stosb
    mov ax, 0x0e0d
    int 0x10
    mov al, 0x0a
    int 0x10
    ret

clear_screen:
    mov ah, 0x00
    mov al, 0x03
    int 0x10
    ret

strcmp:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .not_equal
    test al, al
    jz .equal
    inc si
    inc di
    jmp strcmp
.not_equal:
    clc
    ret
.equal:
    stc
    ret

welcome_msg: db 'KojotortOS', 0
console_msg: db 'Type help', 0x0D, 0x0A, 0
prompt: db '>', 0
cmd_help: db 'help', 0
cmd_clear: db 'clear', 0
cmd_red: db 'red', 0
cmd_blue: db 'blue', 0
cmd_off: db 'off', 0
unknown_cmd: db '?', 0x0D, 0x0A, 0
help_text: db 'Commands:', 0x0D, 0x0A
          db 'help clear off', 0x0D, 0x0A
          db 'Colors: red blue', 0x0D, 0x0A, 0
off_msg: db 'Press key to off', 0x0D, 0x0A, 0

buffer: times 33 db 0

times 510-($-$$) db 0
dw 0xaa55
