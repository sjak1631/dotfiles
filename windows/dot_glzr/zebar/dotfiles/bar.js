import * as zebar from 'https://esm.sh/zebar@3.3.1';
import { OPEN_KEY, CMD_KEY } from './common.js';

const providers = zebar.createProviderGroup({
  glazewm: { type: 'glazewm' },
  cpu: { type: 'cpu', refreshInterval: 3000 },
  memory: { type: 'memory', refreshInterval: 5000 },
  network: { type: 'network', refreshInterval: 5000 },
  battery: { type: 'battery', refreshInterval: 10000 },
  media: { type: 'media' },
  audio: { type: 'audio' },
  systray: { type: 'systray' },
  date: { type: 'date', formatting: 'M/d (EEE) HH:mm', locale: 'ja-JP' },
});

// Shows a drop-down panel (panel.html) right below `anchorEl`, right-aligned to it.
// Clicking the item of the open panel closes it; clicking another item switches panels.
function sendPanel(cmd) {
  try { localStorage.setItem(CMD_KEY, JSON.stringify({ ...cmd, t: Date.now() })); } catch {}
}

function togglePanel(name, anchorEl) {
  let open = null;
  try { open = localStorage.getItem(OPEN_KEY); } catch {}
  if (open === name) { sendPanel({ op: 'close' }); return; }

  // The bar sits at the primary monitor's top-left, so bar coordinates are screen coordinates.
  // The panel sizes itself and right-aligns to `right`.
  const r = anchorEl.getBoundingClientRect();
  sendPanel({ op: 'open', name, right: r.right, barWidth: window.innerWidth, barHeight: window.innerHeight });
}

const $ = (id) => document.getElementById(id);
const style = getComputedStyle(document.documentElement).getPropertyValue('--style').trim();
document.body.classList.add(`style-${style}`);

// Narrow monitors (the portrait one is ~640 logical px wide) only get workspaces + clock
const updateCompact = () => document.body.classList.toggle('compact', window.innerWidth < 900);
window.addEventListener('resize', updateCompact);
updateCompact();

const icon = (name) => `<i class="nf ${name}"></i>`;
const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

function setItem(id, html) {
  const el = $(id);
  el.hidden = html == null;
  if (html != null && el.innerHTML !== html) el.innerHTML = html;
}

function renderWorkspaces(glazewm) {
  const root = $('workspaces');
  if (!glazewm) { root.replaceChildren(); return; }
  const buttons = glazewm.currentWorkspaces.map((ws) => {
    const b = document.createElement('button');
    b.className = ['workspace', ws.hasFocus && 'focused', ws.isDisplayed && 'displayed'].filter(Boolean).join(' ');
    b.textContent = ws.displayName ?? ws.name;
    b.addEventListener('click', () => glazewm.runCommand(`focus --workspace ${ws.name}`));
    return b;
  });
  root.replaceChildren(...buttons);

  const modes = [];
  if (glazewm.isPaused) modes.push(['PAUSED', 'wm-toggle-pause']);
  for (const m of glazewm.bindingModes) modes.push([m.displayName ?? m.name, `wm-disable-binding-mode --name ${m.name}`]);
  $('modes').replaceChildren(...modes.map(([label, cmd]) => {
    const b = document.createElement('button');
    b.className = 'mode';
    b.textContent = label;
    b.addEventListener('click', () => glazewm.runCommand(cmd));
    return b;
  }));
}

function networkIcon(net) {
  switch (net?.defaultInterface?.type) {
    case 'ethernet': return icon('nf-md-ethernet_cable');
    case 'wifi': {
      const s = net.defaultGateway?.signalStrength ?? 0;
      if (s >= 80) return icon('nf-md-wifi_strength_4');
      if (s >= 65) return icon('nf-md-wifi_strength_3');
      if (s >= 40) return icon('nf-md-wifi_strength_2');
      if (s >= 25) return icon('nf-md-wifi_strength_1');
      return icon('nf-md-wifi_strength_outline');
    }
    default: return icon('nf-md-wifi_strength_off_outline');
  }
}

function batteryIcon(pct) {
  if (pct > 90) return icon('nf-fa-battery_4');
  if (pct > 70) return icon('nf-fa-battery_3');
  if (pct > 40) return icon('nf-fa-battery_2');
  if (pct > 20) return icon('nf-fa-battery_1');
  return icon('nf-fa-battery_0');
}

function volumeIcon(dev) {
  if (dev.isMuted || dev.volume === 0) return icon('nf-md-volume_off');
  if (dev.volume < 34) return icon('nf-md-volume_low');
  if (dev.volume < 67) return icon('nf-md-volume_medium');
  return icon('nf-md-volume_high');
}

function render() {
  const o = providers.outputMap;

  const dev = o.audio?.defaultPlaybackDevice;
  setItem('volume', dev ? `${volumeIcon(dev)}${dev.isMuted ? 'mute' : Math.round(dev.volume) + '%'}` : null);

  renderWorkspaces(o.glazewm);

  const focused = o.glazewm?.focusedContainer;
  $('title').textContent = focused?.type === 'window' ? (focused.title || focused.processName || '') : '';

  const session = o.media?.currentSession;
  setItem('media', session?.title
    ? `${icon(session.isPlaying ? 'nf-md-music' : 'nf-md-pause')}<span class="ellipsis">${esc(session.title)}${session.artist ? ' · ' + esc(session.artist) : ''}</span>`
    : null);

  setItem('cpu', o.cpu ? `${icon('nf-oct-cpu')}<span class="${o.cpu.usage > 85 ? 'warn' : ''}">${Math.round(o.cpu.usage)}%</span>` : null);
  setItem('memory', o.memory ? `${icon('nf-fae-chip')}${Math.round(o.memory.usage)}%` : null);
  setItem('network', o.network ? networkIcon(o.network) + esc(o.network.defaultGateway?.ssid ?? '') : null);
  setItem('battery', o.battery
    ? `${o.battery.isCharging ? icon('nf-md-power_plug') : batteryIcon(o.battery.chargePercent)}${Math.round(o.battery.chargePercent)}%`
    : null);
  setItem('date', o.date ? esc(o.date.formatted) : null);
}

// Event handlers read the latest output, so they are attached once
$('media').addEventListener('click', (e) => togglePanel('media', e.currentTarget));
$('media').addEventListener('auxclick', (e) => { if (e.button === 1) providers.outputMap.media?.togglePlayPause(); });
$('date').addEventListener('click', (e) => togglePanel('calendar', e.currentTarget));
$('tray').addEventListener('click', (e) => togglePanel('tray', e.currentTarget));
$('bluetooth').addEventListener('click', (e) => togglePanel('bluetooth', e.currentTarget));
$('power').addEventListener('click', (e) => togglePanel('power', e.currentTarget));
$('volume').addEventListener('click', (e) => togglePanel('volume', e.currentTarget));
$('volume').addEventListener('auxclick', (e) => {
  if (e.button !== 1) return;
  const { audio } = providers.outputMap;
  const dev = audio?.defaultPlaybackDevice;
  if (dev) audio.setMute(!dev.isMuted);
});
$('volume').addEventListener('wheel', (e) => {
  const { audio } = providers.outputMap;
  const dev = audio?.defaultPlaybackDevice;
  if (!dev) return;
  const next = Math.min(100, Math.max(0, Math.round(dev.volume) + (e.deltaY < 0 ? 2 : -2)));
  audio.setVolume(next);
}, { passive: true });

providers.onOutput(render);
render();
