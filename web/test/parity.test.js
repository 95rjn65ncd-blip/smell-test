// The Chrome version must give the same answers as the iPhone app's Swift rules.
// Fixtures are written by the Swift code: EXPORT_WEB_FIXTURES=1 swift test --filter ExportWebFixtures
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fixtures from './fixtures/parity.json' with { type: 'json' };
import * as core from '../src/core.js';

for (const [i, c] of fixtures.messages.entries()) {
  test(`message ${i}: redactor, scanner, length, shield match Swift`, () => {
    const r = core.redact(c.message);
    assert.equal(r.text, c.redacted);
    assert.deepEqual(r.counts, c.counts);
    assert.deepEqual([...core.scan(c.message)].sort(), c.signals);
    assert.equal(core.fitsOnDevice(c.message), c.fits);
    const p = core.shieldPreview(c.message, fixtures.names);
    assert.equal(p.text, c.preview);
    assert.deepEqual(p.counts, c.previewCounts);
  });
}

for (const [i, c] of fixtures.parser.entries()) {
  test(`parser case ${i} matches Swift`, () => {
    if (c.error) {
      assert.throws(() => core.parse(c.output, c.message), (e) => e.kind === c.error);
      return;
    }
    const r = core.parse(c.output, c.message);
    assert.deepEqual(r, c.result);
    const first = core.firstPass(r, c.message);
    assert.equal(first.result.verdict, c.firstPassVerdict);
    assert.equal(first.escalation, c.escalation);
  });
}

test('approve re-checks edited text and only it can reach the cloud', () => {
  assert.throws(() => core.approve('  ', true), (e) => e.kind === 'empty');
  assert.throws(() => core.approve('call me on 555-201-7788', true), (e) => e.kind === 'stillHasDetails');
  const ok = core.approve('Hi Mum, new number', true);
  assert.equal(ok.text, 'Hi Mum, new number');
  assert.ok(core.isApproved(ok));
  assert.ok(!core.isApproved({ text: 'Hi Mum' }));
});
