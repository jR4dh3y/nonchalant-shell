pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    property var palettesByName: Object.create(null)

    function forScreen(name: string): ShellPalette {
        return root.palettesByName[name] ?? Colors;
    }

    function forItem(item: Item): ShellPalette {
        const window = item?.QsWindow?.window;
        return window?.shellPalette ?? forScreen(window?.screen?.name ?? item?.Screen?.name ?? "");
    }

    function register(name: string, palette: ShellPalette): void {
        root.palettesByName = Object.assign(Object.create(null), root.palettesByName, { [name]: palette });
    }

    function unregister(name: string, palette: ShellPalette): void {
        if (root.palettesByName[name] !== palette)
            return;
        const palettes = Object.assign(Object.create(null), root.palettesByName);
        delete palettes[name];
        root.palettesByName = palettes;
    }
}
