{ pkgs, ... }:

let
  user = "sjak1631";
in
{
  wsl = {
    enable = true;
    defaultUser = user;
    # No "NixOS: <app>" shortcuts in the Windows Start menu
    startMenuLaunchers = false;
  };

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [ "root" user ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
    optimise.automatic = true;
  };
  nixpkgs.config.allowUnfree = true;

  time.timeZone = "Asia/Tokyo";
  i18n.defaultLocale = "en_US.UTF-8";

  # Prebuilt Linux binaries (the VS Code Remote-WSL server, language servers downloaded by
  # editors, ...) expect a regular dynamic loader
  programs.nix-ld.enable = true;

  programs.zsh.enable = true;
  users.users.${user}.shell = pkgs.zsh;

  environment.systemPackages = with pkgs; [
    curl
    git
    wget
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";
    users.${user} = import ./home.nix;
  };

  # The NixOS release the distro was first installed with; don't bump it on upgrades
  system.stateVersion = "26.05";
}
