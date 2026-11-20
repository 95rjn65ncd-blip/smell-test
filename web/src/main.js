// Smell Test for Chrome. Same flow and rules as the iPhone app:
// 1. Every check runs on this computer only (Firebase AI Logic, InferenceMode.ONLY_ON_DEVICE: no cloud fallback).
// 2. A second opinion is offered only on doubt (the shared escalation rules), never on model confidence.
// 3. The Privacy Shield removes personal details; the visitor sees and edits exactly what will be sent.
// 4. Only approved text goes to HybridModel-style PREFER_IN_CLOUD (Gemini, with on-device fallback).
import { initializeApp } from 'firebase/app';
import { initializeAppCheck, ReCaptchaEnterpriseProvider } from 'firebase/app-check';
import { getAI, getGenerativeModel, GoogleAIBackend, InferenceMode } from 'firebase/ai';
import { getRemoteConfig, fetchAndActivate, getValue } from 'firebase/remote-config';
import * as core from './core.js';
import { RECAPTCHA_ENTERPRISE_SITE_KEY } from './appcheck-site-key.js';

const $ = (id) => document.getElementById(id);
const els = {
  message: $('message'), check: $('check'), samples: $('samples'), status: $('status'), result: $('result'),
  second: $('second'), modelStatus: $('model-status'), shield: $('shield'), shieldText: $('shield-text'),
  shieldCounts: $('shield-counts'), shieldNote: $('shield-note'), shieldWarning: $('shield-warning'),
  shieldSend: $('shield-send'), shieldCancel: $('shield-cancel'),
};

// Made-up messages (people, companies and links are invented), same as the iPhone app's samples.
const SAMPLES = [
  'ParcelPoint: your package is on hold at our depot. Pay the $1.99 redelivery fee within 12 hours at parcelpoint-redelivery.top or it will be returned.',
  "Hi Mum, it's Jess. This is my new number, my old phone broke. Can you message me on WhatsApp here instead? Need to ask you something quickly x",
  'BrightBank Alert: unusual sign-in detected on your account. Verify your identity now at brightbank-secure-login.net or your account will be locked today.',
];
const NOT_SURE_SUMMARY = "This computer thought this might be a scam, but isn't sure.";

const state = { ai: null, settings: { ...core.DEFAULT_SETTINGS }, onDevice: 'checking', checkedText: '', firstVerdict: null, cloudReady: false };

// ---------- Firebase ----------

async function startFirebase() {
  // Firebase Hosting serves this project's web config here, so it isn't kept in the repo.
  const config = await fetch('/__/firebase/init.json', { cache: 'no-store' }).then((r) => (r.ok ? r.json() : null)).catch(() => null);
  if (!config) throw new Error('Firebase config missing');
  const app = initializeApp(config);
  if (location.hostname === 'localhost' || location.hostname === '127.0.0.1') {
    // Debug provider for local testing only: Chrome's console shows a token to register in App Check.
    // Never commit or paste that token anywhere.
    self.FIREBASE_APPCHECK_DEBUG_TOKEN = true;
  }
  if (RECAPTCHA_ENTERPRISE_SITE_KEY) {
    initializeAppCheck(app, { provider: new ReCaptchaEnterpriseProvider(RECAPTCHA_ENTERPRISE_SITE_KEY), isTokenAutoRefreshEnabled: true });
    state.cloudReady = true;
  }
  state.ai = getAI(app, { backend: new GoogleAIBackend(), useLimitedUseAppCheckTokens: true });
  loadSettings(app);
}

/** Remote Config, validated like the iPhone's Settings.from(); built-in defaults until a fetch works. */
async function loadSettings(app) {
  try {
    const rc = getRemoteConfig(app);
    rc.settings.minimumFetchIntervalMillis = 60 * 60 * 1000;
    await fetchAndActivate(rc);
    const model = getValue(rc, 'cloud_model').asString().trim();
    if (/^gemini-[a-z0-9.\-]{1,40}$/.test(model)) state.settings.cloudModel = model;
    const enabled = getValue(rc, 'second_opinion_enabled').asString().toLowerCase();
    if (enabled === 'false') state.settings.secondOpinionEnabled = false;
    if (enabled === 'true') state.settings.secondOpinionEnabled = true;
    const min = parseInt(getValue(rc, 'min_warning_signs').asString(), 10);
    if (min >= 1 && min <= 6) state.settings.minWarningSigns = min;
    const patterns = getValue(rc, 'current_scam_patterns').asString();
    if (patterns) state.settings.currentPatterns = patterns.split('\n').map((p) => p.trim()).filter((p) => p && p.length <= 120).slice(0, 5);
  } catch { /* keep defaults */ }
}

// ---------- On-device model status ----------

async function refreshOnDevice() {
  if (typeof self.LanguageModel === 'undefined') { state.onDevice = 'unavailable'; return showModelStatus(); }
  try { state.onDevice = await self.LanguageModel.availability(); } catch { state.onDevice = 'unavailable'; }
  showModelStatus();
}

