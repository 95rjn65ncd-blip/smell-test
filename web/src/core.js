// Port of Packages/SmellTestCore (Swift) for the Chrome version. Same rules, same order, same wording
// where the wording isn't about the device. Parity with Swift is checked by test/parity.test.js against
// fixtures that the Swift code itself writes (benchmark: `swift run export-fixtures`).
// No network code in this file.

import generated from './generated/prompt.json' with { type: 'json' };

// ---------- Verdicts ----------

export const VERDICTS = ['scam', 'likely_scam', 'not_sure', 'no_red_flags'];
export const VERDICT_LABEL = {
  scam: 'Scam',
  likely_scam: 'Likely scam',
  not_sure: 'Not sure',
  no_red_flags: 'No red flags found',
};
export const isWarning = (v) => v === 'scam' || v === 'likely_scam';
export const SCAM_TYPES = generated.scamTypes;

// ---------- Prompt (text generated from Swift, so it's identical) ----------

export const PROMPT_VERSION = generated.version;
const ON_DEVICE_WINDOW = 4096;
const RESERVED_FOR_ANSWER = 700;
const MAX_MESSAGE_TOKENS = 1800;

const chars = (s) => Array.from(s).length;
export const estimatedTokens = (text) => Math.ceil(chars(text) / 3);

export function instructions(currentPatterns = []) {
  let text = generated.instructions;
  if (currentPatterns.length > 0) {
    text += '\n\nScams going around right now:\n' + currentPatterns.slice(0, 5).map((p) => `- ${p}`).join('\n');
  }
  return text;
}

export function prompt(message, currentPatterns = []) {
  return `${instructions(currentPatterns)}\n\n<<<MESSAGE\n${message}\nMESSAGE>>>`;
}

export function fitsOnDevice(message, currentPatterns = []) {
  const total = estimatedTokens(instructions(currentPatterns)) + estimatedTokens(message) + RESERVED_FOR_ANSWER;
  return estimatedTokens(message) <= MAX_MESSAGE_TOKENS && total <= ON_DEVICE_WINDOW;
}

// ---------- Fixed red-flag patterns ----------

const SIGNAL_PATTERNS = {
  urgency: [String.raw`within \d+ (hours?|minutes?)`, String.raw`\b(act now|immediately|final notice|last chance|urgent|expires? today)\b`,
    String.raw`\b(suspended|locked|deactivated|on hold)\b`],
  paymentPressure: [String.raw`\bgift ?cards?\b`, String.raw`\b(wire|bitcoin|crypto|usdt)\b`, String.raw`\b(pay|send)\b.{0,30}\$\d`,
    String.raw`\b(fee|fine|penalty|unpaid)\b`],
  credentialRequest: [String.raw`\b(verify|confirm) (your|the) (account|identity|address|details|information)\b`,
    String.raw`\b(password|ssn|social security|routing|pin)\b`, String.raw`\b(reply|send|share).{0,20}\bcode\b`],
  suspiciousLink: [String.raw`https?://[^\s/]+\.(top|xyz|help|info|click|live|shop|icu|buzz|cam|rest)\b`,
    String.raw`https?://[^\s/]*-(verify|secure|login|pay|support|redelivery|tolls?)[^\s/]*`],
  impersonation: [String.raw`\b(fraud (dept|department)|security team|irs|tax office|customs|police|sheriff)\b`,
    String.raw`\b(grandma|grandpa|mom|dad)\b.{0,40}\b(jail|hospital|accident|arrested)\b`],
};

export function scan(text) {
  const found = new Set();
  for (const [signal, list] of Object.entries(SIGNAL_PATTERNS)) {
    if (list.some((p) => new RegExp(p, 'i').test(text))) found.add(signal);
  }
  return found;
}

export const DEFAULT_SETTINGS = { cloudModel: 'gemini-3.5-flash-lite', secondOpinionEnabled: true, minWarningSigns: 2, currentPatterns: [] };

// ---------- Escalation ----------

export const ESCALATION_RULES_VERSION = '2';

