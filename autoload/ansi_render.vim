function! ansi_render#RenderToggle() abort
  if get(b:, 'ansi_render_is_view', 0)
    call ansi_render#CloseRenderedBuffer()
  else
    call ansi_render#OpenRenderedBuffer()
  endif
endfunction

function! ansi_render#OpenRenderedBuffer() abort
  let l:src_bufnr = bufnr('%')
  let l:src_name = bufname('%')
  let l:src_lines = getline(1, '$')

  let [l:rendered_lines, l:matches] = ansi_render#ParseLines(l:src_lines)

  enew
  let l:render_bufnr = bufnr('%')

  setlocal buftype=nofile
  setlocal bufhidden=wipe
  setlocal noswapfile
  setlocal modifiable
  setlocal nowrap

  call setline(1, l:rendered_lines)

  let b:ansi_render_is_view = 1
  let b:ansi_render_source_bufnr = l:src_bufnr

  execute 'file ' . fnameescape('[Rendered] ' . l:src_name)

  call ansi_render#DefineHighlights()
  call clearmatches()
  call ansi_render#ApplyMatches(l:matches)

  setlocal nomodifiable
  setlocal readonly
endfunction

function! ansi_render#CloseRenderedBuffer() abort
  let l:view_bufnr = bufnr('%')
  let l:src_bufnr = get(b:, 'ansi_render_source_bufnr', -1)

  if exists('b:ansi_render_match_ids')
    for l:id in b:ansi_render_match_ids
      silent! call matchdelete(l:id)
    endfor
    unlet! b:ansi_render_match_ids
  endif

  if l:src_bufnr != -1 && bufexists(l:src_bufnr)
    execute 'buffer ' . l:src_bufnr
    if bufexists(l:view_bufnr)
      execute 'bwipeout ' . l:view_bufnr
    endif
  else
    bwipeout
  endif
endfunction

function! ansi_render#DefineHighlights() abort
  if &background ==# 'light'
    highlight AnsiBlack  ctermfg=0
    highlight AnsiWhite  ctermfg=0
  else
    highlight AnsiBlack  ctermfg=8
    highlight AnsiWhite  ctermfg=7
  endif

  highlight AnsiRed    ctermfg=1
  highlight AnsiGreen  ctermfg=2
  highlight AnsiYellow ctermfg=3
  highlight AnsiBlue   ctermfg=4
  highlight AnsiPurple ctermfg=5
  highlight AnsiCyan   ctermfg=6
endfunction

function! ansi_render#ParseLines(lines) abort
  let l:out = []
  let l:matches = []

  let l:color_map = {
        \ '30': 'AnsiBlack',
        \ '31': 'AnsiRed',
        \ '32': 'AnsiGreen',
        \ '33': 'AnsiYellow',
        \ '34': 'AnsiBlue',
        \ '35': 'AnsiPurple',
        \ '36': 'AnsiCyan',
        \ '37': 'AnsiWhite',
        \ }

  " Prefix can be either:
  " - literal "\e"
  " - real ESC byte
  let l:prefix_pat = '^\%(\\e\|\%x1b\)\['
  let l:current_group = ''

  for lnum in range(0, len(a:lines) - 1)
    let l:line = a:lines[lnum]
    let l:newline = ''
    let l:segment_start = 0
    let l:i = 0

    if l:current_group != ''
      let l:segment_start = 1
    endif

    while l:i < strlen(l:line)
      let l:rest = strpart(l:line, l:i)

      " Handle color start:
      "   \e[0;31m
      "   \e[1;31m
      "   ESC[0;31m
      "   ESC[1;31m
      if l:rest =~# l:prefix_pat
        if l:rest =~# '^\\e\[\%(0;\|1;\)3[0-7]m'
          let l:full = matchstr(l:rest, '^\\e\[\%(0;\|1;\)3[0-7]m')
          let l:code = strpart(l:full, strlen(l:full) - 3, 2)
          let l:match_len = strlen(l:full)

          if l:current_group != '' && l:segment_start > 0
            let l:segment_len = strlen(l:newline) - l:segment_start + 1
            if l:segment_len > 0
              call add(l:matches, {
                    \ 'group': l:current_group,
                    \ 'lnum': lnum + 1,
                    \ 'col': l:segment_start,
                    \ 'len': l:segment_len,
                    \ })
            endif
          endif

          let l:current_group = get(l:color_map, l:code, '')
          let l:i += l:match_len
          let l:segment_start = strlen(l:newline) + 1
          continue
        endif

        if l:rest =~# '^\%x1b\[\%(0;\|1;\)3[0-7]m'
          let l:full = matchstr(l:rest, '^\%x1b\[\%(0;\|1;\)3[0-7]m')
          let l:code = strpart(l:full, strlen(l:full) - 3, 2)
          let l:match_len = strlen(l:full)

          if l:current_group != '' && l:segment_start > 0
            let l:segment_len = strlen(l:newline) - l:segment_start + 1
            if l:segment_len > 0
              call add(l:matches, {
                    \ 'group': l:current_group,
                    \ 'lnum': lnum + 1,
                    \ 'col': l:segment_start,
                    \ 'len': l:segment_len,
                    \ })
            endif
          endif

          let l:current_group = get(l:color_map, l:code, '')
          let l:i += l:match_len
          let l:segment_start = strlen(l:newline) + 1
          continue
        endif

        " Handle reset:
        "   \e[m
        "   \e[0m
        "   ESC[m
        "   ESC[0m
        if l:rest =~# '^\\e\[\%(0\)\?m'
          let l:match_len = strlen(matchstr(l:rest, '^\\e\[\%(0\)\?m'))

          if l:current_group != '' && l:segment_start > 0
            let l:segment_len = strlen(l:newline) - l:segment_start + 1
            if l:segment_len > 0
              call add(l:matches, {
                    \ 'group': l:current_group,
                    \ 'lnum': lnum + 1,
                    \ 'col': l:segment_start,
                    \ 'len': l:segment_len,
                    \ })
            endif
          endif

          let l:current_group = ''
          let l:segment_start = 0
          let l:i += l:match_len
          continue
        endif

        if l:rest =~# '^\%x1b\[\%(0\)\?m'
          let l:match_len = strlen(matchstr(l:rest, '^\%x1b\[\%(0\)\?m'))

          if l:current_group != '' && l:segment_start > 0
            let l:segment_len = strlen(l:newline) - l:segment_start + 1
            if l:segment_len > 0
              call add(l:matches, {
                    \ 'group': l:current_group,
                    \ 'lnum': lnum + 1,
                    \ 'col': l:segment_start,
                    \ 'len': l:segment_len,
                    \ })
            endif
          endif

          let l:current_group = ''
          let l:segment_start = 0
          let l:i += l:match_len
          continue
        endif
      endif

      let l:newline .= strpart(l:line, l:i, 1)
      let l:i += 1
    endwhile

    if l:current_group != '' && l:segment_start > 0
      let l:segment_len = strlen(l:newline) - l:segment_start + 1
      if l:segment_len > 0
        call add(l:matches, {
              \ 'group': l:current_group,
              \ 'lnum': lnum + 1,
              \ 'col': l:segment_start,
              \ 'len': l:segment_len,
              \ })
      endif
    endif

    call add(l:out, l:newline)
  endfor

  return [l:out, l:matches]
endfunction

function! ansi_render#ApplyMatches(matches) abort
  let b:ansi_render_match_ids = []

  for l:m in a:matches
    let l:id = matchaddpos(l:m.group, [[l:m.lnum, l:m.col, l:m.len]])
    call add(b:ansi_render_match_ids, l:id)
  endfor
endfunction
