# Media packages: video, audio, players
{ pkgs }:

with pkgs; [
  mpvpaper

  ffmpeg
  x264
  playerctl

  # Audio
  pipewire
  wireplumber
]
