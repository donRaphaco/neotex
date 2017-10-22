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

let b:neotex_jobexe = ''

if get(g:, 'neotex_latexdiff', 0)
	let b:neotex_jobexe = 'latexdiff '
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
