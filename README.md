# dotfiles

Windows 11 を 1 行で再現するための dotfiles。[chezmoi](https://www.chezmoi.io/) + WinGet Configuration で Windows を、Nix flake で WSL (NixOS) を管理する。

- **タイル型 WM の rice**: GlazeWM + Zebar (自作バー) + Flow Launcher。配色・余白・角丸などは `rice.yaml` 1 ファイルで切り替え、GlazeWM / Zebar / WezTerm / Flow / Vesktop / Spotify / カーソルまで追従する
- **静かな Windows**: タスクバー・デスクトップアイコン・スナップ・おすすめ通知・不要なスタートアップを無効化
- **NixOS-WSL**: `chezmoi apply` が WSL のインストールから `nixos-rebuild` まで面倒を見る

## セットアップ

PowerShell で:

```powershell
iex "&{$(irm 'https://get.chezmoi.io/ps1')} -- init --apply sjak1631"
```

最初にいくつか質問される。答えは `~/.config/chezmoi/chezmoi.toml` に保存され、リポジトリには入らない。

| 質問 | 内容 |
|---|---|
| `machine` | `desktop` / `laptop` (入れるアプリ、モニター設定、ワークスペースの割り当てが変わる) |
| `hidpi` | 高 DPI ディスプレイか (フォントサイズなど) |
| `gitName` / `gitEmail` | git の user (GitHub の noreply アドレス推奨) |
| `wslLocation` | NixOS-WSL を置くフォルダ (空 = WSL の既定の場所) |

途中で UAC の確認が何度か出る (winget の一部パッケージ、WSL、Interception ドライバー)。WSL と Interception は **再起動後にもう一度 `chezmoi apply`** で続きが進む。

新しいノート PC に入れるときの手順と確認リスト: [docs/laptop-setup.md](docs/laptop-setup.md)

一部は初回起動が必要: Spotify (起動してログイン → apply で Spicetify が当たる)、Vesktop / Zen (初回起動で設定ファイルができる → apply)。

## 日常の操作

| やりたいこと | コマンド |
|---|---|
| 変更を反映 | `chezmoi apply` |
| リモートの変更を取り込んで反映 | `chezmoi update` |
| 設定ファイルを編集 | `chezmoi edit <file>` |
| ソースディレクトリへ移動 | `chezmoi cd` |
| 何が変わるか確認 | `chezmoi diff` |

`apply` は何度実行しても同じ状態になる (変更があったところだけ動く)。

## Rice

`windows/.chezmoidata/rice.yaml` を編集して `chezmoi apply`。

```yaml
rice:
  theme: gruvbox      # gruvbox / catppuccin / tokyonight / rosepine / nord / everforest / kanagawa
  style: floating     # floating (浮いたバー、広めの隙間、角丸) / flat
  font: JetBrainsMono Nerd Font
  cursor_size: Regular
  terminal_opacity: 0.85
```

| 追従するもの | 何が変わるか |
|---|---|
| GlazeWM | ボーダー色、隙間、角の形 |
| Zebar | バーの配色、高さ、余白 |
| WezTerm | カラースキーム (`terminal_schemes`)、フォント、透過 |
| Flow Launcher | テーマ、壁紙プラグインのアイコン |
| Vesktop | midnight-discord ベースのテーマ |
| Spotify | Spicetify の配色と角丸 |
| カーソル | Bibata Modern の色 (`cursors`: Amber / Classic / Ice) |
| yazi | 端末の ANSI 色を使うので WezTerm に追従 |
| 壁紙 | テーマごとの初期壁紙 (`wallpapers`) |

### Zebar (バー)

ワークスペース、ウィンドウタイトル、バインディングモード、メディア、CPU / メモリ、ネットワーク、Bluetooth、音量、バッテリー、トレイ、日付、電源。クリックでパネル (カレンダー、音量、メディア、Bluetooth、トレイ、電源) が開く。縦置きモニターではワークスペースと時計だけ。

### 壁紙

画像は `~/Pictures/Wallpapers` に置く (横長・縦長を自動判別)。リポジトリの `windows/Pictures/Wallpapers` が apply で配られ、手元で足した画像はそのまま残る。Flow Launcher で `wp` と打つと一覧から選べる。`wallpaper.ps1 next | prev | random` でも切り替えられる。ロック画面も横長の壁紙に追従する。

## キー操作

### GlazeWM (Alt ベース)

| キー | 動作 |
|---|---|
| `Alt+H/J/K/L` (矢印) | フォーカス移動 |
| `Alt+Shift+H/J/K/L` | ウィンドウ移動 |
| `Alt+1`〜`9`, `Alt+0` | ワークスペース移動 (desktop: 1〜9 はメイン、0 はサブモニター) |
| `Alt+Shift+1`〜`9`, `0` | ウィンドウをワークスペースへ送る |
| `Alt+Ctrl+1`〜`9`, `0` | 今のワークスペースとその番号のワークスペースを中身ごと入れ替える (相手が空なら番号の付け替え) |
| `Alt+S` / `Alt+A` / `Alt+D` | 次 / 前 / 直前のワークスペース |
| `Alt`+ホイール下 / 上 | 次 / 前のワークスペース (kanata が `Alt+S` / `Alt+A` に変換) |
| 3 本指スワイプ右 / 左 | 次 / 前のワークスペース (ノート PC のタッチパッド) |
| `Alt+Shift+A/F/D/S` | ワークスペースを左 / 右 / 上 / 下のモニターへ |
| `Alt+U/P` / `Alt+O/I` | 幅 / 高さの調整 |
| `Alt+R` | リサイズモード (HJKL、Esc で抜ける) |
| `Alt+V` | 次に分割する方向を切り替え |
| `Alt+T` / `Alt+Shift+Space` | タイル / フローティング |
| `Alt+F` / `Alt+M` | フルスクリーン / 最小化 |
| `Alt+Shift+Q` | ウィンドウを閉じる |
| `Alt+Enter` | ターミナル (WezTerm → NixOS-WSL) |
| `Alt+Shift+Enter` | ターミナル (WezTerm → PowerShell) |
| `Alt+E` | エクスプローラー |
| `Alt+Shift+R` / `Alt+Shift+W` | 設定の再読み込み / 再配置 |
| `Alt+Shift+P` | GlazeWM を一時停止 |
| `Alt+Shift+E` | GlazeWM を終了 (タスクバーが戻る) |

### その他

| キー | 動作 |
|---|---|
| `Alt+Space` | Flow Launcher (`wp` で壁紙) |
| `CapsLock` 単押し | IME の切り替え (kanata) |
| `CapsLock` 長押し | Ctrl |
| `Shift+CapsLock` | 本来の CapsLock |
| `Win` 単押し | 何もしない (Win+キーは普段どおり) |
| `LCtrl+Space+Esc` | kanata の緊急停止 |

kanata は Interception ドライバー版を使う。フック版ではキーを離した信号を取りこぼして Ctrl が押しっぱなしになることがあったため。

Windows の配列は常に US。ノート PC では外部キーボード (USB / Bluetooth) がつながっていない間だけ、kanata が内蔵キーボードを JIS 配列として扱う (刻印どおりの記号が出る、`半角/全角` で IME 切り替え)。外部キーボードをつなぐと数秒以内に US に戻る。切り替えは `~/.local/bin/kbd-layout.ps1` が kanata の TCP ポート (127.0.0.1:7313) 経由で行う。Windows 標準のキーボードごとの配列設定は、kanata がすべてのキーを 1 台のキーボードから送り直すため使えない。

## アプリ

`windows/winget/*.winget` (WinGet Configuration) で入れる。

| 対象 | 内容 |
|---|---|
| 共通 | Git, GitHub CLI, chezmoi, gitleaks, Zen Browser, Bitwarden, Slack, Vesktop, Spotify + Spicetify, Zoom, VS Code, LibreOffice, Claude, Kdenlive, Obsidian, kanata, GlazeWM, WezTerm, Flow Launcher, JetBrainsMono Nerd Font, yazi (+ 7zip / FFmpeg / Poppler / jq / fd / ripgrep / fzf / zoxide), fastfetch |
| desktop | Little Big Mouse, Steam, HoYoPlay (winget に無いので専用スクリプト、`D:\HoYoPlay` に入れる) |
| laptop | (なし) |

アプリごとの設定:

- **Zen**: `user.js` の管理ブロックで tooltip 無効など。GlazeWM が起動直後のウィンドウを再配置する (Zen が自分で前回位置に戻すため)
- **Spotify (Spicetify)**: Rice テーマ、右サイドバー・右上ボタン・再生バー右側のボタンを非表示、起動時に lofi beats を開く、タイトルバー最小化。Spotify の自動更新で外れても次の apply で当て直す
- **Vesktop**: rice テーマを有効化 (Vencord の設定の `enabledThemes` だけ管理)
- **Flow Launcher**: `Alt+Space`、Rice テーマ、壁紙プラグイン
- **yazi**: 設定は `nix/yazi/yazi.toml` を Windows / WSL で共用。`y` で起動し、終了時にそのディレクトリへ移動
- **PowerShell**: `$PROFILE` は `~/.config/powershell/profile.ps1` を読むだけ (Documents が OneDrive でも動くように)。起動時に PATH をレジストリから読み直す

## Windows の調整

| スクリプト | 内容 |
|---|---|
| `05-quiet-windows` | おすすめ・ヒント・「スタートアップに登録されました」の通知を無効化 |
| `06-startup-apps` | OneDrive / Slack / Steam / HoYoPlay / Spotify / Bitwarden / Edge の自動起動を無効化 |
| `07-explorer` | デスクトップアイコン非表示、サブモニターのタスクバー無効、スナップ無効 (GlazeWM が配置するため) |
| `08-touchpad` | ノート PC: 3 本指スワイプ左 / 右で前 / 次のワークスペース |
| `30-display` | (desktop) モニターの配置・向き・拡大率 |
| `40-littlebigmouse` | (desktop) 物理サイズに合わせたカーソル移動 |
| `72-cursor` | Bibata Modern カーソル (ユーザー単位、管理者不要) |
| `80-autostart` | kanata / GlazeWM / Flow (ノート PC は配列切り替えも) をログオンタスクで即起動 (Startup フォルダより早い) |

タスクバーは GlazeWM が動いている間だけ隠れ (`taskbar.ps1 watch`)、GlazeWM が終わると戻る。

## WSL (NixOS)

`nix/` の flake を apply 時に反映する。詳細は [nix/README.md](nix/README.md)。

- zsh + starship、git / gh、neovim、yazi、fzf / zoxide / eza / bat / ripgrep / fd、direnv
- fastfetch、cowsay / fortune / lolcat、figlet / toilet、cmatrix、cbonsai、pipes-rs、asciiquarium、tty-clock、sl
- nix-ld (VS Code Remote-WSL 用)

## 構成

```
.chezmoiroot              # chezmoi は windows/ をソースとして扱う
.githooks/pre-commit      # gitleaks
windows/
  .chezmoi.toml.tmpl      # マシンごとの質問 (machine / hidpi / git / wslLocation)
  .chezmoidata/rice.yaml  # テーマ・スタイル・壁紙・カーソル
  .chezmoiscripts/        # apply 時に走るスクリプト (番号順)
  .chezmoiremove          # 以前配っていて、今は消すファイル
  winget/                 # common.winget + <machine>.winget
  dot_glzr/               # GlazeWM 設定、Zebar ウィジェット
  dot_config/             # WezTerm, yazi, PowerShell profile
  dot_local/bin/          # 補助スクリプト (taskbar, wallpaper, bluetooth, power, ...)
  AppData/Roaming/        # kanata, Flow Launcher, Spicetify, Vesktop
  Pictures/Wallpapers/    # 壁紙 (~/Pictures/Wallpapers に配る)
nix/                      # NixOS-WSL の flake
```

## トラブルシューティング

| 症状 | 対処 |
|---|---|
| キーが効かない / 修飾キーが押しっぱなし | `LCtrl+Space+Esc` で kanata を止める |
| キーボードとマウスが両方効かない | Interception ドライバーの既知の問題 (機器の抜き差しが多すぎた)。再起動で直る |
| GlazeWM がおかしい | `Alt+Shift+R` で再読み込み、`Alt+Shift+W` で再配置 |
| タスクバーが出てきた | `Alt+Shift+R`、または `taskbar.ps1 hide` |
| Spotify のテーマが外れた | `chezmoi apply` (Spotify の更新を検知して当て直す) |

## 秘密情報

- このリポジトリは公開。トークン・鍵・個人情報 (メールアドレス、モニターのシリアル、PC 名など) はコミットしない
- マシン固有の値は `~/.config/chezmoi/chezmoi.toml` と `%LOCALAPPDATA%\dotfiles\` に置く
- pre-commit で gitleaks が走る (`core.hooksPath = .githooks`)
