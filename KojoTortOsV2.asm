[BITS 16]
[ORG 0x7C00]

    
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    
    mov [bootdrive], dl

   
    mov ah, 0x02        
    mov al, 15          
    mov ch, 0           
    mov cl, 2           
    mov dh, 0           
    mov dl, [bootdrive] 
    mov bx, additional_sectors 
    int 0x13
    jc disk_error

    
    mov si, init_dir
    call print_string
    
    
    mov di, buffer
    mov cx, 512         
    xor ax, ax          
    rep stosb
    
    
    mov di, buffer
    mov si, dot_entry
    mov cx, 32          
    rep movsb
    
    
    mov di, buffer + 32
    mov si, dotdot_entry
    mov cx, 32
    rep movsb
    
    
    mov ax, 0x0301     
    mov cx, 0x0002      
    mov dh, 0          
    mov dl, [bootdrive]
    mov bx, buffer
    int 0x13
    jc disk_error

    
    mov ax, 0x0003  
    int 0x10
    mov ah, 0x0B    
    mov bh, 0       
    mov bl, 1       
    int 0x10

    
    jmp main_code

disk_error:
    mov si, disk_error_msg
    call print_string_boot
    jmp $


print_string_boot:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    jmp print_string_boot
.done:
    ret


bootdrive db 0
disk_error_msg db 'Error loading additional sectors!', 13, 10, 0

times 510-($-$$) db 0
dw 0xAA55


additional_sectors:


print_string:
    pusha
.loop:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    jmp .loop
.done:
    popa
    ret

main_code:
    
    mov si, welcome_screen
    call print_string
    
    
    mov ah, 0
    int 0x16

    
    mov ax, 0x0003
    int 0x10

command_loop:
    
    mov si, prompt
    call print_string

    
    mov di, cmd_buffer
    call read_string

    
    mov si, cmd_buffer
    mov di, cmd_help
    call strcmp_command
    jc do_help

    mov si, cmd_buffer
    mov di, cmd_dir
    call strcmp_command
    jc do_dir

    mov si, cmd_buffer
    mov di, cmd_exit
    call strcmp_command
    jc do_exit

    mov si, cmd_buffer
    mov di, cmd_makedir
    call strcmp_command
    jc do_makedir

    mov si, cmd_buffer
    mov di, cmd_cd
    call strcmp_command
    jc do_cd

    mov si, cmd_buffer
    mov di, cmd_color
    call strcmp_command
    jc do_color

    
    mov si, unknown_cmd
    call print_string
    jmp command_loop


check_directory:
    pusha
    
    xor ax, ax
    mov dl, [bootdrive]
    int 0x13
    jc .error

    
    mov ax, 0x0201      
    mov cx, 0x0002      
    mov dh, 0           
    mov dl, [bootdrive]
    mov bx, buffer
    int 0x13
    jc .error

    
    mov si, debug_checking
    call print_string
    mov si, arg_buffer
    call print_string
    mov si, newline
    call print_string

    
    mov si, arg_buffer
    mov di, filename_buffer
    mov cx, 11          
    mov al, ' '         
    rep stosb          

    mov si, arg_buffer
    mov di, filename_buffer
    mov cx, 8           
.copy_name:
    lodsb
    or al, al           
    jz .search_dir      
    stosb
    loop .copy_name

.search_dir:
    
    mov si, debug_prepared
    call print_string
    mov si, filename_buffer
    mov cx, 11
.show_name:
    lodsb
    push ax
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    pop ax
    loop .show_name
    mov si, newline
    call print_string

    ; Ищем директорию в буфере
    mov cx, 16          
    mov si, buffer      
.check_entry:
    push cx
    push si

    ; Проверяем атрибут (0x10 = директория)
    mov al, [si + 11]   
    and al, 0x10
    jz .next_entry      

    ; Сравниваем имя
    mov di, filename_buffer
    mov cx, 11          
    push si
    push di
.compare_loop:
    lodsb
    mov ah, [di]
    inc di
    cmp al, ah
    jne .compare_fail
    loop .compare_loop
    pop di
    pop si
    jmp .found          

.compare_fail:
    pop di
    pop si

.next_entry:
    pop si
    pop cx
    add si, 32          
    loop .check_entry
    
    
    mov si, debug_not_found
    call print_string
    popa
    clc
    ret

.found:
    mov si, debug_found
    call print_string
    pop si
    pop cx
    popa
    stc                 
    ret

.error:
    mov si, debug_error
    call print_string
    popa
    clc
    ret