/** Explanations for the web. Same meaning as the iPhone's, with "this computer" for "your iPhone". */
export const ESCALATION_TEXT = {
  modelNotSure: "This computer wasn't sure about this one.",
  patternsDisagree: 'This computer found no red flags, but the message has common warning signs.',
  tooLongForOnDevice: 'This message is too long to check on this computer.',
  onDeviceUnavailable: "This browser can't check messages on its own.",
  onDeviceCouldNotAnswer: "This computer couldn't give a clear answer on this one.",
  warningWithoutCommonSigns: "This message doesn't have the usual warning signs, so a second opinion may help.",
};

export function preCheck(message, onDeviceAvailable, currentPatterns = []) {
  if (!onDeviceAvailable) return 'onDeviceUnavailable';
  if (!fitsOnDevice(message, currentPatterns)) return 'tooLongForOnDevice';
  return null;
}

export function afterOnDevice(result, message, minWarningSigns = DEFAULT_SETTINGS.minWarningSigns) {
  if (result.verdict === 'not_sure') return 'modelNotSure';
  if (result.verdict === 'no_red_flags' && scan(message).size >= minWarningSigns) return 'patternsDisagree';
  return null;
}

/** `notSureSummary` is the device-specific wording (the iPhone says "Your iPhone thought..."). */
export function firstPass(result, message, minWarningSigns = DEFAULT_SETTINGS.minWarningSigns,
  notSureSummary = "Your iPhone thought this might be a scam, but isn't sure.") {
  if (isWarning(result.verdict) && scan(message).size === 0) {
    return {
      result: { verdict: 'not_sure', scamType: result.scamType, summary: notSureSummary, reasons: result.reasons, nextSteps: safeSteps('not_sure') },
      escalation: 'warningWithoutCommonSigns',
    };
  }
  return { result, escalation: afterOnDevice(result, message, minWarningSigns) };
}

// ---------- Fixed steps ----------

const CONTACT_PATTERNS = [
  String.raw`https?://\S+`,
  String.raw`\bwww\.\S+`,
  String.raw`\b[a-z0-9-]+(\.[a-z0-9-]+)*\.(com|net|org|gov|edu|io|co|us|uk|ca|info|top|xyz|help|click|live|shop|icu|buzz|cam|rest|app|site|online)\b`,
  String.raw`\S+@\S+\.\S+`,
  String.raw`\+?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}\b`,
  String.raw`\b\d{3}-\d{4}\b`,
];

function findContactDetails(text) {
  return CONTACT_PATTERNS.flatMap((p) => [...text.matchAll(new RegExp(p, 'gi'))].map((m) => m[0]));
}
const containsContactDetails = (text) => findContactDetails(text).length > 0;
const trimPunct = (s) => s.replace(/^[\p{P}]+|[\p{P}]+$/gu, '');
function hasInventedContactDetails(text, message) {
  const lower = message.toLowerCase();
  return findContactDetails(text).some((d) => !lower.includes(trimPunct(d.toLowerCase())));
}

export function safeSteps(verdict) {
  switch (verdict) {
    case 'scam':
    case 'likely_scam':
      return [
        "Don't tap links, reply, or call numbers in the message.",
        'If it claims to be someone you know, contact them using a number or app you already trust.',
        'Block the sender and delete the message.',
      ];
    case 'not_sure':
      return [
        "Don't tap links or share anything until you're sure.",
        'Contact the sender using a number or app you already trust, not one in the message.',
        'Ask someone you trust to take a look.',
      ];
    default:
      return [
        'If a later message asks for money or details, check it again.',
        'If anything feels off, contact the sender using a number you already know.',
        'Never share codes or passwords with anyone who contacts you.',
      ];
  }
}

export function safeSummary(verdict) {
  return {
    scam: 'This message shows several warning signs of a scam.',
    likely_scam: 'This message shows a warning sign of a scam.',
    not_sure: 'Something about this message is a little unusual.',
    no_red_flags: "We didn't find any of the usual warning signs.",
  }[verdict];
}

function replacingSteps(modelSteps, verdict, shouldReplace) {
  const fixed = safeSteps(verdict);
  const spares = fixed.filter((s) => !modelSteps.includes(s));
  return modelSteps.map((step) => (shouldReplace(step) ? (spares.length ? spares.shift() : fixed[0]) : step));
}

// ---------- Parser ----------

