import json
import os

from kitty.constants import config_dir

STATE_FILE = os.path.join(config_dir, '.last_tab_state')


def on_focus_change(boss, window, data):
    import sys
    print(f'[last_tab_watcher] on_focus_change fired: window={window}, data={data}', file=sys.stderr, flush=True)
    if not window or not data.get('focused'):
        return

    new_tab_id = window.tab_id

    try:
        with open(STATE_FILE) as f:
            state = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        state = {'current': None, 'last': None}

    if state.get('current') != new_tab_id:
        state['last'] = state.get('current')
        state['current'] = new_tab_id
        with open(STATE_FILE, 'w') as f:
            json.dump(state, f)
