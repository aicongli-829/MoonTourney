import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { dispatch_json } from '../dist/engine.mjs';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const cli = join(root, 'dist/moontourney.mjs');
function run(...args) {
  return spawnSync(process.execPath, [cli, ...args], { cwd: root, encoding: 'utf8' });
}
function ok(...args) {
  const result = run(...args);
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim();
}
const temporary = mkdtempSync(join(tmpdir(), 'moontourney-smoke-'));
try {
  assert.match(ok('help'), /Create|Generate a competition/);
  assert.equal(JSON.parse(ok('presets')).presets.length, 10);
  const event = join(temporary, 'event.json');
  ok('create', 'examples/badminton-cup.json', event);
  const initial = JSON.parse(readFileSync(event, 'utf8'));
  assert.equal(initial.participants.length, 6);
  assert.equal(initial.results.length, 0);
  const updated = join(temporary, 'updated.json');
  ok('record', event, 'examples/badminton-result.json', updated);
  const played = JSON.parse(readFileSync(updated, 'utf8'));
  assert.equal(played.results.length, 1);
  assert.equal(played.results[0].home, 2);
  assert.equal(JSON.parse(readFileSync(event, 'utf8')).results.length, 0);
  assert.ok(JSON.parse(ok('inspect', updated)).fixtures.some(f => f.state === 'finished'));
  assert.match(ok('export', updated, 'fixtures-csv'), /fixture,stage,round/);
  assert.match(ok('schedule', updated, 'examples/schedule.json'), /fixture,court,start_minutes,end_minutes/);
  assert.notEqual(run('create', 'examples/badminton-cup.json', event).status, 0, 'Refuse overwrite');
  const malformed = join(temporary, 'bad.json');
  writeFileSync(malformed, '{broken');
  assert.notEqual(run('create', malformed).status, 0);
  assert.notEqual(run('unknown').status, 0);
  const envelope = JSON.parse(dispatch_json(JSON.stringify({ action: 'series', rules: 'basketball', bestOf: 3, games: [{ fixtureId: 'a', home: 100, away: 90 }, { fixtureId: 'b', home: 105, away: 101 }] })));
  assert.equal(envelope.ok, true);
  assert.equal(envelope.data.complete, true);
  assert.equal(envelope.data.winnerSide, 1);
  const homeAway = JSON.parse(ok('create', 'examples/football-home-away-groups.json'));
  assert.equal(homeAway.format, 'groups-double');
  assert.equal(homeAway.fixtures.length, 24);
  const swissPlayoff = JSON.parse(ok('create', 'examples/chess-swiss-playoff.json'));
  assert.equal(swissPlayoff.format, 'swiss-playoff');
  assert.equal(swissPlayoff.swissRounds, 3);
  assert.equal(swissPlayoff.fixtures.length, 4);
  assert.equal(JSON.parse(dispatch_json(JSON.stringify({ action: 'inspect', tournament: swissPlayoff }))).ok, true);
  const communityLeague = JSON.parse(ok('create', 'examples/community-league-playoff.json'));
  assert.equal(communityLeague.format, 'league-playoff');
  assert.equal(communityLeague.fixtures.length, 28);
  assert.equal(communityLeague.qualifiers, 4);
  assert.equal(JSON.parse(dispatch_json(JSON.stringify({ action: 'advance', tournament: communityLeague }))).ok, false);
  let scoredLeague = communityLeague;
  for (const fixture of communityLeague.fixtures) {
    const reply = JSON.parse(dispatch_json(JSON.stringify({
      action: 'record', tournament: scoredLeague,
      result: { fixtureId: fixture.id, home: 1, away: 0 }
    })));
    assert.equal(reply.ok, true, reply.error);
    scoredLeague = reply.data.tournament;
  }
  const advancedLeague = JSON.parse(dispatch_json(JSON.stringify({ action: 'advance', tournament: scoredLeague })));
  assert.equal(advancedLeague.ok, true, advancedLeague.error);
  assert.equal(advancedLeague.data.tournament.fixtures.filter(f => f.stage === 'knockout').length, 3);
  assert.deepEqual(advancedLeague.data.tables.map(table => table.stage), ['league']);
  assert.equal(advancedLeague.data.champion, null);
  const footballSeason = JSON.parse(ok('create', 'examples/football-league-home-away.json'));
  assert.equal(footballSeason.format, 'league-double-playoff');
  assert.equal(footballSeason.fixtures.length, 30);
  const emptyArchive = join(temporary, 'archive-empty.json');
  const springArchive = join(temporary, 'archive-spring.json');
  const summerArchive = join(temporary, 'archive-summer.json');
  const communityEvent = join(temporary, 'community-event.json');
  ok('season-new', 'Community 2026', emptyArchive);
  ok('create', 'examples/community-league-playoff.json', communityEvent);
  ok('season-add', emptyArchive, communityEvent, 'Spring 2026', springArchive);
  ok('season-clone', springArchive, 'season-1', 'Summer 2026', summerArchive);
  const archive = JSON.parse(readFileSync(summerArchive, 'utf8'));
  assert.equal(archive.seasons.length, 2);
  assert.equal(archive.seasons[1].tournament.results.length, 0);
  const summerEvent = join(temporary, 'summer-event.json');
  const summerReseeded = join(temporary, 'summer-reseeded.json');
  const updatedArchive = join(temporary, 'archive-updated.json');
  ok('season-extract', summerArchive, 'season-2', summerEvent);
  ok('roster', summerEvent, 'examples/summer-entrants.json', summerReseeded);
  ok('season-update', summerArchive, 'season-2', summerReseeded, updatedArchive);
  const withRoster = JSON.parse(readFileSync(updatedArchive, 'utf8'));
  assert.equal(withRoster.seasons[1].tournament.participants[7].name, 'Jade');
  assert.equal(withRoster.seasons[0].tournament.participants[7].name, 'Halo');
  assert.equal(JSON.parse(ok('season-list', summerArchive)).seasons.length, 2);
  assert.match(ok('season-export', summerArchive, 'seasons-csv'), /Spring 2026/);
  assert.match(ok('season-export', summerArchive, 'history-csv'), /seasons_entered/);
  assert.equal(JSON.parse(ok('season-remove', summerArchive, 'season-2')).seasons.length, 1);
  assert.notEqual(run('season-new', 'Other', emptyArchive).status, 0, 'Refuse archive overwrite');
  console.log('CLI / engine smoke: passed (commands, league advancement, examples, safeguards, series).');
} finally {
  // Only delete the test-owned directory returned by mkdtemp, never user input.
  rmSync(temporary, { recursive: true, force: true });
}
