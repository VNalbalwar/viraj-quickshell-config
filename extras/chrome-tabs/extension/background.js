// Notch tab bridge — runs inside Chrome.
//
// Chrome mixes every tab into ONE audio stream and reports ONE media session, so nothing outside the
// browser can tell which tabs are making sound. Chrome itself knows (tab.audible), so this extension
// reports those tabs to a tiny native helper (qs-chrome-host), which hands them to the Quickshell
// notch, and carries out mute / pause / play / focus requests coming back.

const HOST = "com.viraj.qs_tabs";

let port = null;
let timer = null;
const pausedByUs = new Set();   // tabs we paused: they stay listed (as paused) so they can be resumed

function send(msg) {
  try { if (port) port.postMessage(msg); } catch (e) { /* port is going away */ }
}

function snapshot() {
  chrome.tabs.query({}, (tabs) => {
    const out = [];
    for (const t of tabs) {
      if (!t.audible && !pausedByUs.has(t.id)) continue;
      out.push({
        id: t.id,
        windowId: t.windowId,
        title: t.title || "",
        url: t.url || "",
        favicon: t.favIconUrl || "",
        audible: !!t.audible,
        muted: !!(t.mutedInfo && t.mutedInfo.muted),
        paused: !t.audible && pausedByUs.has(t.id),
        active: !!t.active,
      });
    }
    send({ type: "tabs", browser: "Google Chrome", tabs: out });
  });
}

function schedule() {          // several events fire together; send one snapshot
  clearTimeout(timer);
  timer = setTimeout(snapshot, 120);
}

function setMedia(tabId, action) {
  // pause: remember which elements WE paused, so play only resumes those (never an ad's hidden video)
  chrome.scripting.executeScript({
    target: { tabId, allFrames: true },
    args: [action],
    func: (act) => {
      document.querySelectorAll("video, audio").forEach((m) => {
        if (act === "pause" && !m.paused) { m.pause(); m.dataset.qsPaused = "1"; }
        if (act === "play" && m.dataset.qsPaused) { m.play().catch(() => {}); delete m.dataset.qsPaused; }
      });
    },
  }).catch(() => {});
}

function onCommand(msg) {
  const id = msg.tabId;
  switch (msg.cmd) {
    case "mute":
      chrome.tabs.update(id, { muted: !!msg.muted }).then(schedule, schedule);
      break;
    case "pause":
      pausedByUs.add(id);
      setMedia(id, "pause");
      setTimeout(schedule, 400);
      break;
    case "play":
      pausedByUs.delete(id);
      setMedia(id, "play");
      setTimeout(schedule, 400);
      break;
    case "focus":
      chrome.tabs.update(id, { active: true }).then((t) => {
        if (t) chrome.windows.update(t.windowId, { focused: true });
      }).catch(() => {});
      break;
  }
}

function connect() {
  port = chrome.runtime.connectNative(HOST);
  port.onMessage.addListener(onCommand);
  port.onDisconnect.addListener(() => {
    port = null;
    void chrome.runtime.lastError;      // host not installed / not running: stay quiet, retry
    setTimeout(connect, 5000);
  });
  snapshot();
}

chrome.tabs.onUpdated.addListener((id, change) => {
  if ("audible" in change || "mutedInfo" in change || "title" in change || "favIconUrl" in change) schedule();
});
chrome.tabs.onRemoved.addListener((id) => { pausedByUs.delete(id); schedule(); });
chrome.tabs.onActivated.addListener(schedule);

connect();