do_makedir:
    
    mov si, cmd_buffer
    call get_argument
    jnc .no_arg

    
    mov si, creating_msg
    call print_string
    mov si, arg_buffer
    call print_string
    mov si, newline
    call print_string

    
    call create_directory
    jnc .error

    mov si, makedir_success
    call print_string
    jmp command_loop

.error:
    mov si, makedir_error
    call print_string
    jmp command_loop

.no_arg:
    mov si, makedir_usage
    call print_string
    jmp command_loop


do_dir:
    
    mov si, dir_header
    call print_string
    
    
    mov si, current_dir_msg
    call print_string
    
    
    mov al, [current_dir]
    or al, al
    jnz .show_current_dir
    
    mov si, root_dir_msg
    call print_string
    jmp .after_path
    
.show_current_dir:
    mov si, current_dir
    call print_string
    
.after_path:
    mov si, newline
    call print_string
    mov si, separator_line
    call print_string
    
    
    xor ax, ax
    mov dl, [bootdrive]
    int 0x13
    jc .disk_error
    
    
    mov ax, 0x0201      ; AH = 02 (чтение), AL = 1 (сектор)
    mov cx, 0x0001      ; CH = 0 (цилиндр), CL = 1 (сектор)
    mov dh, 0           ; DH = 0 (головка)
    mov dl, [bootdrive] ; DL = номер диска
    mov bx, buffer      ; ES:BX = адрес буфера
    int 0x13
    jc .disk_error
    
    
    mov si, disk_label
    call print_string
    
    mov si, disk_size
    call print_string
    
    mov si, free_space
    call print_string
    
    mov si, separator_line
    call print_string
    
    ; Выводим файлы (пока заглушка)
    mov si, no_files_msg
    call print_string
    
    mov si, dir_footer
    call print_string
    jmp command_loop
    
.disk_error:
    mov si, dir_error
    call print_string
    jmp command_loop


do_help:
    mov si, help_msg
    call print_string
    jmp command_loop


do_exit:
    mov si, exit_msg
    call print_string
    
    mov ax, 0x5300      
    mov bx, 0
    int 0x15           
    
    mov ax, 0x5301     
    mov bx, 0
    int 0x15           
    
    mov ax, 0x5307      
    mov bx, 0x0001     
    mov cx, 0x0003     
    int 0x15           
    
    cli
    hlt


do_cd:
    
    mov si, cmd_buffer
    call get_argument
    jnc .no_arg

    
    mov si, arg_buffer
    cmp byte [si], '.'  ; Проверяем на "."
    je .current_dir
    
    cmp word [si], '..' ; Проверяем на ".."
    je .parent_dir

    
    call check_directory
    jnc .not_found

    
    mov si, cd_msg
    call print_string
    mov si, arg_buffer
    call print_string
    mov si, newline
    call print_string

    
    mov si, arg_buffer
    mov di, current_dir
    call copy_string

    jmp command_loop

.current_dir:
    
    mov si, cd_current
    call print_string
    jmp command_loop

.parent_dir:
    
    mov si, cd_parent
    call print_string
    mov byte [current_dir], 0  
    jmp command_loop

.not_found:
    mov si, cd_not_found
    call print_string
    jmp command_loop

.no_arg:
    mov si, cd_usage
    call print_string
    jmp command_loop


do_color:
    
    mov si, cmd_buffer
    call get_argument
    jnc .no_arg

    
    mov si, arg_buffer
    lodsb
    sub al, '0'         ; Преобразуем ASCII в число
    cmp al, 7           ; Проверяем, что цвет в диапазоне 0-7
    ja .invalid_color

    
    mov [current_color], al
    mov ah, 0x0B
    mov bh, 0
    mov bl, al
    int 0x10

    ; Выводим сообщение об успехе
    mov si, color_success
    call print_string
    jmp command_loop

.no_arg:
    mov si, color_usage
    call print_string
    jmp command_loop

.invalid_color:
    mov si, color_error
    call print_string
    jmp command_loop


strcmp_command:
    pusha
.loop:
    mov al, [si]
    mov bl, [di]
    
    
    or bl, bl
    jz .check_end
    
    
    cmp al, bl
    jne .not_equal
    
    inc si
    inc di
    jmp .loop

.check_end:
   
    cmp al, ' '
    je .equal
    cmp al, 0
    je .equal
    
.not_equal:
    popa
    clc
    ret
    
.equal:
    popa
    stc
    ret


read_string:
    pusha
