# ノート PC のセットアップ

新しい PC (`machine = laptop`) にこの dotfiles を入れるときの手順と確認リスト。

## 事前準備

- [ ] Windows Update を済ませる (winget / App Installer が古いと `winget configure` が動かない)
- [ ] 時間に余裕を見る: UAC の確認と再起動が 2 回ほど入る
- [ ] ネットワークの確認: GitHub・winget・cache.nixos.org に届くこと (会社のネットワークやプロキシに注意)
- [ ] キーボード配列を確認する: Windows は **US 配列**で使う (kanata の IME 切り替え CapsLock → Alt+\` が前提にしている)。内蔵が JIS 配列なら、外部キーボードがない間は kanata が JIS として扱う (`kbd-layout.ps1`)
- [ ] 質問への答えを決めておく

| 質問 | ノート PC での答え |
|---|---|
| `machine` | `laptop` |
| `hidpi` | 高解像度の画面なら `true` |
| `gitName` / `gitEmail` | `sjak1631` / GitHub の noreply アドレス |
| `wslLocation` | 空 (SSD が 1 台なら既定の場所で良い) |

## 手順

1. PowerShell でワンライナーを実行

   ```powershell
   iex "&{$(irm 'https://get.chezmoi.io/ps1')} -- init --apply sjak1631"
   ```

2. UAC の確認には「はい」(winget の有効化、各アプリ、WSL、Interception ドライバー)
3. **再起動して `chezmoi apply` をもう一度** (WSL の取り込みと NixOS のビルド、kanata の起動が進む)
4. 一度起動してから `chezmoi apply` が必要なアプリ
   - Spotify: 起動してログイン → apply で Spicetify が当たる
   - Zen、Vesktop: 一度起動 → apply で設定が入る
5. 手動でログイン・認証 (リポジトリには入らないもの)
   - Bitwarden、Zen (同期)、Slack、Vesktop、Zoom、VS Code (Settings Sync)
   - `gh auth login` (Windows 側と WSL 側の両方)
6. 壁紙を `~/Pictures/Wallpapers` に入れる (任意)

## 確認リスト

### 起動

- [ ] サインイン直後に GlazeWM・Zebar・Flow が起動し、タスクバーが隠れる
- [ ] PowerShell の窓や「スタートアップに登録されました」などの通知が出ない
- [ ] デスクトップのアイコンが消えている

### キーボード (kanata + Interception)

- [ ] `CapsLock` 単押しで IME 切り替え、長押しで Ctrl
- [ ] `Shift+CapsLock` で本来の CapsLock
- [ ] `Win` 単押しでスタートメニューが出ない (`Win+E` などは使える)
- [ ] しばらく使っても Ctrl が押しっぱなしにならない
- [ ] タッチパッドが普通に動く (Interception はマウスも通る)
- [ ] 外付けのキーボード・マウスを抜き差ししても動く

### GlazeWM・Zebar

- [ ] `Alt+1`〜`0` でワークスペース移動 (モニター 1 枚なので全部同じ画面)
- [ ] `Alt+Enter` でターミナル (WSL)、`Alt+E` でエクスプローラー、`Alt+Space` で Flow
- [ ] Zebar にバッテリーが出る
- [ ] 音量・Bluetooth・電源のパネルが開く
- [ ] 高解像度でもバーの高さや余白が崩れない

### 見た目

- [ ] カーソルが Bibata (gruvbox なら Amber)
- [ ] ターミナルが透過している
- [ ] Flow で `wp` と打つと壁紙を選べる
- [ ] Spotify・Vesktop にテーマが当たっている

### WSL

- [ ] `wsl -l` に NixOS があり、ユーザーが `sjak1631`
- [ ] `y` (yazi)、`fastfetch`、`dotfiles-rebuild` が動く

### ノート PC 特有

- [ ] ふたを閉じる・スリープから復帰しても GlazeWM と kanata が動いている
- [ ] 外部モニターをつないだり外したりしても、Zebar とタスクバーがおかしくならない
- [ ] Steam・HoYoPlay が入っていない (desktop 専用)

## うまくいかなかったら

- キーが効かない・修飾キーが押しっぱなし: `LCtrl+Space+Esc` で kanata を止める
- キーボードとマウスが両方効かない: Interception の既知の問題。再起動で直る
- 止まった場所、エラーメッセージ、`chezmoi apply` の出力を控えておく。直したらデスクトップから push し、ノート PC で `chezmoi update`
