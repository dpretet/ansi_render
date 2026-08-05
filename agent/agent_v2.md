This document is the current implementation and handover guide for a small Vim plugin written in Vimscript.

Overview

- The plugin renders ANSI-colored text logs into a scratch buffer.
- It is designed to be simple, readable, and based mostly on Vim built-ins.
- It targets Vim in a terminal with 256 colors.
- No need to support Neovim, GVim, GUI modes, or extensive portability.
- The command name is :RenderToggle.
- The rendered view replaces the current window content.
- Toggling again from the rendered buffer returns to the original source buffer.


Current behavior

- The plugin reads the current buffer content.
- It parses ANSI markers embedded in the text.
- It opens a scratch buffer with the markers removed from display.
- It applies highlights to the visible text with matchaddpos().
- It stores match IDs buffer-locally and removes them when closing the rendered view.
- Toggle logic is based on the current buffer, not on window state.


Current implementation choices

- Scratch buffer is created with :enew.
- Rendering happens in the current window.
- No syntax/ directory is used.
- Parsing is done manually in Vimscript.
- Highlight groups are custom:
    - AnsiBlack
    - AnsiRed
    - AnsiGreen
    - AnsiYellow
    - AnsiBlue
    - AnsiPurple
    - AnsiCyan
    - AnsiWhite

Supported ANSI input forms

Literal text markers:
- \e[0;30m .. \e[0;37m
- \e[1;30m .. \e[1;37m
- \e[m
- \e[0m

Real ESC-byte markers:
- ESC[0;30m .. ESC[0;37m
- ESC[1;30m .. ESC[1;37m
- ESC[m
- ESC[0m


Notes on semantics

- Only foreground colors 30..37 are currently supported.
- 0;31m and 1;31m are currently treated the same.
- Bold / bright semantics are intentionally ignored for now.
- Background colors 40..47 are not implemented yet.
- Colors persist across lines until a reset is encountered.
- A new color sequence closes the previous active colored segment immediately.

Readability policy

- The plugin favors readability over strict ANSI fidelity.
- On dark backgrounds: ANSI black is mapped to gray for visibility.
- On light backgrounds: ANSI white is mapped to black for visibility.


Important constraints

- Keep interactions concise.
- Prefer incremental changes.
- Do not redesign the plugin completely unless necessary.
- Preserve the current :RenderToggle behavior.
- Keep comments and explanations in English when editing code.
- Keep the code explicit and readable rather than overly clever.


Current public functions

- ansi_render#RenderToggle()
- ansi_render#OpenRenderedBuffer()
- ansi_render#CloseRenderedBuffer()
- ansi_render#DefineHighlights()
- ansi_render#AddSegment(matches, group, lnum, start_col, end_col)
- ansi_render#ParseStartCode(text)
- ansi_render#ParseResetCode(text)
- ansi_render#ParseLines(lines)
- ansi_render#ApplyMatches(matches)

Known stable behavior

- Rendering works on buffers containing literal \e[...] markers.
- Rendering works on buffers containing real ANSI ESC byte sequences.
- Toggle now behaves correctly when:
  - opening a rendered log
  - then opening another file in the same window
  - then rendering that second file
- Toggle also behaves correctly with split windows / panes because it is based on buffer-local state.

Roadmap ideas

1. Bright/bold distinction

- Optionally distinguish 0;31m from 1;31m.
- Possible approaches:
    - add cterm=bold
    - use brighter color indices if desired
    - Keep optional and simple.

2. Background colors

- Add support for ANSI background colors 40..47.
- Start with a minimal implementation only.
- Keep compatibility with current foreground-only logic.

3. Better highlight customization

- Allow user overrides through global variables, for example:
  - g:ansi_render_color_map
  - g:ansi_render_use_theme_links
- Keep defaults simple.

4. Render command ergonomics

- Possibly add a dedicated command to only open render, and another to only close render.
- Keep :RenderToggle as the primary entry point.

5. Packaging cleanup

- Keep the current plugin/ + autoload/ structure.
- Remove dead code and legacy state if any remains.
- Avoid adding a syntax/ directory unless there is a strong reason.

6. Tests / fixtures
- Add a small set of sample logs for manual regression testing:
  - literal \e[...]
  - real ESC-byte logs
  - multiple colors on one line
  - cross-line persistence
  - reset with \e[m
  - reset with \e[0m

Guidance for the next agent Please follow this workflow:

- Briefly summarize your understanding of the current plugin behavior.
- Ask one short clarifying question before proposing changes.
- Keep the answer short unless more detail is requested.
- Prefer minimal patches over rewrites.
- Preserve current behavior unless the user explicitly asks to change it.

If editing code

- Keep code comments in English.
- Keep the code readable and explicit.
- Reuse existing helpers where possible.
- Do not introduce unnecessary abstraction.
- Do not add support for unrelated ANSI features unless requested.

If proposing a next step Good candidates are:
- support 1;3Xm as bold/bright
- add 40..47 background colors
- add user-configurable color overrides
- package cleanup and small regression fixtures
