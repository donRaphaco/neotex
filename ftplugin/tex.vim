if !get(g:, 'neotex_enabled', 1)
    finish
endif

if !exists('s:neotex_loaded')
    if !has('timers')
        echohl Error | echomsg 'NeoTex requires timers support' | echohl None
    endif
    if !has('nvim') && !has('job')
        echohl Error | echomsg 'NeoTex requires neovim or vim 8 with job support' | echohl None
    endif

    let s:buffer_tempname = tempname()
    if get(g:, 'neotex_latexdiff', 0)
        let s:diff_tempname = tempname()
    else
        let s:diff_tempname = s:buffer_tempname
    endif

    if !exists('g:neotex_delay')
        let g:neotex_delay = 1000
    endif

    augroup _neotex_
        au!
    augroup END

    command! NeoTexOn au! _neotex_ TextChanged,TextChangedI <buffer> call s:latex_compile_delayed()
    command! NeoTexOff au! _neotex_ TextChanged,TextChangedI <buffer>
    command! NeoTex call s:latex_compile(0)

    let s:neotex_loaded = 1
endif

if get(g:, 'neotex_subfile', 1)
    " check modelines for pattern
    let lines = join(getline(1,&modelines) + getline(line('$') - (&modelines-1), '$'), "\n")
    let pattern = '\mNeoTex: mainfile=\zs.\{-}\ze\(\n\|\_$\)'
    let b:neotex_compile_filename = matchstr(lines, pattern)
endif
if exists('b:neotex_compile_filename') && !empty(b:neotex_compile_filename)
    let b:neotex_is_subfile = 1
    let b:neotex_compile_filename = simplify(expand('%:p:h') . '/' . b:neotex_compile_filename)
    let b:neotex_compile_tempname = tempname()
else
    let b:neotex_compile_filename = expand('%:p')
    let b:neotex_compile_tempname = s:diff_tempname
endif
let b:neotex_compile_cwd = fnamemodify(b:neotex_compile_filename, ':h')

let b:neotex_jobexe=''

if get(b:, 'neotex_is_subfile', 0)
    " get subfile path relative to mainfile-directory and escape directory slashes for sed
    " only works if subfile is in same or subdirectory as mainfile
    let sed_subfile = substitute(
                \ substitute(expand('%:p'), b:neotex_compile_cwd . '/', '', ''),
                \ '/', '\\/', 'g')
    let sed_tempfile = substitute(s:diff_tempname, '/', '\\/', 'g')
    let b:neotex_jobexe .= 'sed "s/\(\\include\|\\input\){' . sed_subfile . '}'
                \ . '/\1{' . sed_tempfile . '}/g" ' . b:neotex_compile_filename . ' > ' . b:neotex_compile_tempname . ' && '
endif

if get(g:, 'neotex_latexdiff', 0)
    let b:neotex_jobexe .= 'latexdiff '
    if exists('neotex_latexdiff_options')
        let b:neotex_jobexe .= g:neotex_latexdiff_options . ' '
    endif
    let b:neotex_jobexe .= fnameescape(expand('%:t')) . ' ' . s:buffer_tempname . ' > ' . s:diff_tempname . ' && '
endif

let b:neotex_jobexe .= get(g:, 'neotex_pdflatex_alternative', 'pdflatex') . ' -shell-escape -jobname='
            \ . fnameescape(fnamemodify(b:neotex_compile_filename, ':t:r')) . ' -interaction=nonstopmode '
if exists('neotex_pdflatex_add_options')
    let b:neotex_jobexe .= g:neotex_pdflatex_add_options . ' '
endif

let b:neotex_jobexe .= b:neotex_compile_tempname


if get(g:, 'neotex_enabled', 1) == 2
    au! _neotex_ TextChanged,TextChangedI <buffer> call s:latex_compile_delayed()
endif


function! s:job_exit(...)
    if exists('s:job')
        unlet s:job
    endif
endfunction

function! s:job_log(job_id, data, event)
    if get(g:, 'neotex_log', 0)
                \ && (a:event == 'stderr' || g:neotex_log == 2)
        call writefile(a:data, 'neotex.log', 'a')
    endif
endfunction

function! s:latex_compile(_)
    if exists('s:job')
        call s:latex_compile_delayed()
        return
    endif
    call writefile(getline(1, '$'), s:buffer_tempname)
    if has('nvim')
        let s:job = jobstart(['bash', '-c', b:neotex_jobexe],
                    \ {'cwd': b:neotex_compile_cwd,
                    \ 'on_exit': function('s:job_exit'),
                    \ 'on_stderr': function('s:job_log'),
                    \ 'on_stdout': function('s:job_log')})
    else
        let options = { 'cwd': b:neotex_compile_cwd, 'err_io': 'null', 'exit_cb': function('s:job_exit') }
        if get(g:, 'neotex_log', 0)
            let options.err_io = 'file'
            let options.err_name = 'neotex.log'
            if g:neotex_log == 2
                let options.out_io = 'file'
                let options.out_name = 'neotex.log'
            endif
        endif
        let s:job = job_start(['bash', '-c', b:neotex_jobexe], options)
    endif
    if exists('s:timer')
        unlet s:timer
    endif
endfunction

function! s:latex_compile_delayed()
    if exists('s:timer')
        call timer_stop(s:timer)
    endif
    let s:timer = timer_start(g:neotex_delay, function('s:latex_compile'))
endfunction
