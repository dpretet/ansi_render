# Agent Guide: ansi_render

## Purpose

`ansi_render` is a small Vim plugin that renders ANSI-colored log files in a
temporary scratch buffer. It removes supported ANSI markers from the displayed
text and highlights the remaining text.

- Entry point: `:RenderToggle`
- Language: Vimscript
- Target: Vim in a 256-color terminal
- Out of scope: Neovim, GVim, GUI modes, truecolor/256-color ANSI input,
  background colors, and live file synchronization

## Source Of Truth

- `plugin/ansi_render.vim` defines the public `:RenderToggle` command.
- `autoload/ansi_render.vim` contains all implementation and parsing logic.
- `test/` contains sample files for manual regression testing.
- `agent/agent_v1.md` and `agent/agent_v2.md` are historical handover notes;
  do not treat them as current requirements.

Read the implementation before changing behavior. Update this guide when a
supported behavior, important invariant, or verification step changes.

## Current Behavior

`ansi_render#RenderToggle()` toggles based on the current buffer. Opening a
rendered view reads the source lines, parses them, creates a new buffer in the
current window, and applies highlights with `matchaddpos()`. Edits and reloads
of the source buffer refresh the existing rendered buffer. Closing the view
removes its matches, returns to the source buffer when it still exists, and
wipes the temporary buffer.

The rendered buffer is non-file and temporary (`buftype=nofile`,
`bufhidden=wipe`, `noswapfile`), and is made read-only after rendering.

Public functions in `autoload/ansi_render.vim`:

- `ansi_render#RenderToggle()` toggles source and rendered views.
- `ansi_render#OpenRenderedBuffer()` creates and populates a rendered view.
- `ansi_render#CloseRenderedBuffer()` cleans up and returns to the source.
- `ansi_render#DefineHighlights()` defines `AnsiBlack` through `AnsiWhite`.
- `ansi_render#ParseLines(lines)` returns `[rendered_lines, matches]`.
- `ansi_render#ApplyMatches(matches)` applies parsed `matchaddpos()` ranges.
- `ansi_render#RefreshRenderedBuffer(src_bufnr)` reparses a changed source
  buffer and refreshes its rendered view.

View state is buffer-local:

- `b:ansi_render_is_view`
- `b:ansi_render_source_bufnr`
- `b:ansi_render_match_ids`
- Source buffers with an open view also store `b:ansi_render_view_bufnr`.

## Supported Input

Only standard foreground colors `30..37` are supported. The parser accepts:

- Literal markers: `\e[0;30m` through `\e[0;37m` and `\e[1;30m` through
  `\e[1;37m`
- Literal resets: `\e[m` and `\e[0m`
- Real ESC-byte markers: `ESC[0;30m` through `ESC[0;37m` and
  `ESC[1;30m` through `ESC[1;37m`
- Real ESC-byte resets: `ESC[m` and `ESC[0m`

Colors persist across lines until another color marker or reset is seen.
`0;3Xm` and `1;3Xm` currently have identical behavior; bold/bright is not
distinguished.

## Change Guidelines

- Keep patches small, explicit, and readable.
- Prefer Vim built-ins and the existing `plugin/` plus `autoload/` structure.
- Reuse the existing parser and match lifecycle rather than adding a separate
  rendering path.
- Preserve `:RenderToggle`, buffer-local toggle behavior, cleanup of matches,
  and scratch-buffer settings unless the task explicitly changes them.
- Do not add a `syntax/` directory or unrelated ANSI features without a clear
  need.
- Keep code comments and user-facing explanations in English.

Clarify requirements only when the request is genuinely ambiguous. Otherwise,
make the smallest correct change and verify it.

## Readability Policy

The plugin favors terminal readability over strict ANSI fidelity:

- On dark backgrounds, ANSI black maps to gray (`ctermfg=8`).
- On light backgrounds, ANSI white maps to black (`ctermfg=0`).

## Performance Requirement

Rendering `test/text3.txt` must complete in no more than 5 seconds on the
development machine. This fixture is the large regression case (currently
about 52,000 lines and 5.5 MB). Keep the parser linear in the input size and
avoid per-character or per-match operations that scale poorly.

Benchmark the rendering operation separately from Vim startup and file
loading. The command below writes the elapsed render time, rendered line count,
and view-state check to `/tmp/ansi_render_benchmark`:

```sh
vim -Nu NONE -n -es \
  -c "set rtp^=$PWD" \
  -c 'runtime plugin/ansi_render.vim' \
  -c 'edit test/text3.txt' \
  -c 'let s = reltime()' \
  -c 'RenderToggle' \
  -c "call writefile([reltimestr(reltime(s)), string(line('$')), string(get(b:, 'ansi_render_is_view', 0))], '/tmp/ansi_render_benchmark')" \
  -c 'qa!'
```

The benchmark should report a time below `5.0` seconds, `52366` rendered lines,
and view state `1`. Also check the process wall-clock time when diagnosing
interactive startup or file-loading regressions.

## Verification

There is no automated test runner. Manually verify changes in Vim with the
plugin loaded:

1. Open `test/simulation.log`, `test/text1.log`, `test/text2.txt`, or
   `test/text3.txt`.
2. Run `:RenderToggle` and confirm markers are hidden and colors are visible.
3. Run `:RenderToggle` again and confirm the original buffer is restored.
4. For parser or lifecycle changes, also check splits, rendering a second file
   in the same window, editing and reloading the source while rendered, color
   persistence across lines, and both reset forms.
