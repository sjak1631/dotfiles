// Shared by bar.js and panel.js.
//
// The drop-down panels live in one pre-started, hidden widget (panel.html). The bar
// talks to it through localStorage, whose `storage` events reach the other widget:
//   CMD_KEY:  written by the bar, {op: 'open' | 'close', name, right, barWidth, barHeight, t}
//   OPEN_KEY: name of the panel currently shown (written by the panel widget)
export const CMD_KEY = 'zebar-panel-cmd';
export const OPEN_KEY = 'zebar-panel-open';

// Tray icons not shown in the tray panel (matched against the tooltip).
// The Windows volume icon duplicates the bar's own volume control.
const HIDDEN_TRAY = [/スピーカー|ヘッドホン|ヘッドフォン|speaker|headphone/i];
export const visibleTrayIcons = (systray) =>
  (systray?.icons ?? []).filter((i) => !HIDDEN_TRAY.some((re) => re.test(i.tooltip ?? '')));

export const icon = (name) => `<i class="nf ${name}"></i>`;
export const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