function showModelStatus() {
  const s = els.modelStatus;
  if (state.onDevice === 'available') { s.hidden = true; return; }
  s.hidden = false;
  if (state.onDevice === 'downloadable' || state.onDevice === 'downloading') {
    s.innerHTML = '<strong>Chrome needs to download its built-in AI model once</strong> before it can check messages on this computer. It downloads the first time you tap Check it.';
  } else {
    s.innerHTML = "<strong>This browser can't check messages on its own.</strong> Checking on this computer needs desktop Chrome with its built-in AI model. You can still ask for a second opinion with personal details removed.";
  }
}

async function ensureOnDeviceModel(model) {
  if (state.onDevice === 'available') return true;
  if (state.onDevice !== 'downloadable' && state.onDevice !== 'downloading') return false;
  setStatus('<progress max="1" value="0" id="dl"></progress><p class="hint">Downloading Chrome\'s built-in model. This happens once.</p>');
  try {
    await model.initializeDeviceModel((p) => { const bar = $('dl'); if (bar) bar.value = p; });
    await refreshOnDevice();
  } catch { return false; }
  return state.onDevice === 'available';
}

// ---------- Rendering ----------

const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const setStatus = (html) => { els.status.innerHTML = html; };
const busy = (text) => setStatus(`<p><span class="spinner"></span>${esc(text)}</p>`);

function resultCard(result, { escalation, source, sentText }) {
  const reasons = result.reasons.length
    ? `<h3>Why</h3>${result.reasons.map((r) => `<p class="quote">“${esc(r.quote)}”</p><p class="why">${esc(r.why)}</p>`).join('')}` : '';
  const hint = escalation === 'warningWithoutCommonSigns' ? `<p class="hint">${esc(core.ESCALATION_TEXT[escalation])}</p>` : '';
  const recovery = `<details><summary>Already clicked, paid or shared?</summary>${core.RECOVERY.map((r) =>
    `<h3>${esc(r.label)}</h3><ol class="steps">${r.steps.map((s) => `<li>${esc(s)}</li>`).join('')}</ol>`).join('')}</details>`;
  const badge = source === 'cloud'
    ? '<span class="badge cloud">Checked in the cloud</span>'
    : '<span class="badge device">Checked on this computer</span>';
  const sent = sentText ? `<details><summary>What left this computer</summary><p class="sent">${esc(sentText)}</p></details>` : '';
  return `<article class="card ${result.verdict}">
    <h2><span class="dot" aria-hidden="true"></span>${esc(core.VERDICT_LABEL[result.verdict])}</h2>
    <p>${esc(result.summary)}</p>${hint}${reasons}
    <h3>What to do</h3><ol class="steps">${result.nextSteps.map((s) => `<li>${esc(s)}</li>`).join('')}</ol>
    ${recovery}${badge}${sent}</article>`;
}

function offerSecondOpinion(reason) {
  if (!state.settings.secondOpinionEnabled) {
    els.second.innerHTML = '<p class="quiet small">Second opinions are paused right now. Nothing was sent.</p>';
    return;
  }
  if (!state.cloudReady) {
    els.second.innerHTML = '<p class="quiet small">Second opinions aren\'t set up on this site yet. Nothing was sent.</p>';
    return;
  }
  const notice = reason && reason !== 'warningWithoutCommonSigns' && reason !== 'modelNotSure'
    ? `<p class="hint">${esc(core.ESCALATION_TEXT[reason])}</p>` : '';
  els.second.innerHTML = `${notice}<button class="primary" id="second-btn">Get a second opinion</button>`;
  $('second-btn').addEventListener('click', prepareSecondOpinion);
}

// ---------- Check ----------

async function check() {
  const text = els.message.value.trim();
  if (!text) return;
  state.checkedText = text;
  state.firstVerdict = null;
  els.result.innerHTML = ''; els.second.innerHTML = ''; els.samples.hidden = true;
  els.check.disabled = true;
  try {
    const model = getGenerativeModel(state.ai, { mode: InferenceMode.ONLY_ON_DEVICE });
    const ready = await ensureOnDeviceModel(model);
    const pre = core.preCheck(text, ready, state.settings.currentPatterns);
    if (pre) {
      setStatus(`<div class="notice"><strong>Not checked on this computer</strong><p>${esc(core.ESCALATION_TEXT[pre])} Nothing was sent anywhere.</p></div>`);
      offerSecondOpinion(pre);
      return;
    }
    busy('Checking on this computer…');
    let raw;
    try {
      const response = await model.generateContent(core.prompt(text, state.settings.currentPatterns));
      raw = response.response.text();
    } catch {
      setStatus('');
      els.result.innerHTML = '<div class="notice"><strong>Couldn\'t check</strong><p>This computer couldn\'t give a clear answer on this one. Nothing was sent anywhere.</p></div>';
      offerSecondOpinion('onDeviceCouldNotAnswer');
      return;
    }
    let parsed;
    try { parsed = core.parse(raw, text); } catch {
      setStatus('');
      els.result.innerHTML = '<div class="notice"><strong>Couldn\'t check</strong><p>Couldn\'t check this one. Try again.</p></div>';
      return;
    }
    const first = core.firstPass(parsed, text, state.settings.minWarningSigns, NOT_SURE_SUMMARY);
    state.firstVerdict = first.result.verdict;
    setStatus('');
    els.result.innerHTML = resultCard(first.result, { escalation: first.escalation, source: 'device' });
    if (first.escalation) offerSecondOpinion(first.escalation);
  } catch {
    // Never show a made-up verdict.
    setStatus('');
    els.result.innerHTML = '<div class="notice"><strong>Couldn\'t check</strong><p>Couldn\'t check this one. Try again.</p></div>';
  } finally {
    els.check.disabled = !els.message.value.trim();
  }
}

