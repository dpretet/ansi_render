" Toggle the rendered view for the current buffer.
"
" If the current buffer is already a rendered view, close it and return
" to the source buffer. Otherwise, parse the source buffer and open a
" new rendered view.
function! ansi_render#RenderToggle() abort
  if get(b:, 'ansi_render_is_view', 0)
    call ansi_render#CloseRenderedBuffer()
  else
    call ansi_render#OpenRenderedBuffer()
  endif
endfunction

" Create a temporary rendered buffer from the current source buffer.
"
" The source lines are parsed to remove ANSI escape sequences and to
" collect the color ranges that must later be highlighted. The rendered
" buffer is configured as a read-only, non-file buffer and keeps a
" reference to its source buffer.
function! ansi_render#OpenRenderedBuffer() abort
  let l:src_bufnr = bufnr('%')
  let l:src_name = bufname('%')
  let l:src_lines = getline(1, '$')

  let [l:rendered_lines, l:matches] = ansi_render#ParseLines(l:src_lines)

  enew
  let l:render_bufnr = bufnr('%')

  " Configure the new buffer as a temporary scratch buffer.
  setlocal buftype=nofile
  setlocal bufhidden=wipe
  setlocal noswapfile
  setlocal modifiable
  setlocal nowrap

  call setline(1, l:rendered_lines)

  " Store the relationship between the rendered buffer and its source.
  let b:ansi_render_is_view = 1
  let b:ansi_render_source_bufnr = l:src_bufnr

  " Give the rendered buffer a descriptive name based on the source name.
  execute 'file ' . fnameescape('[Rendered] ' . l:src_name)

  " Define the highlight groups and apply the ranges identified by the parser.
  call ansi_render#DefineHighlights()
  call clearmatches()
  call ansi_render#ApplyMatches(l:matches)

  " Prevent accidental modifications to the rendered view.
  setlocal nomodifiable
  setlocal readonly
endfunction

" Close the current rendered buffer and return to its source buffer.
"
" All highlight matches created for the rendered view are removed first.
" If the source buffer still exists, it becomes the current buffer and the
" rendered buffer is wiped out. Otherwise, the rendered buffer itself is
" simply closed.
function! ansi_render#CloseRenderedBuffer() abort
  let l:view_bufnr = bufnr('%')
  let l:src_bufnr = get(b:, 'ansi_render_source_bufnr', -1)

  " Delete the matches created for this rendered buffer.
  if exists('b:ansi_render_match_ids')
    for l:id in b:ansi_render_match_ids
      silent! call matchdelete(l:id)
    endfor
    unlet! b:ansi_render_match_ids
  endif

  " Return to the source buffer when it is still available.
  if l:src_bufnr != -1 && bufexists(l:src_bufnr)
    execute 'buffer ' . l:src_bufnr
    if bufexists(l:view_bufnr)
      execute 'bwipeout ' . l:view_bufnr
    endif
  else
    " If the source buffer no longer exists, close the rendered buffer.
    bwipeout
  endif
endfunction

" Define the terminal color highlight groups used by the renderer.
"
" The black and white colors are adjusted according to the background
" setting so that they remain visible in both light and dark color schemes.
" The other groups map directly to the standard ANSI foreground colors.
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

" Parse source lines and extract both rendered text and highlight ranges.
"
" ANSI color sequences are removed from the output text. For each supported
" color sequence, the function records the corresponding line, column and
" length so that the color can later be applied with matchaddpos().
"
" The parser supports:
" - literal "\e" escape notation;
" - real ESC bytes;
" - standard foreground colors 30 through 37;
" - optional reset prefixes 0; and 1;;
" - reset sequences "\e[m", "\e[0m", ESC[m and ESC[0m.
"
" The active color is preserved between lines until another color sequence
" or a reset sequence is encountered.
function! ansi_render#ParseLines(lines) abort
  let l:out = []
  let l:matches = []

  " Map ANSI foreground color codes to Vim highlight groups.
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

  " A color sequence may start with either a literal "\e" or a real ESC byte.
  let l:prefix_pat = '^\%(\\e\|\%x1b\)\['
  let l:current_group = ''

  for lnum in range(0, len(a:lines) - 1)
    let l:line = a:lines[lnum]
    let l:newline = ''
    let l:segment_start = 0
    let l:i = 0

    " If a color is active from a previous line, the new colored segment
    " starts at the first character of the current output line.
    if l:current_group != ''
      let l:segment_start = 1
    endif

    " Process the line one character or ANSI sequence at a time.
    while l:i < strlen(l:line)
      let l:rest = strpart(l:line, l:i)

      " Handle color start sequences:
      "
      "   \e[0;31m
      "   \e[1;31m
      "   ESC[0;31m
      "   ESC[1;31m
      if l:rest =~# l:prefix_pat
        if l:rest =~# '^\\e\[\%(0;\|1;\)3[0-7]m'
          let l:full = matchstr(l:rest, '^\\e\[\%(0;\|1;\)3[0-7]m')
          let l:code = strpart(l:full, strlen(l:full) - 3, 2)
          let l:match_len = strlen(l:full)

          " Close the previous colored segment before starting the new one.
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

          " Close the previous colored segment before starting the new one.
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

        " Handle reset sequences:
        "
        "   \e[m
        "   \e[0m
        "   ESC[m
        "   ESC[0m
        if l:rest =~# '^\\e\[\%(0\)\?m'
          let l:match_len = strlen(matchstr(l:rest, '^\\e\[\%(0\)\?m'))

          " Close the current colored segment before resetting the color.
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

          " Close the current colored segment before resetting the color.
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

      " Copy ordinary characters to the rendered line.
      let l:newline .= strpart(l:line, l:i, 1)
      let l:i += 1
    endwhile

    " Close any colored segment that continues until the end of the line.
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

" Apply all parsed highlight ranges to the current rendered buffer.
"
" Each match contains a highlight group and a position represented by
" line number, starting column and character length. The returned match
" IDs are stored locally in the buffer so they can be removed when the
" rendered view is closed.
function! ansi_render#ApplyMatches(matches) abort
  let b:ansi_render_match_ids = []

  for l:m in a:matches
    let l:id = matchaddpos(l:m.group, [[l:m.lnum, l:m.col, l:m.len]])
    call add(b:ansi_render_match_ids, l:id)
  endfor
endfunctionndfunction
