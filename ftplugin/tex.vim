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

    if !get(g:, 'neotex_subfile', 0)
        let s:neotex_tempfile = tempname()
    endif
    if get(g:, 'neotex_latexdiff', 0)
        let s:prediff_tempfile = tempname()
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

    let s:mainfiles = {}
endif

function! s:update_maintemp(mainfile)
    let mainfile = s:mainfiles[a:mainfile]
    let mainbuf = getbufline(a:mainfile, 1, '$')
    if empty(mainbuf)
        let mainbuf = readfile(a:mainfile)
    endif
    let mainbuf = join(mainbuf, "\n")
    for subfile in values(mainfile['subfiles'])
        let mainbuf = substitute(mainbuf, subfile['substitute_from'], subfile['substitute_to'], 'g')
    endfor
    call writefile(split(mainbuf, "\n"), mainfile['tempfile'])
endfunction

if get(g:, 'neotex_subfile', 0)
    " check modelines for pattern
    let lines = join(getline(1,&modelines) + getline(line('$') - (&modelines-1), '$'), "\n")
    let pattern = '\mNeoTex: mainfile=\zs.\{-}\ze:\(\n\|\_$\)'
    let b:neotex_mainfile = matchstr(lines, pattern)
    " if valid modline found it's a subfile
    if exists('b:neotex_mainfile') && !empty(b:neotex_mainfile)
        let b:neotex_is_subfile = 1
        let b:neotex_mainfile = simplify(expand('%:p:h') . '/' . b:neotex_mainfile)
        let b:neotex_tempfile = tempname()
        if has_key(s:mainfiles, b:neotex_mainfile)
            let b:neotex_maintemp = s:mainfiles[b:neotex_mainfile]['tempfile']
        else
            let b:neotex_maintemp = tempname()
            let s:mainfiles[b:neotex_mainfile] =  { 'tempfile': b:neotex_tempfile, 'subfiles': {} }
        endif
        " get subfile path relative to mainfile-directory
        " only works if subfile is in same or subdirectory as mainfile
        let subfile = substitute(expand('%:p'), fnamemodify(b:neotex_mainfile, ':h') . '/', '', '')
        let s:mainfiles[b:neotex_mainfile]['subfiles'][@%] = {
                    \ 'tempfile': b:neotex_tempfile,
                    \ 'substitute_from': '\(\\include\|\\input\){' .  subfile . '}',
                    \ 'substitute_to': '\1{' . b:neotex_tempfile . '}'
                    \ }
        call writefile(getline(1, '$'), b:neotex_tempfile)
        call s:update_maintemp(b:neotex_mainfile)
    else
        let b:neotex_is_subfile = 0
        let b:neotex_mainfile = expand('%:p')
        if has_key(s:mainfiles, b:neotex_mainfile)
            let b:neotex_tempfile = s:mainfiles[b:neotex_mainfile]['tempfile']
        else
            let b:neotex_tempfile = tempname()
            let s:mainfiles[b:neotex_mainfile] =  { 'tempfile': b:neotex_tempfile, 'subfiles': {} }
        endif
        let b:neotex_maintemp = b:neotex_tempfile
    endif
else
    let b:neotex_is_subfile = 0
    let b:neotex_mainfile = expand('%:p')
    let b:neotex_tempfile = s:neotex_tempfile
    let b:neotex_maintemp = b:neotex_tempfile
endif

let b:neotex_compile_cwd = fnamemodify(b:neotex_mainfile, ':h')

let b:neotex_jobexe=''

if get(g:, 'neotex_latexdiff', 0) && !get(g:, 'neotex_subfile', 0)
    let b:neotex_prediff = s:prediff_tempfile
    let b:neotex_jobexe .= 'latexdiff '
    if exists('neotex_latexdiff_options')
        let b:neotex_jobexe .= g:neotex_latexdiff_options . ' '
    endif
    let b:neotex_jobexe .= fnameescape(expand('%:t')) . ' ' . s:prediff_tempfile . ' > ' . b:neotex_tempfile . ' && '
else
    let b:neotex_prediff = b:neotex_tempfile
endif

let b:neotex_jobexe .= get(g:, 'neotex_pdflatex_alternative', 'pdflatex') . ' -shell-escape -jobname='
            \ . fnameescape(fnamemodify(b:neotex_mainfile, ':t:r')) . ' -interaction=nonstopmode '
if exists('neotex_pdflatex_add_options')
    let b:neotex_jobexe .= g:neotex_pdflatex_add_options . ' '
endif

let b:neotex_jobexe .= b:neotex_maintemp


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
    if has_key(s:mainfiles, expand('%:p'))
        call s:update_maintemp(expand('%:p'))
    else
        call writefile(getline(1, '$'), b:neotex_prediff)
    endif
    if has('nvim')
        let s:job = jobstart(['bash', '-c', b:neotex_jobexe],
                    \ {'cwd': b:neotex_compile_cwd,
                    \ 'on_exit': function('s:job_exit'),
                    \ 'on_stderr': function('s:job_log'),
                    \ 'on_stdout': function('s:job_log')})
    else
        let options = {'cwd': b:neotex_compile_cwd,
                    \ 'err_io': 'null',
                    \ 'exit_cb': function('s:job_exit')}
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

function!  NeotexTempname()
    return s:neotex_preview_tempname
endfunction
