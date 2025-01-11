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

    mov si, cmd_buffer
    mov di, cmd_create
    call strcmp_command
    jc do_create

    mov si, cmd_buffer
    mov di, cmd_view
    call strcmp_command
    jc do_view

    mov si, cmd_buffer
    mov di, cmd_edit
    call strcmp_command
    jc do_edit

    mov si, cmd_buffer
    mov di, cmd_snake
    call strcmp_command
    jc do_snake

    mov si, cmd_buffer
    mov di, cmd_pong
    call strcmp_command
    jc do_pong

    mov si, cmd_buffer
    mov di, cmd_calc
    call strcmp_command
    jc do_calc

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
    or al, al           ; Check for end of string
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
    
    ; Show current directory path
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
    
    ; Initialize file counter
    xor dx, dx          ; DX will store file count
    
    ; Reset disk system first
    xor ax, ax
    mov dl, [bootdrive]
    int 0x13
    jc .disk_error
    
    ; Read the root directory
    mov ax, 0x0201      ; Read one sector
    mov bx, buffer      ; Buffer to read into
    mov cx, 0x0002      ; Cylinder 0, Sector 2
    mov dx, 0x0000      ; Head 0, Drive 0
    int 0x13
    jc .disk_error
    
    ; Now process directory entries
    mov si, buffer      ; Point to directory buffer
    mov cx, 16          ; Maximum entries to display

.next_entry:
    push cx
    mov al, [si]        ; Get first byte of entry
    cmp al, 0          ; Check if entry is empty (0)
    je .check_files    ; If empty, we're done
    cmp al, 0xE5       ; Check if entry is deleted
    je .skip_entry
    
    ; Get file attributes
    push si
    add si, 11         ; Point to attributes
    mov al, [si]
    pop si
    
    ; Skip system, hidden, and directory entries
    test al, 0x16      ; Test for hidden (0x02), system (0x04), or directory (0x10) attributes
    jnz .skip_entry
    
    ; Save starting position
    push si
    
    ; Display filename (8 chars)
    mov cx, 8
.name_loop:
    lodsb
    cmp al, ' '         ; Skip trailing spaces
    je .pad_name
    mov ah, 0x0E        ; BIOS teletype
    mov bh, 0           ; Page 0
    int 0x10            ; Video interrupt
    loop .name_loop
    jmp .print_dot

.pad_name:
    ; Skip remaining spaces in name
    add si, cx          ; Skip remaining characters

.print_dot:
    mov al, '.'         ; Print dot between name and extension
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    
    ; Point to extension (8 bytes after start of name)
    pop si              ; Restore start position
    add si, 8           ; Point to extension
    
    ; Display extension (3 chars)
    mov cx, 3
.ext_loop:
    lodsb
    cmp al, ' '         ; Skip trailing spaces
    je .skip_ext
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    loop .ext_loop

