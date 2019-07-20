function MerlinItmStart()
    if argc() == 1 && argv(0) == "itm!"
        execute "e .itm.log"
        execute "normal \<C-w>s"
        execute "e .itm.dis"
        wincmd j

        call MerlinItmStep()

        map s :call MerlinItmStep()<cr>
        map q :qa<cr>
    endif
endfunction

function MerlinItmStep()
    highlight CursorLine ctermbg=grey
    set cursorline
    call search("] 0x", "W")
    normal zz
    redraw
    let space = ' '
    let adr = getline('.')[28:35]
    if adr[0] == '0'
        let adr = adr[1:]
    else
        let space = ''
    endif
    if adr[0] == '0'
        let adr = adr[1:]
    endif
    if adr[0] == '0'
        let adr = adr[1:]
    endif
    if adr[0] == '0'
        let adr = adr[1:]
    endif
    if adr[0] == '0'
        let adr = adr[1:]
    endif
    if adr[0] == '0'
        let adr = adr[1:]
    endif
    if adr[0] == '0'
        let adr = adr[1:]
    endif
    wincmd k
    set cursorline
    call search(space . adr . ":")
    normal zz
    redraw
    wincmd j
endfunction

map <C-I> :call MerlinItmStart()<cr>

"au BufNewFile : call MerlinItmStart()
autocmd VimEnter * call MerlinItmStart()
