/**
 * Width-aware line composition.
 *
 * The key correctness concern here is terminal escape state. OSC 8 hyperlinks
 * and ANSI SGR runs are invisible to `visibleWidth` but very visible to the
 * terminal — truncating inside one leaves the terminal in a bad state that
 * can bleed into surrounding text. To keep behaviour safe:
 *
 *   - When the full line fits, we emit it verbatim (no truncation needed).
 *   - When we must truncate, we append explicit hyperlink + SGR terminators
 *     so any unfinished escape state is closed at end-of-line.
 */

import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

/** OSC 8 link terminator + SGR reset. Always safe to append. */
export const ESC_RESET = "\x1b]8;;\x1b\\\x1b[0m";

/**
 * Truncate to `width` visible columns, then append `ESC_RESET` so any
 * dangling hyperlink / SGR state is closed. Only appends the suffix when the
 * input was actually truncated, to keep output clean in the common case.
 */
export function safeTruncate(line: string, width: number): string {
  const truncated = truncateToWidth(line, width, "");
  // If truncation removed characters, there may be a dangling escape open.
  // Heuristic: `truncateToWidth` returns the full string when no truncation
  // happened, so compare lengths.
  if (truncated.length !== line.length) return truncated + ESC_RESET;
  return truncated;
}

/**
 * Compose a left/center/right tri-pane line. When everything fits the center
 * is placed as close to the geometric middle as possible without overlapping
 * either side. When it does not fit we drop the center and fall back to a
 * two-pane left/right layout. Either way the result is guaranteed not to
 * exceed `width` columns.
 */
export function composeLeftCenterRight(
  leftStyled: string,
  leftWidth: number,
  centerStyled: string,
  centerWidth: number,
  rightStyled: string,
  rightWidth: number,
  width: number,
): string {
  if (leftWidth + centerWidth + rightWidth <= width) {
    const midpoint = Math.floor(width / 2);
    const idealStart = Math.max(leftWidth, midpoint - Math.floor(centerWidth / 2));
    const rightStart = width - rightWidth;
    const actualStart = Math.min(idealStart, rightStart - centerWidth);
    const pad1 = Math.max(0, actualStart - leftWidth);
    const pad2 = Math.max(0, rightStart - actualStart - centerWidth);
    return safeTruncate(
      leftStyled + " ".repeat(pad1) + centerStyled + " ".repeat(pad2) + rightStyled,
      width,
    );
  }
  return composeLeftRight(leftStyled, leftWidth, rightStyled, rightWidth, width);
}

/** Compose a left/right line, padding the middle. Guarantees `width` columns max. */
export function composeLeftRight(
  leftStyled: string,
  leftWidth: number,
  rightStyled: string,
  rightWidth: number,
  width: number,
): string {
  const pad = Math.max(0, width - leftWidth - rightWidth);
  return safeTruncate(leftStyled + " ".repeat(pad) + rightStyled, width);
}

/** Compose a centered single segment with the given total `width`. */
export function composeCentered(
  contentStyled: string,
  contentWidth: number,
  width: number,
): string {
  const pad = Math.max(0, Math.floor((width - contentWidth) / 2));
  return safeTruncate(" ".repeat(pad) + contentStyled, width);
}

/** Re-exports so the render layer does not need to import pi-tui directly. */
export { visibleWidth };
