# Rendering Optimization Checkpoint

## Current Behavior

`ansi_render` reads the complete source buffer, removes supported ANSI
foreground-color sequences, creates a rendered scratch buffer, and applies
highlight ranges with `matchaddpos()`.

The reported problem is slow rendering for large logs, especially files with
50,000 or more lines.

## Change Made

`ansi_render#ApplyMatches()` was changed to group ranges by highlight group.
Previously, it called `matchaddpos()` once for every colored segment. It now
calls `matchaddpos()` once for each group and passes all positions for that
group in one call.

This preserves the existing behavior and keeps the same match IDs available
for cleanup when the rendered buffer is closed.

## Result

There was initially no noticeable improvement on a 50k+ line log. The likely
reason was that match creation was not the dominant cost for that workload.

The parser optimization described below subsequently brought rendering of a
50k+ line log below the target of 3 seconds.

## Main Bottleneck

`ansi_render#ParseLines()` currently does the following for each character:

- calls `strlen()` in the loop condition;
- creates a new remainder with `strpart()`;
- tests several regular expressions;
- appends one character to the output string.

This is especially expensive for long lines and for large files containing
mostly ordinary text. Repeated string slicing and concatenation can also make
long-line processing approach quadratic behavior.

## Parser Update

The parser was updated to scan for the next complete supported ANSI sequence
with `matchstrpos()` and copy ordinary text in chunks. Lines without ANSI
sequences now use a fast path that copies the entire line directly.

The existing cross-line color state and match range format were retained.

Verification passed for literal escapes, real ESC bytes, reset sequences, and
colors spanning multiple lines. A synthetic 50,000-line plain input parsed in
approximately 0.57 seconds in the test Vim environment. The reported result
for a real 50k+ line log is under 3 seconds.

## Further Improvements

### 1. Benchmark representative logs

Measure parsing, buffer population, and match application separately with
Vim's `reltime()` on both mostly plain and ANSI-dense logs.

### 2. Keep match grouping

The `ApplyMatches()` grouping change should remain. It reduces Vim API calls
when a file contains many colored segments, even though it is not sufficient by
itself for large files.

### 3. Consider viewport or incremental rendering

For extremely large files, rendering the entire buffer can still be slow even
with a faster parser. A later design could render only the visible range and
update on scrolling, or render in chunks. This is a larger behavioral change
and should only be considered after parser optimization.

## Compatibility Requirements

The implementation must continue to support:

- literal `\\e` and real ESC bytes;
- foreground colors `30` through `37`;
- prefixes `0;` and `1;`;
- reset sequences `\\e[m`, `\\e[0m`, ESC[m, and ESC[0m;
- color state continuing across line boundaries;
- read-only, non-file rendered buffers;
- buffer-local toggle behavior.

## Verification Plan

There is no automated test runner. After parser changes, verify with the sample
files in `test/`, then test:

- a large mostly plain log;
- a large log with frequent color changes;
- colors spanning multiple lines;
- reset sequences;
- multiple splits and repeated toggling.

Use Vim's `reltime()` around parsing and match application to compare the old
and new implementations separately.
