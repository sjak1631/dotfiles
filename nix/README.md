# nix

NixOS-WSL の flake (host `nixos-wsl`)。

| ファイル | 内容 |
|---|---|
| `flake.nix` | inputs (nixpkgs 26.05 / NixOS-WSL / home-manager) |
| `configuration.nix` | システム設定 (WSL, nix, nix-ld, ユーザー) |
| `home.nix` | home-manager (zsh, git, CLI ツール) |

## セットアップ

Windows 側で `chezmoi apply` するだけ (`windows/.chezmoiscripts/run_after_90-wsl.ps1.tmpl`)。

1. WSL が無ければ `wsl --install --no-distribution` (UAC あり、終わったら再起動して apply し直す)
2. `NixOS` ディストロが無ければ NixOS-WSL の最新リリースを import
3. このディレクトリが前回から変わっていれば `nixos-rebuild` (初回はデフォルトユーザーを `nixos` から切り替えるため `boot` + ディストロ再起動)

ビルドは chezmoi のソースディレクトリ (Windows 側) を `path:` flake として直接使うので、push していない変更もそのまま反映される。

## WSL の中から

```sh
dotfiles-rebuild          # nixos-rebuild switch (Windows 側の chezmoi ソースから)
dotfiles-rebuild boot     # 次回起動時に反映
nix flake update --flake path:<chezmoi source>/nix   # inputs の更新 (flake.lock はコミットする)
```
