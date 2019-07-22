alias itm="rm -f vim.itm.dis;ln -nsf merlin_htt.log vim.itm.log;find *.dis|xargs -I {} sh -c 'cat {} >> vim.itm.dis';gvim +\"source vim-itm.vim\""
