"""
niri_model.py
Model for Niri compositor workspace and window tracking (simulates NiriService).
"""

from typing import Dict, List, Optional, Any

class NiriWorkspace:
    def __init__(self, id: int, idx: int, output: str, name: str = "", active: bool = False):
        self.id = id
        self.idx = idx
        self.output = output
        self.name = name or str(idx)
        self.active = active
        self.windows = 0

class NiriWindow:
    def __init__(self, id: int, workspace_id: int, app_id: str, title: str):
        self.id = id
        self.workspace_id = workspace_id
        self.app_id = app_id
        self.title = title

class NiriCompositorModel:
    def __init__(self, monitors: Optional[List[str]] = None):
        self.monitors: List[str] = monitors or ["eDP-1"]
        self.workspaces: Dict[int, NiriWorkspace] = {}
        self.windows: Dict[int, NiriWindow] = {}

    def add_workspace(self, id: int, idx: int, output: str, active: bool = False) -> NiriWorkspace:
        ws = NiriWorkspace(id=id, idx=idx, output=output, active=active)
        self.workspaces[id] = ws
        return ws

    def activate_workspace(self, output: str, workspace_id: int):
        """Sets the active workspace for a specific monitor output."""
        for ws in self.workspaces.values():
            if ws.output == output:
                ws.active = (ws.id == workspace_id)

    def add_window(self, id: int, workspace_id: int, app_id: str = "app", title: str = "Window") -> NiriWindow:
        win = NiriWindow(id=id, workspace_id=workspace_id, app_id=app_id, title=title)
        self.windows[id] = win
        self._recount_windows()
        return win

    def close_window(self, id: int):
        if id in self.windows:
            del self.windows[id]
            self._recount_windows()

    def move_window_to_workspace(self, window_id: int, target_workspace_id: int):
        if window_id in self.windows and target_workspace_id in self.workspaces:
            self.windows[window_id].workspace_id = target_workspace_id
            self._recount_windows()

    def _recount_windows(self):
        for ws in self.workspaces.values():
            ws.windows = 0
        for win in self.windows.values():
            if win.workspace_id in self.workspaces:
                self.workspaces[win.workspace_id].windows += 1

    def get_active_workspace(self, output: str) -> Optional[NiriWorkspace]:
        for ws in self.workspaces.values():
            if ws.output == output and ws.active:
                return ws
        return None

    def get_window_count(self, output: str) -> int:
        ws = self.get_active_workspace(output)
        return ws.windows if ws else 0

    def has_active_windows(self, output: str) -> bool:
        return self.get_window_count(output) > 0
