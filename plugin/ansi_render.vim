if exists('g:loaded_ansi_render')
  finish
endif
let g:loaded_ansi_render = 1

command! RenderToggle call ansi_render#RenderToggle()

augroup ansi_render
  autocmd!
  autocmd BufReadPost * call ansi_render#RefreshRenderedBuffer(bufnr('%'))
  if exists('##FileChangedShellPost')
    autocmd FileChangedShellPost * call ansi_render#RefreshRenderedBuffer(bufnr('%'))
  endif
  if exists('##TextChanged')
    autocmd TextChanged * call ansi_render#RefreshRenderedBuffer(bufnr('%'))
  endif
  if exists('##TextChangedI')
    autocmd TextChangedI * call ansi_render#RefreshRenderedBuffer(bufnr('%'))
  endif
augroup END
