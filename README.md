# ansi-render

Small Vim plugin to render ANSI-colored log files into a temporary view.

It is designed for plain text files that contain ANSI color markers, either as:

- literal sequences like `\e[0;31m`
- real ANSI escape sequences like `ESC[0;31m`

The plugin opens a rendered scratch buffer in the current window, hides the ANSI markers, and applies colors to the visible text.

## Features

- Toggle rendering with `:RenderToggle`
- Replace the current window content with a rendered scratch buffer
- Hide ANSI markers from the rendered view
- Restore the original buffer on toggle back
- Support foreground colors `30..37`
- Support:
  - `\e[0;3Xm`
  - `\e[1;3Xm`
  - `ESC[0;3Xm`
  - `ESC[1;3Xm`
  - reset with `\e[m`, `\e[0m`, `ESC[m`, `ESC[0m`
- Color persistence across lines
- Color switches without explicit reset
- Simple implementation using Vim built-ins only
- Refresh the rendered view after source-buffer edits or reloads

## Scope

This plugin currently supports only basic ANSI foreground colors.

Not implemented yet:

- background colors `40..47`
- bold / bright distinction
- 256-color ANSI
- truecolor ANSI
- continuous polling for changes made by external processes

## Installation

Use your usual Vim plugin manager:

```vim
Plug 'dpretet/ansi_render'
```

### Usage

Open a log file with ANSI color codes and run the next function
```vim
:RenderToggle
```

Run the same command again from the rendered view to go back to the original buffer.

Test files a present in `test` folder

### Supported ANSI sequences

Foreground colors:
- `30` black
- `31` red
- `32` green
- `33` yellow
- `34` blue
- `35` purple
- `36` cyan
- `37` white

Supported forms:
- literal: `\e[0;31m`, `\e[1;31m`
- real ESC: `ESC[0;31m`, `ESC[1;31m`
- reset: `\e[m`, `\e[0m`, `ESC[m, ESC[0m`

At the moment, `0;31m` and `1;31m` are treated the same.

Notes
- The rendered buffer is a scratch buffer.
- It is read-only and not meant to be edited.
- The plugin targets Vim in terminal `256-color` mode.
- For readability:
    - on dark backgrounds, ANSI black is remapped to gray
    - on light backgrounds, ANSI white is remapped to black
