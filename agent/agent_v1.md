This is the implementation guide to follow of a small Vim plugin written in Vimscript.

Context:
- The plugin renders plain text files that contain literal ANSI-like markers such as:
  \e[0;31mHello\e[0m
- These markers are not real ESC bytes; they are literal text in the file.
- The goal is to open a rendered scratch buffer in the current window, hide the markers, and color the visible text.
- The plugin is intentionally simple and should use Vim built-ins as much as possible.
- Target environment is Vim in a 256-color terminal only.
- No need to support Neovim, GVim, or advanced portability.
- The command name is :RenderToggle
- The rendered view replaces the current window content.
- Toggling again returns to the original buffer.
- Current implementation relies on:
  - scratch buffer via :enew
  - matchaddpos() for highlights
  - custom highlight groups AnsiBlack..AnsiWhite
  - parsing done in Vimscript, no syntax/ directory
- The plugin currently supports:
  - \e[0;30m .. \e[0;37m
  - reset via \e[0m and \e[m
  - color persistence across lines
  - switching from one color to another without reset
  - cleanup of matches on toggle back
- Current design preference:
  - keep the plugin small
  - prefer readability and built-in Vim facilities
  - avoid overengineering

Important constraints:
- Keep interactions concise.
- Prefer incremental changes.
- Do not redesign the plugin completely unless necessary.
- Preserve the existing RenderToggle behavior.
- Keep comments and explanations in English when editing code.
- Favor terminal readability over strict ANSI fidelity:
  - on dark backgrounds, "black" is mapped to gray
  - on light backgrounds, "white" is mapped to black

Current functions in the plugin:
- ansi_render#RenderToggle()
- ansi_render#OpenRenderedBuffer()
- ansi_render#CloseRenderedBuffer()
- ansi_render#DefineHighlights()
- ansi_render#ParseLines(lines)
- ansi_render#ApplyMatches(matches)

Please first:
1. Briefly summarize your understanding of the current plugin behavior.
2. Ask one clarifying question before proposing changes.
3. Keep the answer short.
