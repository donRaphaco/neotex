if !get(g:, 'neotex_enabled', 1)
	finish
endif

if !exists('s:neotex_loaded')
    if !has('timers')
        echohl Error | NeoTex requires timers support | echohl None
    endif
    if !has('nvim') && !has('job')
        echohl Error | NeoTex requires neovim or vim 8 with job support | echohl None
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

let b:neotex_jobexe .= 'pdflatex -shell-escape -jobname=' . fnameescape(expand('%:t:r')) . ' -interaction=nonstopmode '
if exists('neotex_pdflatex_add_options')
	let b:neotex_jobexe .= g:neotex_pdflatex_add_options . ' '
endif

let b:neotex_jobexe .= s:neotex_preview_tempname

if get(g:, 'neotex_enabled', 1) == 2
	au! _neotex_ TextChanged,TextChangedI <buffer> call s:latex_compile_delayed()
endif


function! s:latex_compile(_)
    call writefile(getline(1, '$'), s:neotex_buffer_tempname)
    if has('nvim')
        call jobstart(['bash', '-c', b:neotex_jobexe], {'cwd': expand('%:p:h')})
    else
        call job_start(['bash', '-c', b:neotex_jobexe], {'cwd': expand('%:p:h'), 'out_io':'null'})
    endif
    if exists(s:timer)
        unlet s:timer
    endif
endfunction

function! s:latex_compile_delayed()
    if exists('s:timer')
        call timer_stop(s:timer)
    endif
    let s:timer = timer_start(g:neotex_delay, function('s:latex_compile'))
endfunction
