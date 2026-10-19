// Drop-down panels: one widget, started hidden with Zebar, shown/moved on request from the bar.
// Reusing the window avoids creating a WebView2 window per click.
import * as zebar from 'https://esm.sh/zebar@3.3.1';
// Same @tauri-apps/api version zebar depends on, so the window methods accept these
import { LogicalPosition, LogicalSize } from 'https://esm.sh/@tauri-apps/api@2.0.2/dpi';
import { CMD_KEY, OPEN_KEY, visibleTrayIcons, icon, esc } from './common.js';
import { BIN } from './paths.js';

const win = zebar.currentWidget().tauriWindow;
win.hide();

// Panel state, declared first because the sections below read it during setup
let current = null;  // name of the visible section
let anchor = null;   // {right, barWidth, barHeight} from the bar, in logical px
let focusedAtOpen;

const providers = zebar.createProviderGroup({
  glazewm: { type: 'glazewm' },
  audio: { type: 'audio' },
  media: { type: 'media' },
  systray: { type: 'systray' },
});

// Runs a helper script from ~/.local/bin (allowed in zpack.json `privileges`)
const runScript = (name, ...args) =>
  zebar.shellExec('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', `${BIN}/${name}.ps1`, ...args]);

// Collects [data-ref] elements of a section into an object
const refs = (id) => Object.fromEntries([...document.getElementById(id).querySelectorAll('[data-ref]')].map((el) => [el.dataset.ref, el]));

function setRange(input, value) {
  input.value = String(value);
  input.style.setProperty('--pct', `${value}%`);
}

// ---- calendar ----
const calendar = (() => {
  const r = refs('calendar');
  const DOW = ['日', '月', '火', '水', '木', '金', '土'];
  let view;

  function tick() {
    const now = new Date();
    r.time.textContent = now.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
    r.date.textContent = now.toLocaleDateString('ja-JP', { year: 'numeric', month: 'long', day: 'numeric', weekday: 'long' });
  }

  function renderMonth() {
    const today = new Date();
    const y = view.getFullYear(), m = view.getMonth();
    r.month.textContent = `${y}年 ${m + 1}月`;
    const cells = DOW.map((d, i) => `<span class="dow ${i === 0 ? 'sun' : i === 6 ? 'sat' : ''}">${d}</span>`);
    const start = new Date(y, m, 1 - new Date(y, m, 1).getDay());
    for (let i = 0; i < 42; i++) {
      const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
      const cls = [
        d.getMonth() !== m && 'other',
        d.getDay() === 0 && 'sun',
        d.getDay() === 6 && 'sat',
        d.toDateString() === today.toDateString() && 'today',
      ].filter(Boolean).join(' ');
      cells.push(`<span class="${cls}">${d.getDate()}</span>`);
    }
    r.grid.innerHTML = cells.join('');
  }

  const resetView = () => { view = new Date(); view.setDate(1); };
  const shift = (n) => { view.setMonth(view.getMonth() + n); renderMonth(); };
  r.prev.addEventListener('click', () => shift(-1));
  r.next.addEventListener('click', () => shift(1));
  r.month.addEventListener('click', () => { resetView(); renderMonth(); });
  document.getElementById('calendar').addEventListener('wheel', (e) => shift(e.deltaY > 0 ? 1 : -1), { passive: true });
  setInterval(() => { if (current === 'calendar') tick(); }, 1000);

  return { onOpen() { resetView(); tick(); renderMonth(); } };
})();

// ---- volume ----
const volume = (() => {
  const r = refs('volume');
  let dragging = false;

  function speakerIcon(d) {
    if (d.type === 'recording') return icon(d.isMuted ? 'nf-md-microphone_off' : 'nf-md-microphone');
    if (d.isMuted || d.volume === 0) return icon('nf-md-volume_off');
    if (d.volume < 34) return icon('nf-md-volume_low');
    if (d.volume < 67) return icon('nf-md-volume_medium');
    return icon('nf-md-volume_high');
  }

  function row(out, d) {
    const el = document.createElement('div');
    el.className = ['dev', d.isDefaultPlayback || d.isDefaultRecording ? 'default' : '', d.isMuted ? 'muted-dev' : ''].join(' ');
    el.innerHTML = `
      <div class="name ellipsis" title="${esc(d.name)}">${esc(d.name)}</div>
      <div class="row">
        <button type="button" title="ミュート切り替え">${speakerIcon(d)}</button>
        <input type="range" min="0" max="100" step="1" aria-label="${esc(d.name)} の音量" />
        <span class="pct">${Math.round(d.volume)}%</span>
      </div>`;
    const range = el.querySelector('input');
    setRange(range, Math.round(d.volume));
    el.querySelector('button').addEventListener('click', () => out.setMute(!d.isMuted, { deviceId: d.deviceId }));
    range.addEventListener('pointerdown', () => { dragging = true; });
    range.addEventListener('pointerup', () => { dragging = false; });
    range.addEventListener('input', () => {
      setRange(range, range.value);
      el.querySelector('.pct').textContent = `${range.value}%`;
      out.setVolume(Number(range.value), { deviceId: d.deviceId });
    });
    return el;
  }

  function render() {
    const out = providers.outputMap.audio;
    if (dragging || !out) return;
    r.playback.replaceChildren(...out.playbackDevices.map((d) => row(out, d)));
    const mic = out.defaultRecordingDevice;
    r.rec.hidden = !mic;
    r.recording.replaceChildren(...(mic ? [row(out, mic)] : []));
  }

  return { render };
})();