.loop:
    mov ah, 0
    int 0x16
    
    cmp al, 0x0D        
    je .done
    
    cmp al, 0x08        
    je .backspace
    
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    
    stosb
    jmp .loop

.backspace:
    cmp di, cmd_buffer  
    je .loop
    
    dec di              
    mov ah, 0x0E
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
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    popa
    ret


strcmp:
    pusha
.loop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .not_equal
    or al, al
    jz .equal
    inc si
    inc di
    jmp .loop
.not_equal:
    popa
    clc
    ret
.equal:
    popa
    stc
    ret


get_argument:
    push si
    
.skip_cmd:
    lodsb
    or al, al
    jz .no_arg
    cmp al, ' '
    jne .skip_cmd
    
    
.skip_spaces:
    lodsb
    or al, al
    jz .no_arg
    cmp al, ' '
    je .skip_spaces
    
    
    dec si          
    mov di, arg_buffer
    
    
.copy_arg:
    lodsb
    or al, al
    jz .done
    stosb
    jmp .copy_arg
    
.done:
    mov al, 0
    stosb
    mov di, arg_buffer
    pop si
    stc             
    ret
    
.no_arg:
    pop si
    clc             
    ret


copy_string:
    pusha
.loop:
    lodsb
    stosb
    or al, al
    jnz .loop
    popa
    ret


create_directory:
    pusha
    
    mov si, debug_reset
    call print_string
    
    xor ax, ax
    mov dl, [bootdrive]
    int 0x13
    jc .error_reset

    
    mov si, debug_reading
    call print_string
    
    mov ax, 0x0201      
    mov cx, 0x0002      
    mov dh, 0           
    mov dl, [bootdrive]
    mov bx, buffer
    int 0x13
    jc .error_read

    
    mov si, debug_creating
    call print_string
    mov si, arg_buffer
    call print_string
    mov si, newline
    call print_string

    
    mov si, debug_buffer
    call print_string
    mov cx, 16          
    mov si, buffer
.show_buffer:
    lodsb
    push ax
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    pop ax
    loop .show_buffer
    mov si, newline
    call print_string

    
    mov cx, 16          
    mov di, buffer
.find_empty:
    cmp byte [di], 0    
    je .found_empty     
    cmp byte [di], 0xE5 
    je .found_empty     
    add di, 32          
    loop .find_empty
    
    mov si, debug_no_space
    call print_string
    jmp .error          

.found_empty:
    mov si, debug_found_space
    call print_string

    
    mov si, arg_buffer
    mov cx, 8
.copy_name:
    lodsb
    or al, al           
    jz .pad_spaces
    stosb
    loop .copy_name
    jmp .extension

.pad_spaces:            
    mov al, ' '
.pad_loop:
    stosb
    loop .pad_loop

.extension:
    
    mov cx, 3
    mov al, ' '
    rep stosb

    
    mov al, 0x10        
    stosb

    
    xor ax, ax
    stosw               
    stosw               
    stosw               
    mov ax, 0          
    stosw
    stosw

    
    mov si, debug_writing
    call print_string
    
    mov ax, 0x0301      
    mov cx, 0x0002      
    mov dh, 0           
    mov dl, [bootdrive]
    mov bx, buffer
    int 0x13
    jc .error_write

    mov si, debug_created
    call print_string
    popa
    stc                 ; Успех
    ret

.error_reset:
    mov si, debug_error_reset
    call print_string
    jmp .error

.error_read:
    mov si, debug_error_read
    call print_string
    jmp .error

.error_write:
    mov si, debug_error_write
    call print_string

.error:
    popa
    clc                 ; Ошибка
    ret

; Данные дополнительных секторов
welcome_msg db 'KojoTortOS Bootloader', 13, 10, 0
prompt db '>', 0
cmd_buffer times 64 db 0
arg_buffer times 64 db 0
cmd_help db 'help', 0
cmd_dir db 'dir', 0
cmd_exit db 'exit', 0
cmd_makedir db 'makedir', 0
cmd_cd db 'cd', 0
cmd_color db 'color', 0
help_msg db 'Available commands:', 13, 10
         db 'help    - Show this help', 13, 10
         db 'dir     - List directory', 13, 10
         db 'makedir - Create directory', 13, 10
         db 'cd      - Change directory', 13, 10
         db 'color   - Change background color (0-7)', 13, 10
         db 'exit    - Shutdown system', 13, 10, 0
