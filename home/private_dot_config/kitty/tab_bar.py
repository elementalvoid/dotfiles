# Custom tab bar kitten.
# Delegates all tab rendering to draw_tab_with_fade (the default style),
# then appends a right-aligned layout indicator in the remaining bar space.

from kitty.tab_bar import (
    DrawData,
    ExtraData,
    TabBarData,
    as_rgb,
    color_as_int,
    draw_tab_with_fade,
)
from kitty.fast_data_types import Screen

# Module-level cache: updated on each active tab render so _draw_layout_indicator
# can read it when processing is_last.
_active_layout: str = ""


def draw_tab(
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_tab_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
) -> int:
    global _active_layout
    if tab.is_active:
        _active_layout = tab.layout_name

    end = draw_tab_with_fade(
        draw_data, screen, tab, before, max_tab_length, index, is_last, extra_data
    )

    if is_last and _active_layout:
        _draw_layout_indicator(draw_data, screen)

    return end


def _draw_layout_indicator(draw_data: DrawData, screen: Screen) -> None:
    # Two segments:
    #   label  – " layout " in muted inactive_fg on default_bg
    #   value  – " {name} " in cyan (active_bg) on default_bg
    label = " layout "
    value = f" {_active_layout} "
    avail = screen.columns - screen.cursor.x

    if avail >= len(label) + len(value):
        pass  # both fit, draw as designed
    elif avail >= len(value):
        label = ""  # drop the label, keep the value
    else:
        return  # not enough room for anything useful

    total = len(label) + len(value)
    screen.cursor.x = screen.columns - total

    bg = as_rgb(color_as_int(draw_data.default_bg))

    if label:
        screen.cursor.bg = bg
        screen.cursor.fg = as_rgb(color_as_int(draw_data.inactive_fg))
        screen.draw(label)

    screen.cursor.bg = bg
    screen.cursor.fg = as_rgb(color_as_int(draw_data.active_bg))
    screen.draw(value)