.skip_ext:
    mov al, ' '         ; Print space after extension
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    
    ; Point to file size (20 bytes from start of entry)
    add si, 20 - 11     ; Move to size field (compensate for what we've read)
    mov eax, [si]       ; Get file size
    call print_number   ; Print the size
    mov si, bytes_str
    call print_string
    mov si, newline
    call print_string
    
    inc dx              ; Increment file counter
    
    ; Move to next entry
    pop si              ; Restore entry start
    add si, 32          ; Move to next entry
    pop cx
    dec cx
    jnz .next_entry
    jmp .check_files

.skip_entry:
    add si, 32          ; Skip to next entry
    pop cx
    dec cx
    jnz .next_entry

.disk_error:
    mov si, dir_error
    call print_string
    pop cx              ; Balance stack if needed
    jmp command_loop
    
.check_files:
    test dx, dx         ; Check if we found any files
    jnz .done
    
    ; If no files found, show message
    mov si, no_files_msg
    call print_string
    
.done:
    mov si, dir_footer
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


do_create:
    
    mov si, cmd_buffer
    call get_argument
    jnc .no_arg

    
    mov si, creating_msg
    call print_string
    mov si, arg_buffer
    call print_string
    mov si, newline
    call print_string

    
    call create_file
    jc .error

    mov si, create_success
    call print_string
    jmp command_loop

.error:
    mov si, create_error
    call print_string
    jmp command_loop

.no_arg:
    mov si, syntax_error
    call print_string
    jmp command_loop


do_view:
    push si              ; Save SI
    mov si, cmd_buffer
    call get_argument    ; Get filename argument
    jnc .no_file        ; If no argument found (CF=0)
    
    ; Show view mode instructions
    mov si, view_start_msg
    call print_string
    
    ; Store filename
    mov di, filename_buffer
    mov cx, 11          ; Maximum 8.3 filename
.copy_name:
    mov si, arg_buffer  ; Get argument from arg_buffer
.copy_loop:
    lodsb
    cmp al, 0           ; End of string?
    je .end_name
    cmp al, ' '         ; Space?
    je .end_name
    stosb
    loop .copy_loop
.end_name:
    
    ; Load file contents
    mov ax, 0x0201      ; Read sector
    mov cx, 1           ; Start from sector 1
    mov dx, 0           ; Head 0, Drive [bootdrive]
    mov bx, buffer
    int 0x13
    jc .error
    
    ; Display file contents
    mov si, buffer
    call print_string
    
    ; Wait for any key
    mov ah, 0
    int 0x16
    
    ; Show exit message
    mov si, view_exit_msg
    call print_string
    
    pop si              ; Restore SI
    jmp command_loop    ; Return to command prompt
    
.no_file:
    mov si, no_file_msg
    call print_string
    pop si              ; Restore SI
    ret
    
.error:
    mov si, read_error_msg
    call print_string
    pop si              ; Restore SI
    ret


do_edit:
    push si              ; Save SI
    mov si, cmd_buffer
    call get_argument    ; Get filename argument
    jnc .no_file        ; If no argument found (CF=0)
    
    ; Show edit mode instructions
    mov si, edit_start_msg
    call print_string
    
    ; Store filename
    mov di, filename_buffer
    mov cx, 11          ; Maximum 8.3 filename
.copy_name:
    mov si, arg_buffer  ; Get argument from arg_buffer
.copy_loop:
    lodsb
    cmp al, 0           ; End of string?
    je .end_name
    cmp al, ' '         ; Space?
    je .end_name
    stosb
    loop .copy_loop
.end_name:
    
    ; Setup edit buffer
    mov di, buffer
    mov cx, 512
    mov al, 0
    rep stosb
    
    ; Get user input
    mov di, buffer
.input_loop:
    mov ah, 0
    int 0x16           ; Wait for keypress
    
    cmp al, 27         ; ESC to finish editing and save
    je .save_file
    
    cmp al, 3          ; Ctrl+C to exit without saving
    je .exit_no_save
    
    cmp al, 13         ; Enter key
    je .newline
    
    cmp al, 8          ; Backspace
    je .backspace
    
    mov [di], al
    inc di
    
    mov ah, 0x0E       ; Echo character
    mov bh, 0
    int 0x10
    
    jmp .input_loop

.exit_no_save:
    mov si, edit_exit_msg
    call print_string
    pop si              ; Restore SI
    jmp command_loop    ; Return to command prompt

.backspace:
    cmp di, buffer     ; Check if we're at the start
    je .input_loop
    
    dec di             ; Move cursor back
    mov ah, 0x0E
    mov al, 8          ; Backspace
    int 0x10
    mov al, ' '        ; Space (to clear character)
    int 0x10
    mov al, 8          ; Backspace again
    int 0x10
    jmp .input_loop

.newline:
    mov al, 13
    mov [di], al
    inc di
    mov al, 10
    mov [di], al
    inc di
    
    mov ah, 0x0E
    mov al, 13
    int 0x10
    mov al, 10
    int 0x10
    
    jmp .input_loop

.save_file:
    ; Save to disk
    mov ax, 0x0301      ; Write sector
    mov cx, 1           ; Start from sector 1
    mov dx, 0           ; Head 0, Drive [bootdrive]
    mov bx, buffer
    int 0x13
    jc .error
    
    mov si, save_msg
    call print_string
    mov si, edit_exit_msg
    call print_string
    pop si              ; Restore SI
    jmp command_loop    ; Return to command prompt

.no_file:
    mov si, no_file_msg
    call print_string
    pop si              ; Restore SI
    ret
    
.error:
    mov si, write_error_msg
    call print_string
    pop si              ; Restore SI
    ret


do_snake:
    call clear_screen
    mov si, snake_welcome
    call print_string
    
    mov byte [snake_x], 40    ; Initial snake position
    mov byte [snake_y], 12
    mov byte [snake_dir], 0   ; 0=right, 1=down, 2=left, 3=up
    mov byte [game_over], 0
    mov word [snake_score], 0 ; Initialize score
    
    ; Place initial apple
    call place_new_apple
    
.game_loop:
    call clear_screen        ; Clear screen to remove trails
    
    ; Draw score
    mov ah, 02h         ; Set cursor position
    mov bh, 0
    mov dh, 0           ; Row 0
    mov dl, 0           ; Column 0
    int 10h
    mov si, score_msg
    call print_string
    mov ax, [snake_score]
    call print_number
    
    call draw_snake
    call draw_apple
    
    mov ah, 1           ; Check if key is pressed
    int 0x16
    jz .no_key
    
    mov ah, 0           ; Get key
    int 0x16
    
    cmp al, 'w'
    je .up
    cmp al, 's'
    je .down
    cmp al, 'a'
    je .left
    cmp al, 'd'
    je .right
    cmp al, 'q'
    je .quit
    
.no_key:
    mov ah, 86h         ; Wait function
    mov cx, 0
    mov dx, 30000      ; Increased delay for slower snake movement
    int 15h
    
    mov al, [snake_dir]
    cmp al, 0
    je .move_right
    cmp al, 1
    je .move_down
    cmp al, 2
    je .move_left
    cmp al, 3
    je .move_up
    jmp .game_loop
    
.up:
    mov byte [snake_dir], 3
    jmp .game_loop
.down:
    mov byte [snake_dir], 1
    jmp .game_loop
.left:
    mov byte [snake_dir], 2
    jmp .game_loop
.right:
    mov byte [snake_dir], 0
    jmp .game_loop
    
.move_right:
    inc byte [snake_x]
    jmp .check_collision
.move_left:
    dec byte [snake_x]
    jmp .check_collision
.move_up:
    dec byte [snake_y]
    jmp .check_collision
.move_down:
    inc byte [snake_y]
    
.check_collision:
    mov al, [snake_x]
    cmp al, 80
    jge .game_over
    cmp al, 0
    jl .game_over
    mov al, [snake_y]
    cmp al, 25
    jge .game_over
    cmp al, 0
    jl .game_over
    
    ; Check apple collision
    mov al, [snake_x]
    cmp al, [apple_x]
    jne .continue_game
    mov al, [snake_y]
    cmp al, [apple_y]
    jne .continue_game
    
    ; Ate apple
    inc word [snake_score]
    call place_new_apple
    
.continue_game:
    jmp .game_loop
    
.game_over:
    mov si, snake_game_over
    call print_string
    mov si, final_score_msg
    call print_string
    mov ax, [snake_score]
    call print_number
    mov ah, 0
    int 0x16
    
.quit:
    call clear_screen
    jmp command_loop

do_pong:
    call clear_screen
    mov si, pong_welcome
    call print_string
    
    ; Initialize paddles and ball
    mov byte [left_paddle_y], 10
    mov byte [right_paddle_y], 10
    mov byte [ball_x], 40
    mov byte [ball_y], 12
    mov byte [ball_dx], 1
    mov byte [ball_dy], 1
    mov word [left_score], 0
    mov word [right_score], 0
    
.game_loop:
    call clear_screen
    
    ; Draw scores
    mov ah, 02h
    mov bh, 0
    mov dh, 0
    mov dl, 20
    int 10h
    mov ax, [left_score]
    call print_number
    
    mov ah, 02h
    mov dh, 0
    mov dl, 60
    int 10h
    mov ax, [right_score]
    call print_number
    
    ; Draw paddles
    mov cx, 5           ; Paddle height
    mov dh, [left_paddle_y]
    .draw_left_paddle:
    mov ah, 02h
    mov bh, 0
    mov dl, 0
    int 10h
    mov ah, 0Eh
    mov al, '|'
    int 10h
    inc dh
    loop .draw_left_paddle
    
    mov cx, 5
    mov dh, [right_paddle_y]
    .draw_right_paddle:
    mov ah, 02h
    mov bh, 0
    mov dl, 79
    int 10h
    mov ah, 0Eh
    mov al, '|'
    int 10h
    inc dh
    loop .draw_right_paddle
    
    ; Draw ball
    mov ah, 02h
    mov bh, 0
    mov dh, [ball_y]
    mov dl, [ball_x]
    int 10h
    mov ah, 0Eh
    mov al, 'O'
    int 10h
    
    ; Move ball
    mov al, [ball_x]
    add al, [ball_dx]
    mov [ball_x], al
    
    mov al, [ball_y]
    add al, [ball_dy]
    mov [ball_y], al
    
    ; Check paddle collisions
    mov al, [ball_x]
    cmp al, 1
    jne .check_right_paddle
    mov al, [ball_y]
    mov bl, [left_paddle_y]
    sub al, bl
    cmp al, 5
    jge .left_miss
    neg byte [ball_dx]
    
.check_right_paddle:
    mov al, [ball_x]
    cmp al, 78
    jne .check_walls
    mov al, [ball_y]
    mov bl, [right_paddle_y]
    sub al, bl
    cmp al, 5
    jge .right_miss
    neg byte [ball_dx]
    
.check_walls:
    mov al, [ball_y]
    cmp al, 0
    jle .bounce_y
    cmp al, 24
    jge .bounce_y
    jmp .check_input
    
.bounce_y:
    neg byte [ball_dy]
    
.check_input:
    mov ah, 1
    int 16h
    jz .continue_game
    
    mov ah, 0
    int 16h
    
    cmp al, 'w'
    je .left_up
    cmp al, 's'
    je .left_down
    cmp al, 'i'
    je .right_up
    cmp al, 'k'
    je .right_down
    cmp al, 'q'
    je .quit
    
.left_up:
    mov al, [left_paddle_y]
    cmp al, 0
    jle .continue_game
    dec byte [left_paddle_y]
    jmp .continue_game
    
.left_down:
    mov al, [left_paddle_y]
    cmp al, 19
    jge .continue_game
    inc byte [left_paddle_y]
    jmp .continue_game
    
.right_up:
    mov al, [right_paddle_y]
    cmp al, 0
    jle .continue_game
    dec byte [right_paddle_y]
    jmp .continue_game
    
.right_down:
    mov al, [right_paddle_y]
    cmp al, 19
    jge .continue_game
    inc byte [right_paddle_y]
    
.continue_game:
    mov ah, 86h
    mov cx, 0
    mov dx, 12000      ; Increased delay for slower ball movement
    int 15h
    jmp .game_loop
    
.left_miss:
    inc word [right_score]
    jmp .reset_ball
    
.right_miss:
    inc word [left_score]
    
.reset_ball:
    mov byte [ball_x], 40
    mov byte [ball_y], 12
    mov word [ball_dx], 1
    mov word [ball_dy], 1
    
    mov ax, [right_score]
    cmp ax, 5
    je .game_over
    mov ax, [left_score]
    cmp ax, 5
    je .game_over
    jmp .game_loop
    
.game_over:
    mov si, pong_game_over
    call print_string
    mov ah, 0
    int 16h
    
.quit:
    call clear_screen
    jmp command_loop

draw_snake:
    pusha
    mov ah, 02h         ; Set cursor position
    mov bh, 0           ; Page number
    mov dh, [snake_y]   ; Row
    mov dl, [snake_x]   ; Column
    int 10h
    
    mov ah, 0Eh         ; Teletype output
    mov al, '*'         ; Snake character
    int 10h
    popa
    ret

draw_apple:
    pusha
    mov ah, 02h
    mov bh, 0
    mov dh, [apple_y]
    mov dl, [apple_x]
    int 10h
    
    mov ah, 0Eh
    mov al, '@'         ; Apple character
    int 10h
    popa
    ret

place_new_apple:
    pusha
    ; Get system time for random seed
    mov ah, 0
    int 1Ah
    mov ax, dx
    
    ; X position (0-79)
    mov dx, 0
    mov bx, 80
    div bx
    mov [apple_x], dl
    
    ; Y position (0-24)
    mov dx, 0
    mov bx, 25
    div bx
    mov [apple_y], dl
    
    popa
    ret

strcmp_command:
    pusha
.loop:
    mov al, [si]
    mov bl, [di]
    
    ; Проверяем конец строки
    or bl, bl
    jz .check_end
    
    ; Сравниваем символы
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
    
    dec di              ; Move cursor back
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '        ; Space (to clear character)
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
    or al, al           ; Check for end of string
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
    mov dh, 0           ; Head 0
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
    or al, al           ; Check for end of string
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
    stosw               ; Store zeros
    stosw
    stosw
    mov ax, 0          
    stosw
    stosw

    
    mov si, debug_writing
    call print_string
    
    mov ax, 0x0301      
    mov cx, 0x0002      
    mov dh, 0           ; Head 0
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


; Function to print a byte in hex
print_hex:
    pusha
    mov cx, 2           ; Two digits
    mov bl, al          ; Save number
.digit_loop:
    rol bl, 4           ; Rotate to get high digit
    mov al, bl          ; Copy digit
    and al, 0x0F        ; Mask off high nibble
    add al, '0'         ; Convert to ASCII
    cmp al, '9'         ; Is it a decimal digit?
    jle .print_digit
    add al, 7           ; Convert to A-F
.print_digit:
    mov ah, 0x0E        ; BIOS teletype
    int 0x10
    loop .digit_loop
    popa
    ret

; Function to print a number
print_number:
    pusha
    mov cx, 0           ; Digit counter
    mov ebx, 10         ; Divisor
.divide_loop:
    xor edx, edx        ; Clear upper bits before div
    div ebx             ; Divide by 10
    push dx             ; Save remainder
    inc cx              ; Count digits
    test eax, eax       ; Check if quotient is 0
    jnz .divide_loop
    
.print_loop:
    pop ax              ; Get digit
    add al, '0'         ; Convert to ASCII
    mov ah, 0x0E        ; BIOS teletype
    mov bh, 0           ; Page number
    int 0x10            ; Video interrupt
    loop .print_loop
    popa
    ret

; Function to create a new file
; Input: DS:DX points to ASCIIZ filename
; Output: CF set on error, clear on success
create_file:
    pusha
    
    ; Reset disk first
    xor ax, ax
    mov dl, [bootdrive]
    int 0x13
    jc .error
    
    ; Read root directory
    mov ax, 0x0201      ; Read sector
    mov cx, 0x0002      ; Sector 2
    mov dh, 0           ; Head 0
    mov dl, [bootdrive]
    mov bx, buffer
    int 0x13
    jc .error
    
    ; Find empty directory entry
    mov di, buffer
    mov cx, 16          ; Check 16 entries
.find_empty:
    mov al, [di]
    cmp al, 0          ; Empty entry
    je .found_empty
    cmp al, 0xE5       ; Deleted entry
    je .found_empty
    add di, 32         ; Next entry
    loop .find_empty
    jmp .error         ; No empty slots
    
.found_empty:
    ; Fill in directory entry
    push di            ; Save entry position
    
    ; Clear entry
    mov cx, 32
    mov al, 0
    rep stosb
    
    pop di             ; Restore entry position
    
    ; Copy filename (8 chars max)
    mov si, arg_buffer
    mov cx, 8
.copy_name:
    lodsb
    cmp al, '.'        ; Stop at dot
    je .pad_name
    cmp al, 0          ; Stop at end
    je .pad_name
    stosb
    loop .copy_name
    jmp .find_ext
    
.pad_name:
    mov al, ' '
    rep stosb          ; Pad with spaces
    
.find_ext:
    mov si, arg_buffer
    mov cx, 8          ; Maximum length to search
.find_dot:
    lodsb
    cmp al, '.'
    je .copy_ext
    cmp al, 0
    je .pad_ext
    loop .find_dot
    jmp .pad_ext
    
.copy_ext:
    mov cx, 3          ; 3 chars for extension
.copy_ext_loop:
    lodsb
    cmp al, 0
    je .pad_remaining
    stosb
    loop .copy_ext_loop
    jmp .finish_entry
    
.pad_remaining:
    mov al, ' '
    rep stosb
    jmp .finish_entry
    
.pad_ext:
    mov cx, 3
    mov al, ' '
    rep stosb
    
.finish_entry:
    ; Set attributes and other fields
    mov byte [di], 0x20     ; Archive attribute
    inc di
    xor ax, ax
    mov cx, 19              ; Clear remaining fields
    rep stosb
    mov word [di], 0        ; File size (0 bytes initially)
    
    ; Write directory back to disk
    mov ax, 0x0301          ; Write sector
    mov cx, 0x0002          ; Sector 2
    mov dh, 0               ; Head 0
    mov dl, [bootdrive]
    mov bx, buffer
    int 0x13
    jc .error
    
    popa
    clc                     ; Success
    ret
    
.error:
    popa
    stc                     ; Error
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
cmd_create db 'create', 0
cmd_view db 'view', 0
cmd_edit db 'edit', 0
cmd_snake db 'snake', 0
cmd_pong db 'pong', 0
cmd_calc db 'calc', 0
help_msg db 'Available commands:', 13, 10
         db 'help    - Show this help', 13, 10
         db 'dir     - List directory', 13, 10
         db 'makedir - Create directory', 13, 10
         db 'cd      - Change directory', 13, 10
         db 'view    - View file contents', 13, 10
         db 'edit    - Edit file contents', 13, 10
         db 'color   - Change background color (0-7)', 13, 10
         db 'create  - Create file', 13, 10
         db 'exit    - Shutdown system', 13, 10
         db 'snake   - Play Snake game', 13, 10
         db 'pong    - Play Pong game', 13, 10
         db 'calc    - Calculator', 13, 10, 0
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
creating_msg db 'Creating file: ', 0
create_success db 'File created successfully', 13, 10, 0
create_error db 'Error creating file', 13, 10, 0
syntax_error db 'Syntax error: filename required', 13, 10, 0
cd_msg db 'Changing directory to: ', 0
cd_usage db 'Usage: cd <directory>', 13, 10, 0
current_dir_msg db 'Directory of ', 0
root_dir_msg db 'ROOT', 0
separator_line db '----------------------------------------', 13, 10, 0
dir_attr db ' <DIR>     ', 0
bytes_str db ' bytes', 0
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
filename_buffer times 12 db 0  ; Буфер для подготовленного имени файла
init_dir db 'Initializing root directory...', 13, 10, 0
debug_reading_dir db 'Reading directory...', 13, 10, 0
debug_read_first db 'Reading first sector...', 13, 10, 0
debug_entry db 'Found entry: ', 0
debug_attr db 'Attributes: ', 0
debug_error_code db 'Error code: ', 0
no_file_msg db 'Error: No filename specified', 13, 10, 0
read_error_msg db 'Error: Could not read file', 13, 10, 0
write_error_msg db 'Error: Could not write file', 13, 10, 0
save_msg db 'File saved successfully', 13, 10, 0
edit_start_msg db 'Edit mode. Press ESC to save and exit, Ctrl+C to exit without saving.', 13, 10, 0
edit_exit_msg db 'Exiting edit mode...', 13, 10, 0
view_start_msg db 'View mode. Press any key to exit...', 13, 10, 0
view_exit_msg db 'Exiting view mode...', 13, 10, 0
snake_welcome db 'Snake Game! Use WASD to move, Q to quit', 13, 10, 0
snake_game_over db 'Game Over!', 13, 10, 0
score_msg db 'Score: ', 0
final_score_msg db 'Final Score: ', 0
pong_welcome db 'Pong! Left: W/S, Right: I/K, Q to quit', 13, 10, 0
pong_game_over db 'Game Over! Press any key...', 13, 10, 0
calc_welcome db 'Calculator! Format: number operator number (e.g. 5 + 3)', 13, 10
            db 'Operators: +, -, *, /', 13, 10
            db 'Type exit to quit', 13, 10, 0
calc_prompt db '> ', 0
calc_error db 'Invalid input!', 13, 10, 0
div_zero_error db 'Error: Division by zero!', 13, 10, 0
equals_msg db '= ', 0

; Add game variables
snake_x db 40
snake_y db 12
snake_dir db 0
game_over db 0
snake_score dw 0
apple_x db 0
apple_y db 0

; Pong variables
left_paddle_y db 10
right_paddle_y db 10
ball_x db 40
ball_y db 12
ball_dx db 1
ball_dy db 1
left_score dw 0
right_score dw 0

; Calculator variables
operator db 0

dot_entry:
    db '.       '      ; 8 bytes for name
    db '   '           ; 3 bytes for extension
    db 0x10            ; Directory attribute
    db 0,0,0,0,0,0,0,0,0,0  ; Reserved bytes
    dw 0               ; Creation time
    dw 0               ; Creation date
    dw 0               ; Starting cluster
    dd 0               ; File size

dotdot_entry:
    db '..      '      ; 8 bytes for name
    db '   '           ; 3 bytes for extension
    db 0x10            ; Directory attribute
    db 0,0,0,0,0,0,0,0,0,0  ; Reserved bytes
    dw 0               ; Creation time
    dw 0               ; Creation date
    dw 0               ; Starting cluster
    dd 0               ; File size

disk_heads db 0
disk_sectors db 0
buffer times 512 db 0
DTA times 128 db 0

skip_spaces:
    push ax
.loop:
    lodsb
    cmp al, ' '
    je .loop
    dec si
    pop ax
    ret

clear_screen:
    pusha
    mov ax, 0x0003
    int 0x10
    popa
    ret

do_calc:
    call clear_screen
    mov si, calc_welcome
    call print_string

.calc_loop:
    mov si, calc_prompt
    call print_string
    
    mov di, cmd_buffer
    call read_string
    
    mov si, cmd_buffer
    mov di, cmd_exit
    call strcmp_command
    jc .quit
    
    ; Parse first number
    mov si, cmd_buffer
    call parse_number
    push ax            ; Save first number
    
    ; Find operator
.find_operator:
    lodsb
    cmp al, ' '
    je .find_operator  ; Skip spaces
    cmp al, 0
    je .error         ; End of string - error
    
    ; Check if valid operator
    cmp al, '+'
    je .save_operator
    cmp al, '-'
    je .save_operator
    cmp al, '*'
    je .save_operator
    cmp al, '/'
    je .save_operator
    jmp .error
    
.save_operator:
    mov [operator], al
    
    ; Skip spaces after operator
.skip_spaces_after_op:
    lodsb
    cmp al, ' '
    je .skip_spaces_after_op
    cmp al, 0
    je .error
    
    ; Move back one character since we've read past the spaces
    dec si
    
    ; Parse second number
    call parse_number
    mov bx, ax        ; Second number in BX
    pop ax            ; First number in AX
    
    ; Perform operation
    mov cl, [operator]
    cmp cl, '+'
    je .add
    cmp cl, '-'
    je .subtract
    cmp cl, '*'
    je .multiply
    cmp cl, '/'
    je .divide
    
.error:
    mov si, calc_error
    call print_string
    jmp .calc_loop
    
.add:
    add ax, bx
    jmp .print_result
    
.subtract:
    sub ax, bx
    jmp .print_result
    
.multiply:
    imul bx
    jmp .print_result
    
.divide:
    cmp bx, 0
    je .div_zero
    xor dx, dx
    idiv bx
    jmp .print_result
    
.div_zero:
    mov si, div_zero_error
    call print_string
    jmp .calc_loop
    
.print_result:
    mov si, equals_msg
    call print_string
    call print_number
    mov si, newline
    call print_string
    jmp .calc_loop
    
.quit:
    call clear_screen
    jmp command_loop

parse_number:
    xor ax, ax        ; Clear result
    xor cx, cx        ; Clear sign flag
    
    ; Skip leading spaces
.skip_spaces:
    lodsb
    cmp al, ' '
    je .skip_spaces
    cmp al, 0
    je .return
    
    ; Check for minus sign
    cmp al, '-'
    jne .process_digit
    mov cx, 1         ; Set sign flag
    jmp .next_digit
    
.process_digit:
    ; Convert ASCII to number
    sub al, '0'
    cmp al, 9
    ja .return        ; If not a digit, we're done
    
    ; First digit
    mov ah, 0
    mov bx, ax        ; Save first digit
    
.next_digit:
    lodsb
    cmp al, ' '
    je .finish
    cmp al, 0
    je .finish
    
    ; Convert ASCII to number
    sub al, '0'
    cmp al, 9
    ja .finish        ; If not a digit, we're done
    
    ; Multiply current result by 10
    mov dx, 10
    mov ax, bx
    mul dx
    mov bx, ax
    
    ; Add new digit
    xor ah, ah
    mov al, [si-1]
    sub al, '0'
    add bx, ax
    
    jmp .next_digit
    
.finish:
    dec si           ; Move back one character
    mov ax, bx
    
    ; Apply sign if needed
    test cx, cx
    jz .return
    neg ax
    
.return:
    ret

times 8192-($-$$) db 0