unknown_cmd db 'Unknown command', 13, 10, 0
exit_msg db 'System is shutting down...', 13, 10, 0
filespec db '*.*', 0
newline db 13, 10, 0
dir_header db 'Directory listing:', 13, 10
          db '----------------', 13, 10, 0
dir_footer db '----------------', 13, 10
          db 'End of directory listing', 13, 10, 0
dir_error db 'Error reading directory', 13, 10, 0
disk_label db 'Disk label: KOJOTORT-OS', 13, 10, 0
disk_size db 'Total size: 1.44 MB', 13, 10, 0
free_space db 'Free space: 1.44 MB', 13, 10, 0
makedir_usage db 'Usage: makedir <dirname>', 13, 10, 0
makedir_success db 'Directory created successfully', 13, 10, 0
makedir_error db 'Error creating directory', 13, 10, 0
disk_info_msg db 'Checking disk information...', 13, 10, 0
disk_num_msg db 'Boot drive number: ', 0
disk_num db '0', 13, 10, 0
heads_msg db 'Number of heads: ', 0
heads_num db '0', 13, 10, 0
sectors_msg db 'Sectors per track: ', 0
sectors_num db '0', 13, 10, 0
disk_op_error db 'Error accessing disk. ', 0
error_code_msg db 'Error code: ', 0
error_code db '0', 13, 10, 0
creating_msg db 'Attempting to create directory: ', 0
cd_msg db 'Changing directory to: ', 0
cd_usage db 'Usage: cd <directory>', 13, 10, 0
current_dir_msg db 'Directory of ', 0
root_dir_msg db 'ROOT', 0
separator_line db '----------------------------------------', 13, 10, 0
no_files_msg db 'No files found', 13, 10, 0
current_dir times 64 db 0  ; Буфер для текущей директории
welcome_screen db '=======================================', 13, 10
              db '         Welcome to KojoTortOS         ', 13, 10
              db '=======================================', 13, 10
              db '     Press any key to continue...      ', 13, 10, 0
color_usage db 'Usage: color <0-7>', 13, 10
           db '0 - Black', 13, 10
           db '1 - Blue', 13, 10
           db '2 - Green', 13, 10
           db '3 - Cyan', 13, 10
           db '4 - Red', 13, 10
           db '5 - Magenta', 13, 10
           db '6 - Brown', 13, 10
           db '7 - Light Gray', 13, 10, 0
color_error db 'Invalid color. Use numbers 0-7.', 13, 10, 0
color_success db 'Color changed successfully.', 13, 10, 0
current_color db 1  ; Текущий цвет фона (по умолчанию синий)
cd_not_found db 'Directory not found', 13, 10, 0
cd_current db 'Staying in current directory', 13, 10, 0
cd_parent db 'Moving to parent directory', 13, 10, 0
debug_checking db 'Checking directory: ', 0
debug_dir_content db 'Directory content: ', 0
debug_not_found db 'Directory not found in entries', 13, 10, 0
debug_found db 'Directory found!', 13, 10, 0
debug_error db 'Error reading directory', 13, 10, 0
debug_creating db 'Creating directory: ', 0
debug_created db 'Directory created successfully', 13, 10, 0
debug_create_error db 'Error creating directory', 13, 10, 0
debug_reset db 'Resetting disk...', 13, 10, 0
debug_reading db 'Reading root directory...', 13, 10, 0
debug_writing db 'Writing directory entry...', 13, 10, 0
debug_buffer db 'Buffer content: ', 0
debug_no_space db 'No free space in directory', 13, 10, 0
debug_found_space db 'Found free space for entry', 13, 10, 0
debug_error_reset db 'Error resetting disk', 13, 10, 0
debug_error_read db 'Error reading directory', 13, 10, 0
debug_error_write db 'Error writing directory', 13, 10, 0
debug_prepared db 'Prepared name: ', 0
filename_buffer times 11 db 0  ; Буфер для подготовленного имени файла
init_dir db 'Initializing root directory...', 13, 10, 0


dot_entry:
    db '.       '      
    db '   '           
    db 0x10           
    db 0,0,0,0,0,0,0,0,0,0  
    dw 0              
    dw 0              
    dw 0              
    dd 0              


dotdot_entry:
    db '..      '      
    db '   '           
    db 0x10           
    db 0,0,0,0,0,0,0,0,0,0  
    dw 0              
    dw 0              
    dw 0              
    dd 0              


disk_heads db 0
disk_sectors db 0
buffer times 512 db 0
DTA times 128 db 0

times 8192-($-$$) db 0  
