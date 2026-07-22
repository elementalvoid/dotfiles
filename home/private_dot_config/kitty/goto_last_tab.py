import json
import os

from kitty.constants import config_dir
from kittens.tui.handler import result_handler

STATE_FILE = os.path.join(config_dir, '.last_tab_state')


def main(args):
    pass


@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    try:
        with open(STATE_FILE) as f:
            state = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return

    last_tab_id = state.get('last')
    if last_tab_id is None:
        return

    for tab in boss.all_tabs:
        if tab.id == last_tab_id:
            boss.set_active_tab(tab)
            return
