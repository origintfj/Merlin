function ItmInit()
    colorscheme blue
    highlight CursorLine ctermbg=black
    highlight CursorLine ctermfg=white
    highlight CursorLine guibg=Orange
    highlight CursorLine guifg=Black
    set guifont=Courier\ 10\ Pitch\ 9

    set cursorline
    "set background=dark
    "set foreground=green

    execute "view vim.itm.log"
    set nowrap
    execute "normal \<C-w>s"
    execute "view vim.itm.dis"
    "set filetype=asm
    "set filetype=retdecdsm
    wincmd j

    call ItmResize()

    call ItmResolve()

    map q :qa!<cr>
    map u :view<cr>
endfunction

function ItmResize()
    "execute "set cmdheight=2"
    execute "resize 11"
endfunction

function ItmResolve()
    " center the active line
    normal zz
    redraw

    " get the address from the current line in the itm log
    let adr = getline('.')
    let adr = matchstr(adr, "0x[0-9a-fA-F][0-9a-fA-F]*")
    let hex_addr = adr
    let adr = matchstr(adr, "[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]*")
    let adr = substitute(adr, '0*', '', '')
    if adr == ""
        let adr = "0"
    endif

    " switch to the top window
    wincmd k

    " jump to the relevant line of assembly
    call search("^ [ ]*" . adr . ":")

    " reverse search to find the function name and extract it to 'func'
    call search("^[0-9a-fA-F][0-9a-fA-F]*[ ]*\<.*\>", "b")
    let func = getline('.')
    let func = matchstr(func, "\<.*\>")

    " jump to the relevant line of assembly again
    call search("^ [ ]*" . adr . ":")

    " center the active line
    normal zz
    redraw

    " return to the bottom window
    wincmd j

    " print it at the bottom of the vim window
    echo "At address: " . hex_addr . " | Function: " . func
endfunction

"map <C-I> :call ItmInit()<cr>

autocmd VimEnter * call ItmInit()
autocmd CursorMoved * call ItmResolve()
autocmd VimResized * call ItmResize()
"autocmd FileChangedShell * :view vim.itm.dis<cr>
"autocmd VimResized * :resize 11<cr>
