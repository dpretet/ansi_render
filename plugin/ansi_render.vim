if exists('g:loaded_ansi_render')
  finish
endif
let g:loaded_ansi_render = 1

command! RenderToggle call ansi_render#RenderToggle()
