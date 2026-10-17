{ pkgs, source }:
let
  headlessAquamarine = pkgs.aquamarine.overrideAttrs (old: {
    patches = (old.patches or []) ++ [ ./headless-aquamarine.patch ];
  });
  headlessHyprland = pkgs.writeShellScriptBin "Hyprland" ''
    export LD_LIBRARY_PATH="${headlessAquamarine}/lib:''${LD_LIBRARY_PATH:-}"
    exec ${pkgs.hyprland}/bin/Hyprland "$@"
  '';
  phosphor = import ./packages/phosphor-icons.nix { inherit pkgs; };
  qmlModules = pkgs.buildEnv {
    name = "nonchalant-test-qml-modules";
    paths = with pkgs; [ kdePackages.qtmultimedia kdePackages.syntax-highlighting ];
  };
  fontConfig = pkgs.makeFontsConf {
    fontDirectories = [ pkgs.dejavu_fonts phosphor ];
  };
  testTools = with pkgs; [
    (python3.withPackages (ps: [ ps.pillow ps.dbus-next ])) quickshell niri headlessHyprland hyprland weston grim dbus mesa
    fontconfig dejavu_fonts qmlModules phosphor nodejs wtype wlrctl
    (lib.getBin qt6.qtdeclarative)
  ];
in {
  shell = pkgs.mkShellNoCC {
    packages = testTools;
    QML_IMPORT_PATH = "${qmlModules}/lib/qt-6/qml";
    FONTCONFIG_FILE = fontConfig;
    __EGL_VENDOR_LIBRARY_FILENAMES = "${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json";
  };
  runner = pkgs.writeShellApplication {
    name = "nonchalant-compositor-test";
    runtimeInputs = testTools;
    text = ''
      export QML_IMPORT_PATH="${qmlModules}/lib/qt-6/qml"
      export FONTCONFIG_FILE="${fontConfig}"
      export __EGL_VENDOR_LIBRARY_FILENAMES="${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json"
      exec python3 ${source}/tests/runtime/run_compositor.py --source ${source} "$@"
    '';
  };
}