// ---- media ----
const media = (() => {
  const r = refs('media');
  const fmt = (s) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`;
  // Position is reported on changes only; advance it locally while playing
  let base = { pos: 0, at: Date.now(), playing: false, end: 0 };

  function tick() {
    const pos = Math.min(base.end || Infinity, base.pos + (base.playing ? (Date.now() - base.at) / 1000 : 0));
    r.pos.textContent = fmt(pos);
    r.end.textContent = base.end ? fmt(base.end) : '';
    r.fill.style.width = base.end ? `${(pos / base.end) * 100}%` : '0';
  }

  function render() {
    const s = providers.outputMap.media?.currentSession;
    r.empty.hidden = !!s;
    r.player.hidden = !s;
    if (!s) return;
    r.title.textContent = s.title ?? '';
    r.sub.textContent = [s.artist, s.albumTitle].filter(Boolean).join(' · ');
    r.play.innerHTML = icon(s.isPlaying ? 'nf-md-pause' : 'nf-md-play');
    base = { pos: s.position ?? 0, at: Date.now(), playing: s.isPlaying, end: s.endTime ?? 0 };
    tick();
  }

  const m = () => providers.outputMap.media;
  const opts = () => ({ sessionId: m()?.currentSession?.sessionId });
  r.prev.addEventListener('click', () => m()?.previous(opts()));
  r.play.addEventListener('click', () => m()?.togglePlayPause(opts()));
  r.next.addEventListener('click', () => m()?.next(opts()));
  setInterval(() => { if (current === 'media') tick(); }, 1000);

  return { render };
})();

// ---- tray ----
const tray = (() => {
  const r = refs('tray');
  const COLUMNS = 6;
  let key = '';

  function render() {
    const out = providers.outputMap.systray;
    const icons = visibleTrayIcons(out);
    const next = icons.map((i) => `${i.id}:${i.iconHash}:${i.tooltip}`).join('|');
    if (next === key) return;
    key = next;

    r.empty.hidden = icons.length > 0;
    r.grid.style.setProperty('--cols', Math.min(Math.max(icons.length, 1), COLUMNS));
    r.grid.replaceChildren(...icons.map((i) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.title = i.tooltip ?? '';
      b.innerHTML = `<img src="${i.iconUrl}" alt="" />`;
      b.addEventListener('click', () => out.onLeftClick(i.id));
      b.addEventListener('dblclick', () => out.onLeftDoubleClick(i.id));
      b.addEventListener('contextmenu', (e) => { e.preventDefault(); out.onRightClick(i.id); });
      b.addEventListener('auxclick', (e) => { if (e.button === 1) out.onMiddleClick(i.id); });
      b.addEventListener('mouseenter', () => out.onHoverEnter(i.id));
      b.addEventListener('mouseleave', () => out.onHoverLeave(i.id));
      b.addEventListener('mousemove', () => out.onHoverMove(i.id));
      return b;
    }));
  }

  return { render };
})();

// ---- bluetooth ----
const bluetooth = (() => {
  const r = refs('bluetooth');
  // Querying takes ~1.5s (PowerShell + WinRT), so show the last result and refresh behind it
  let status = null;
  let loading = false;

  function render() {
    const on = status?.radio === 'On';
    r.toggle.setAttribute('aria-checked', String(on));
    r.toggle.disabled = !status?.radio;
    const devices = on ? status.devices : [];
    r.list.replaceChildren(...devices.map((d) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = `dev ${d.connected ? 'connected' : ''}`;
      b.title = 'Bluetooth の設定を開く';
      b.innerHTML = `${icon(d.connected ? 'nf-md-bluetooth_connect' : 'nf-md-bluetooth')}<span class="ellipsis">${esc(d.name)}</span><span class="state">${d.connected ? '接続中' : ''}</span>`;
      b.addEventListener('click', openSettings);
      return b;
    }));
    r.empty.hidden = devices.length > 0;
    r.empty.textContent = !status ? (loading ? '読み込み中…' : '状態を取得できませんでした')
      : !status.radio ? 'Bluetooth が見つかりません'
      : !on ? 'Bluetooth はオフです' : 'ペアリング済みのデバイスはありません';
    fit();
  }

  async function refresh() {
    loading = true;
    render();
    try {
      const out = await runScript('bluetooth', 'status');
      status = JSON.parse(out.stdout);
    } catch (e) {
      console.error(e);
    }
    loading = false;
    render();
  }

  function openSettings() {
    runScript('bluetooth', 'settings').catch(console.error);
    close();
  }

  r.toggle.addEventListener('click', async () => {
    const next = status?.radio === 'On' ? 'off' : 'on';
    status = { ...status, radio: next === 'on' ? 'On' : 'Off' };
    render();
    await runScript('bluetooth', next).catch(console.error);
    refresh();
  });
  r.settings.addEventListener('click', openSettings);
  refresh();

  return { onOpen: refresh, render };
})();

// ---- power ----
const power = (() => {
  const section = document.getElementById('power');
  let armed = null;
  let timer;

  const disarm = () => {
    armed?.classList.remove('armed');
    armed?.querySelector('.hint')?.remove();
    armed = null;
  };

  section.querySelectorAll('button[data-action]').forEach((b) => {
    b.addEventListener('click', () => {
      // Destructive actions need a second click within 3 seconds
      if ('confirm' in b.dataset && armed !== b) {
        disarm();
        armed = b;
        b.classList.add('armed');
        b.insertAdjacentHTML('beforeend', '<span class="hint">もう一度押すと実行</span>');
        clearTimeout(timer);
        timer = setTimeout(disarm, 3000);
        return;
      }
      disarm();
      close();
      runScript('power', b.dataset.action).catch(console.error);
    });
  });

  return { onOpen: disarm };
})();

// ---- show / hide ----
const sections = { calendar, volume, media, tray, bluetooth, power };

function setOpenKey(name) {
  try { name ? localStorage.setItem(OPEN_KEY, name) : localStorage.removeItem(OPEN_KEY); } catch {}
}

// Sizes the window to the visible section and places it under the bar item, right-aligned
async function fit() {
  if (!current || !anchor) return;
  const el = document.getElementById(current);
  const width = Math.ceil(el.offsetWidth);
  const height = Math.ceil(el.offsetHeight);
  const x = Math.round(Math.max(8, Math.min(anchor.barWidth - width - 8, anchor.right - width + 12)));
  await win.setSize(new LogicalSize(width, height));
  await win.setPosition(new LogicalPosition(x, anchor.barHeight + 6));
}

async function open({ name, right, barWidth, barHeight }) {
  if (!sections[name]) return;
  current = name;
  anchor = { right, barWidth, barHeight };
  setOpenKey(name);
  focusedAtOpen = providers.outputMap.glazewm?.focusedContainer?.id;

  for (const n of Object.keys(sections)) {
    const el = document.getElementById(n);
    el.hidden = n !== name;
    // Restart the drop-in animation
    el.classList.remove('enter');
    if (n === name) { void el.offsetWidth; el.classList.add('enter'); }
  }
  sections[name].onOpen?.();
  sections[name].render?.();

  await fit();
  await win.show();
}

async function close() {
  if (!current) return;
  current = null;
  setOpenKey(null);
  await win.hide();
}

setOpenKey(null);

window.addEventListener('storage', (e) => {
  if (e.key !== CMD_KEY || !e.newValue) return;
  const cmd = JSON.parse(e.newValue);
  if (cmd.op === 'open') open(cmd).catch(console.error);
  else close().catch(console.error);
});

// Close when another window gets focus (GlazeWM); otherwise keep the open panel up to date
providers.onOutput(() => {
  if (!current) return;
  if (providers.outputMap.glazewm?.focusedContainer?.id !== focusedAtOpen) { close(); return; }
  sections[current].render?.();
});
window.addEventListener('blur', () => close());
window.addEventListener('keydown', (e) => { if (e.key === 'Escape') close(); });

// Close on clicks anywhere outside the panel and the bar. The panel can't get keyboard
// focus from the bar, so a global mouse hook (clickwatch.ps1) reports clicks instead.
async function watchClicks() {
  const proc = await zebar.shellSpawn('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', `${BIN}/clickwatch.ps1`]);
  proc.onStdout(async (line) => {
    if (!current || !anchor) return;
    const [x, y] = String(line).trim().split(' ').map(Number);
    const scale = window.devicePixelRatio;
    // Clicks on the bar are handled by the bar (toggle / switch panels)
    if (x >= 0 && x < anchor.barWidth * scale && y >= 0 && y < anchor.barHeight * scale) return;
    const pos = await win.outerPosition();
    const size = await win.outerSize();
    const inside = x >= pos.x && x < pos.x + size.width && y >= pos.y && y < pos.y + size.height;
    if (!inside) close();
  });
  proc.onExit(() => setTimeout(watchClicks, 2000));
}
watchClicks().catch(console.error);
