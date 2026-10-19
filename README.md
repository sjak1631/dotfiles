# dotfiles

Windows (chezmoi + WinGet Configuration) と Nix の設定。

## Setup (Windows)

```powershell
iex "&{$(irm 'https://get.chezmoi.io/ps1')} -- init --apply sjak1631"
```

初回にマシン種別などを聞かれる。回答は `~/.config/chezmoi/chezmoi.toml` に保存され、リポジトリには含まれない。

## 日常の操作

| やりたいこと | コマンド |
|---|---|
| 変更を反映 | `chezmoi apply` |
| リモートの変更を取り込んで反映 | `chezmoi update` |
| 設定ファイルを編集 | `chezmoi edit <file>` |
| ソースディレクトリへ移動 | `chezmoi cd` |

## 構成

```
.chezmoiroot           # chezmoi は windows/ をソースとして扱う
windows/
  .chezmoi.toml.tmpl   # マシンごとの値 (machine / hidpi / git 情報)
  .chezmoiscripts/     # 前処理、winget configure
  winget/              # common.winget + <machine>.winget
  dot_*, AppData/ ...  # 配布するファイル
nix/                   # NixOS-WSL の flake (apply 時に WSL へ反映、nix/README.md)
```

## 秘密情報

- このリポジトリは公開。トークン・鍵・個人情報はコミットしない
- pre-commit で gitleaks が走る (`core.hooksPath = .githooks`)
