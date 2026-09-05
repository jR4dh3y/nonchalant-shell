"""
config_model.py
Model for reactive configuration store (simulates Config.bar and ConfigValidator).
"""

from typing import List, Dict, Callable, Any

class BarConfigModel:
    def __init__(self,
                 style: str = "default",
                 position: str = "top",
                 screen_list: List[str] = None,
                 enable_firefox_player: bool = False,
                 use_12h_format: bool = False):
        self._style = "default"
        self._position = "top"
        self._screen_list = list(screen_list) if screen_list else []
        self._enable_firefox_player = bool(enable_firefox_player)
        self._use_12h_format = bool(use_12h_format)

        self._listeners: Dict[str, List[Callable[[Any], None]]] = {
            "style": [],
            "position": [],
            "screenList": [],
            "enableFirefoxPlayer": [],
            "use12hFormat": []
        }

        # Validate initial values
        self.style = style
        self.position = position

    @property
    def style(self) -> str:
        return self._style

    @style.setter
    def style(self, val: Any):
        valid = ["default", "island"]
        new_val = val if (isinstance(val, str) and val in valid) else "default"
        if self._style != new_val:
            self._style = new_val
            self._notify("style", self._style)

    @property
    def position(self) -> str:
        return self._position

    @position.setter
    def position(self, val: Any):
        valid = ["top", "bottom"]
        new_val = val if (isinstance(val, str) and val in valid) else "top"
        if self._position != new_val:
            self._position = new_val
            self._notify("position", self._position)

    @property
    def screen_list(self) -> List[str]:
        return list(self._screen_list)

    @screen_list.setter
    def screen_list(self, val: Any):
        new_val = list(val) if isinstance(val, (list, tuple)) else []
        if self._screen_list != new_val:
            self._screen_list = new_val
            self._notify("screenList", self._screen_list)

    def on_change(self, key: str, callback: Callable[[Any], None]):
        if key in self._listeners:
            self._listeners[key].append(callback)

    def _notify(self, key: str, value: Any):
        for cb in self._listeners.get(key, []):
            cb(value)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "style": self._style,
            "position": self._position,
            "screenList": self._screen_list,
            "enableFirefoxPlayer": self._enable_firefox_player,
            "use12hFormat": self._use_12h_format
        }

    def load_from_dict(self, data: Dict[str, Any]):
        if not isinstance(data, dict):
            return
        if "style" in data:
            self.style = data["style"]
        if "position" in data:
            self.position = data["position"]
        if "screenList" in data:
            self.screen_list = data["screenList"]
        if "enableFirefoxPlayer" in data:
            self._enable_firefox_player = bool(data["enableFirefoxPlayer"])
        if "use12hFormat" in data:
            self._use_12h_format = bool(data["use12hFormat"])
