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

	let s:neotex_buffer_tempname = tempname()
	if get(g:, 'neotex_latexdiff', 0)
		let s:neotex_preview_tempname = tempname()
	else
		let s:neotex_preview_tempname = s:neotex_buffer_tempname
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

let b:neotex_jobexe=''

if get(g:, 'neotex_latexdiff', 0)
	let b:neotex_jobexe .= 'latexdiff '
	if exists('neotex_latexdiff_options')
		let b:neotex_jobexe .= g:neotex_latexdiff_options . ' '
	endif
	let b:neotex_jobexe .= fnameescape(expand('%:t')) . ' ' . s:neotex_buffer_tempname . ' > ' . s:neotex_preview_tempname . ' && '
endif

let s:neotex_pdflatex_cmd = 'pdflatex -shell-escape -jobname=' . fnameescape(expand('%:t:r')) . ' -interaction=nonstopmode '
if exists('neotex_pdflatex_add_options')
	let s:neotex_pdflatex_cmd .= g:neotex_pdflatex_add_options . ' '
endif

let s:neotex_pdflatex_cmd .= s:neotex_preview_tempname
let b:neotex_jobexe .= s:neotex_pdflatex_cmd

if get(g:, 'neotex_bibtex', 0) && filereadable(expand('%:r') . '.bib')
    let b:neotex_jobexe .= ' && bibtex ' . fnameescape(expand('%:t:r')) . ' && ' . s:neotex_pdflatex_cmd . ' && ' . s:neotex_pdflatex_cmd
endif

if get(g:, 'neotex_enabled', 1) == 2
	au! _neotex_ TextChanged,TextChangedI <buffer> call NeoTexUpdate()
endif

if get(g:, 'neotex_enabled', 1) == 2
	au! _neotex_ TextChanged,TextChangedI <buffer> call s:latex_compile_delayed()
endif

function! s:job_exit(...)
    if exists('s:job')
        unlet s:job
    endif
endfunction

function! s:job_log(job_id, data, event)
    if get(g:, 'neotex_log', 0) == 2 && a:event == 'stdout'
        call writefile(a:data, 'neotex.log', 'a')
    elseif get(g:, 'neotex_log', 0) && a:event == 'stderr'
        call writefile(a:data, 'neotex.log', 'a')
    endif
endfunction

function! s:latex_compile(_)
    if exists('s:job')
        call s:latex_compile_delayed()
        return
    endif
    call writefile(getline(1, '$'), s:neotex_buffer_tempname)
    if has('nvim')
        let s:job = jobstart(['bash', '-c', b:neotex_jobexe], {'cwd': expand('%:p:h'), 'on_exit': function('s:job_exit'), 'on_stderr': function('s:job_log'), 'on_stdout': function('s:job_log')})
    else
        let s:job = job_start(['bash', '-c', b:neotex_jobexe], {'cwd': expand('%:p:h'), 'out_io':'null', 'exit_cb': function('s:job_exit')})
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