// ---------- Second opinion ----------

let currentPreview = null;

async function prepareSecondOpinion() {
  busy('Removing personal details on this computer…');
  els.second.innerHTML = '';
  const names = await findNamesOnDevice(state.checkedText);
  currentPreview = core.shieldPreview(state.checkedText, names);
  setStatus('');
  showShield(currentPreview, null);
}

async function findNamesOnDevice(text) {
  if (state.onDevice !== 'available') return null;
  try {
    const model = getGenerativeModel(state.ai, { mode: InferenceMode.ONLY_ON_DEVICE });
    const response = await model.generateContent(core.namePrompt(text));
    return core.parseNames(response.response.text());
  } catch { return null; }
}

const KIND_NAMES = { EMAIL: 'email address', LINK: 'link detail', SSN: 'Social Security number', CARD: 'card number', PHONE: 'phone number', ADDRESS: 'street address', ACCOUNT: 'account number', CODE: 'code', NAME: 'name' };

function showShield(preview, note) {
  els.shieldText.value = preview.text;
  const parts = core.KINDS.filter((k) => preview.counts[k] > 0).map((k) => `${preview.counts[k]} ${KIND_NAMES[k]}${preview.counts[k] === 1 ? '' : 's'}`);
  els.shieldCounts.textContent = parts.length ? `Removed: ${parts.join(', ')}` : 'No personal details were found.';
  els.shieldWarning.hidden = preview.namesChecked;
  els.shieldNote.hidden = !note;
  els.shieldNote.textContent = note ?? '';
  if (!els.shield.open) els.shield.showModal();
}

els.shield.addEventListener('close', () => {
  if (els.shield.returnValue !== 'send') { els.second.innerHTML = ''; offerSecondOpinion(null); return; }
  let approved;
  try {
    approved = core.approve(els.shieldText.value, currentPreview.namesChecked);
  } catch (e) {
    if (e.kind === 'stillHasDetails') { showShield(e.preview, 'More personal details were removed. Check the text again, then tap Send.'); return; }
    showShield(currentPreview, "There's nothing to send.");
    return;
  }
  sendSecondOpinion(approved);
});

/** Only approved text reaches the cloud-capable model. */
async function sendSecondOpinion(approved) {
  if (!core.isApproved(approved)) return;
  busy('Getting a second opinion…');
  try {
    const model = getGenerativeModel(state.ai, { mode: InferenceMode.PREFER_IN_CLOUD, inCloudParams: { model: state.settings.cloudModel } });
    const response = await model.generateContent(core.prompt(approved.text, state.settings.currentPatterns));
    const result = core.parse(response.response.text(), approved.text);
    const source = response.response.inferenceSource === 'on_device' ? 'device' : 'cloud';
    setStatus('');
    const changed = state.firstVerdict && state.firstVerdict !== result.verdict
      ? `<p class="hint">This computer said ${esc(core.VERDICT_LABEL[state.firstVerdict])}. The second opinion says ${esc(core.VERDICT_LABEL[result.verdict])}.</p>` : '';
    els.second.innerHTML = `<h2 style="margin-top:24px">Second opinion</h2>${changed}${resultCard(result, { source, sentText: approved.text })}`;
  } catch {
    setStatus('');
    els.second.innerHTML = '<div class="notice"><strong>No second opinion</strong><p>Couldn\'t get a second opinion. Nothing else was sent. Try again.</p></div>';
  }
}

// ---------- Wiring ----------

els.message.addEventListener('input', () => {
  els.check.disabled = !els.message.value.trim();
  if (!els.message.value.trim()) { els.samples.hidden = false; els.result.innerHTML = ''; els.second.innerHTML = ''; }
});
els.check.addEventListener('click', check);
els.samples.addEventListener('click', (e) => {
  const i = e.target.closest('[data-sample]')?.dataset.sample;
  if (i === undefined) return;
  els.message.value = SAMPLES[Number(i)];
  els.check.disabled = false;
});

refreshOnDevice();
startFirebase().catch(() => {
  setStatus('<div class="notice"><strong>Smell Test isn\'t set up here</strong><p>The Firebase web config couldn\'t be loaded.</p></div>');
});