export class ParseError extends Error {
  constructor(kind) { super(kind); this.kind = kind; }
}

const MAX_REASONS = 3;
const MAX_FIELD = 400;

function clean(s) {
  const collapsed = String(s).split(/\s+/u).filter(Boolean).join(' ');
  return Array.from(collapsed).slice(0, MAX_FIELD).join('');
}

function normalize(s) {
  const folded = s.toLowerCase().normalize('NFKD').replace(/\p{M}/gu, '')
    .replace(/’/g, "'").replace(/‘/g, "'").replace(/“/g, '"').replace(/”/g, '"');
  const trimmed = folded.replace(/^["' .,!?…]+|["' .,!?…]+$/gu, '');
  return trimmed.split(/\s+/u).filter(Boolean).join(' ');
}

const containsQuote = (quote, message) => normalize(message).includes(normalize(quote));
export const mentionsCode = (text) => /\b(codes?|pins?|passcodes?|otps?)\b/i.test(text);

function copiedExampleSummary(summary, message) {
  const s = normalize(summary);
  const m = message.toLowerCase();
  return generated.exampleSummaries.some((ex) => normalize(ex.summary) === s && !ex.fitsIfMessageHas.some((w) => m.includes(w)));
}

/** First balanced {...} object, ignoring braces inside strings. */
export function extractJSONObject(text) {
  const start = text.indexOf('{');
  if (start < 0) return null;
  let depth = 0, inString = false, escaped = false;
  for (let i = start; i < text.length; i++) {
    const c = text[i];
    if (inString) {
      if (escaped) escaped = false;
      else if (c === '\\') escaped = true;
      else if (c === '"') inString = false;
    } else if (c === '"') inString = true;
    else if (c === '{') depth++;
    else if (c === '}') { depth--; if (depth === 0) return text.slice(start, i + 1); }
  }
  return null;
}

const RED_FLAG_TAG = /\s*\((red flags?|flags?|scam types?|types?) \d+((,| and| or) ?\d+)*\)/gi;

/** Model output -> validated result, or throws ParseError. Never fills in a verdict. */
export function parse(output, message) {
  const json = extractJSONObject(output);
  if (json === null) throw new ParseError('noJSON');
  let raw;
  try { raw = JSON.parse(json); } catch { throw new ParseError('malformedJSON'); }
  if (typeof raw !== 'object' || raw === null || typeof raw.verdict !== 'string') throw new ParseError('malformedJSON');

  const verdict = raw.verdict.trim().toLowerCase();
  if (!VERDICTS.includes(verdict)) throw new ParseError('unknownVerdict');
  const scamTypeRaw = String(raw.scam_type ?? 'none').trim().toLowerCase();
  if (!SCAM_TYPES.includes(scamTypeRaw)) throw new ParseError('unknownScamType');

  const modelSummary = clean(raw.summary ?? '');
  if (!modelSummary) throw new ParseError('missingSummary');
  const copiedExample = copiedExampleSummary(modelSummary, message);
  const summary = copiedExample ? safeSummary(verdict) : modelSummary;
  if (hasInventedContactDetails(summary, message)) throw new ParseError('inventedContactDetails');

  const reasons = (Array.isArray(raw.reasons) ? raw.reasons : [])
    .map((r) => (r && typeof r === 'object' ? r : {}))
    .map((r) => ({ quote: clean(typeof r.quote === 'string' ? r.quote : ''), why: clean((typeof r.why === 'string' ? r.why : '').replace(RED_FLAG_TAG, '')) }))
    .filter((r) => r.quote && r.why && containsQuote(r.quote, message))
    .filter((r) => !(mentionsCode(r.why) && !mentionsCode(message)))
    .slice(0, MAX_REASONS);
  if (reasons.some((r) => hasInventedContactDetails(r.why, message))) throw new ParseError('inventedContactDetails');
  if (isWarning(verdict) && reasons.length === 0) throw new ParseError('warningWithoutEvidence');

  const modelSteps = (Array.isArray(raw.next_steps) ? raw.next_steps : []).map(clean).filter(Boolean);
  if (modelSteps.length !== 3) throw new ParseError('wrongNumberOfSteps');
  let steps;
  if (verdict === 'not_sure' || copiedExample) {
    steps = safeSteps(verdict);
  } else {
    const offTopic = (step) => isWarning(verdict) && mentionsCode(step) && !mentionsCode(message);
    steps = replacingSteps(modelSteps, verdict, (s) => containsContactDetails(s) || offTopic(s));
  }
  return { verdict, scamType: verdict === 'no_red_flags' ? 'none' : scamTypeRaw, summary, reasons, nextSteps: steps };
}

// ---------- Redactor (Privacy Shield layer 1) ----------

export const KINDS = ['EMAIL', 'LINK', 'SSN', 'CARD', 'PHONE', 'ADDRESS', 'ACCOUNT', 'CODE', 'NAME'];
const label = (k) => `[${k}]`;

export const RELATIONSHIP_WORDS = generated.relationshipWords;

export function redact(input) {
  let text = input;
  const counts = {};
  const add = (k, n) => { counts[k] = (counts[k] ?? 0) + n; };
  const apply = (pattern, kind, { flags = 'gi', template } = {}) => {
    const re = new RegExp(pattern, flags);
    const n = [...text.matchAll(re)].length;
    if (n === 0) return;
    add(kind, n);
    text = text.replace(re, template ?? label(kind));
  };

  apply(String.raw`[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}`, 'EMAIL');
  text = redactLinks(text, add);
  apply(String.raw`\b\d{3}-\d{2}-\d{4}\b`, 'SSN');
  apply(String.raw`\b(?:\d[ \-]?){12,18}\d\b`, 'CARD');
  apply(String.raw`(?<![\w$])(?:\+?1[\s.\-]?)?\(?\d{3}\)?[\s.\-]?\d{3}[\s.\-]?\d{4}\b`, 'PHONE');
  apply(String.raw`(?<![\w$])\+\d{1,3}(?:[\s.\-]?\d{2,4}){2,5}\b`, 'PHONE');
  apply(String.raw`\b\d{1,6}\s+(?:[A-Za-z0-9.]+\s+){0,3}(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Lane|Ln|Drive|Dr|Court|Ct|Way|Place|Pl|Terrace|Ter|Circle|Cir|Parkway|Pkwy|Highway|Hwy)\b\.?(?:,?\s*(?:Apt|Apartment|Unit|Suite|Ste|#)\.?\s*[A-Za-z0-9\-]+)?`, 'ADDRESS');
  apply(String.raw`\b(ending(?:\s+in)?|acct\.?|account(?:\s+(?:no\.?|number))?|card)(\s*(?:#|no\.?|number|\.{2,}|[•*x]+)?\s*)\d{4,}\b`,
    'ACCOUNT', { template: '$1$2[ACCOUNT]' });
  apply(String.raw`(?<![\w$€£.,])\d{9,17}(?![\w.,]\d)`, 'ACCOUNT');
  apply(String.raw`\b(?=[A-Z0-9]*\d[A-Z0-9]*\d)(?=[A-Z0-9]*[A-Z])[A-Z0-9]{6,24}\b`, 'CODE');
  apply(String.raw`(?<![\w$€£.,])\d{4,8}(?![\w%]|[.,]\d)`, 'CODE');
  const family = [...RELATIONSHIP_WORDS].sort().join('|');
  apply(String.raw`\b(Dear|Hi|Hello|Hey)(\s+(?:Mr\.?|Mrs\.?|Ms\.?|Dr\.?)?\s*)(?!(?:Mr|Mrs|Ms|Dr)\b)(?!(?i:` + family + String.raw`)\b)[A-Z][a-z'\-]+(?:\s+[A-Z][a-z'\-]+)?`,
    'NAME', { flags: 'g', template: '$1$2[NAME]' });
  return { text, counts };
}

export const totalRedactions = (counts) => Object.values(counts).reduce((a, b) => a + b, 0);

function redactLinks(input, add) {
  return input.replace(/\b(?:https?:\/\/|www\.)[^\s<>"']+/gi, (original) => {
    const m = original.match(/[.,;:!?)]*$/);
    const trailing = m ? m[0] : '';
    const link = original.slice(0, original.length - trailing.length);
    const kept = safeLink(link);
    if (kept !== link) add('LINK', 1);
    return kept + trailing;
  });
}

// Mirrors Foundation's URLComponents: host without userinfo or port, decoded path, query/fragment flagged.
export function safeLink(link) {
  const isWww = link.toLowerCase().startsWith('www.');
  const withScheme = isWww ? 'https://' + link : link;
  const m = withScheme.match(/^([a-z][a-z0-9+.\-]*):\/\/([^/?#]*)([^?#]*)(\?[^#]*)?(#.*)?$/i);
  if (!m || /[^\x21-\x7e]/.test(withScheme) || /[{}|\\^`\[\]]/.test(withScheme.replace(/^[^:]+:\/\/\[[^\]]*\]/, ''))) return label('LINK');
  const [, schemeRaw, authority, pathRaw, query, fragment] = m;
  const host = authority.replace(/^.*@/, '').replace(/:\d*$/, '');
  if (!host) return label('LINK');
  let path;
  try { path = decodeURIComponent(pathRaw); } catch { return label('LINK'); }
  const scheme = isWww ? '' : `${schemeRaw}://`;
  const segments = path.split('/').filter((s) => s.length > 0);
  const safe = segments.map((seg) => {
    const digits = (seg.match(/\p{Nd}/gu) ?? []).length;
    return chars(seg) >= 16 || digits >= 4 || seg.includes('@') ? label('LINK') : seg;
  });
  let result = scheme + host;
  if (safe.length) result += '/' + safe.join('/');
  if (query !== undefined || fragment !== undefined) result += '?' + label('LINK');
  return result;
}

// ---------- Privacy Shield ----------

const isRelationshipWord = (w) => RELATIONSHIP_WORDS.includes(trimPunct(w.toLowerCase()));
const escapeRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

export function replaceNames(text, names) {
  const parts = new Set();
  for (const name of names) {
    const cleaned = trimPunct(name.trim()).trim();
    if (chars(cleaned) < 2) continue;
    const pieces = cleaned.split(' ').filter(Boolean);
    if (!pieces.some(isRelationshipWord)) parts.add(cleaned);
    for (const piece of pieces) if (chars(piece) >= 2 && !isRelationshipWord(piece)) parts.add(piece);
  }
  let result = text;
  let count = 0;
  for (const part of [...parts].sort((a, b) => chars(b) - chars(a))) {
    const re = new RegExp(String.raw`(?<![\w\[])` + escapeRe(part) + String.raw`(?![\w\]])`, 'gi');
    const n = [...result.matchAll(re)].length;
    if (n > 0) { count += n; result = result.replace(re, label('NAME')); }
  }
  return { text: result, count };
}

/** `names` from the on-device name pass, or null if it couldn't run (the UI then warns louder). */
export function shieldPreview(original, names) {
  const patterned = redact(original);
  let { text } = patterned;
  const counts = { ...patterned.counts };
  if (names) {
    const replaced = replaceNames(text, names);
    text = replaced.text;
    if (replaced.count > 0) counts.NAME = (counts.NAME ?? 0) + replaced.count;
  }
  return { text, counts, namesChecked: names !== null };
}

const approvedMark = Symbol('approved');

/** The cloud path only accepts what this returns. Throws {kind:'empty'} or {kind:'stillHasDetails', preview}. */
export function approve(shownText, namesChecked) {
  const trimmed = shownText.trim();
  if (!trimmed) throw { kind: 'empty' };
  const again = redact(trimmed);
  if (totalRedactions(again.counts) > 0) throw { kind: 'stillHasDetails', preview: { text: again.text, counts: again.counts, namesChecked } };
  return Object.freeze({ text: trimmed, [approvedMark]: true });
}

export const isApproved = (a) => !!a && a[approvedMark] === true;

export function namePrompt(text) {
  return generated.namePromptPrefix + text + generated.namePromptSuffix;
}

export function parseNames(output) {
  const start = output.indexOf('[');
  const end = output.lastIndexOf(']');
  if (start < 0 || end <= start) return null;
  try {
    const names = JSON.parse(output.slice(start, end + 1));
    return Array.isArray(names) && names.every((n) => typeof n === 'string') ? names : null;
  } catch { return null; }
}

// ---------- Recovery steps (fixed, never generated) ----------

export const RECOVERY = generated.recovery;
