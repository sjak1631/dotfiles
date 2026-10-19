{ pkgs, ... }:

let
  # Rebuilds from the chezmoi source on the Windows side (the same files `chezmoi apply` uses)
  rebuild = pkgs.writeShellScriptBin "dotfiles-rebuild" ''
    set -eu
    cd /mnt/c
    home=$(wslpath "$(/mnt/c/Windows/System32/cmd.exe /c 'echo %USERPROFILE%' | tr -d '\r')")
    exec sudo nixos-rebuild "''${1:-switch}" --flake "path:$home/.local/share/chezmoi/nix#nixos-wsl"
  '';
in
{
  home.packages = with pkgs; [
    rebuild

    fd
    jq
    ripgrep
    tree
    unzip

    nil
    nixfmt
  ];

  programs.git = {
    enable = true;
    settings = {
      user.name = "sjak1631";
      user.email = "63937497+sjak1631@users.noreply.github.com";
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };
  # Also the git credential helper for github.com (`gh auth login` once)
  programs.gh.enable = true;

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    history = {
      size = 100000;
      ignoreAllDups = true;
      share = true;
    };
  };

  programs.starship.enable = true;
  programs.fzf.enable = true;
  programs.zoxide.enable = true;
  programs.eza.enable = true;
  programs.bat = {
    enable = true;
    config.theme = "gruvbox-dark";
  };
  programs.btop.enable = true;
  # Terminal file manager (nixpkgs' yazi comes wrapped with its preview tools); `y` cds to
  # where it was left. Settings are shared with Windows
  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
    settings = builtins.fromTOML (builtins.readFile ./yazi/yazi.toml);
  };
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  home.stateVersion = "26.05";
}
