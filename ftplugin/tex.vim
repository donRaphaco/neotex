if !get(g:, 'neotex_enabled', 1)
	finish
endif

if !exists('s:neotex_loaded')
	let s:neotex_buffer_tempname = tempname()
	if get(g:, 'neotex_latexdiff', 0)
		let s:neotex_preview_tempname = tempname()
	else
		let s:neotex_preview_tempname = s:neotex_buffer_tempname
	endif

	augroup _neotex_
		au!
	augroup END

	command! NeoTexOn au! _neotex_ TextChanged,TextChangedI <buffer> call NeoTexUpdate()
	command! NeoTexOff au! _neotex_ TextChanged,TextChangedI <buffer>

	call _neotex_init(s:neotex_buffer_tempname)
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

let b:neotex_jobexe .= 'pdflatex -jobname=' . fnameescape(expand('%:t:r')) . ' -interaction=nonstopmode '
if exists('neotex_pdflatex_add_options')
	let b:neotex_jobexe .= g:neotex_pdflatex_add_options . ' '
endif

let b:neotex_jobexe .= s:neotex_preview_tempname

if get(g:, 'neotex_enabled', 1) == 2
	au! _neotex_ TextChanged,TextChangedI <buffer> call NeoTexUpdate()
endif
