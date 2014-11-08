" local vimrc for a BuildKit project
let $SRCROOT = expand("<sfile>:h")

augroup BuildKit-mindbender
au!

" .module.* involves mostly local stuff
au BufEnter .module.* try | lcd %:h | catch /.*/ | endtry

" It's good to save everything before we do :make
setlocal autowrite

" easy builds with Command-Return (Mac) or F5
let $MAKEARGS = ""
for key in ["<D-CR>", "<F5>"]
    exec "nmap <buffer> ".key.' :setl makeprg=make<CR>:wa<CR>:sleep 1<CR>:make -C "$SRCROOT" polish $MAKEARGS<CR>'
    exec "imap <buffer> ".key." <C-\><C-N>".key."<CR>gi"
    exec "vmap <buffer> ".key." <C-\><C-N>".key."<CR>gv"
endfor


augroup END
