'use strict';
const fs = require('node:fs/promises');
const path = require('node:path');
const { LandmarkService } = require('./service');
// Operator-controlled named PUBLIC areas only; no live user location input.
const DEMO = { id: 'zaanse-schans', name: 'Zaanse Schans and Zaandijk', bounds: { south:52.469, west:4.800, north:52.480, east:4.827 } };
async function main() {
  const service = new LandmarkService({ directory: path.resolve('.prototype-build/landmarks'), enabled: true });
  const snapshot = await service.snapshot(DEMO);
  if (snapshot.coverage.status === 'unknown') throw new Error(snapshot.delivery.reason);
  const output = path.resolve('Fonsters/Playroom/Resources/MappedWorldDemo.json');
  await fs.mkdir(path.dirname(output), { recursive: true });
  // Strip local delivery info; provenance, license and source geometry stay bundled.
  delete snapshot.delivery; await fs.writeFile(output, JSON.stringify(snapshot, null, 2) + '\n');
  console.log(JSON.stringify({ output, fetchedAt:snapshot.fetchedAt, counts:Object.fromEntries(['windmill','playground','waterway'].map(k => [k,snapshot.features.filter(f=>f.kind===k).length])) }));
}
if (require.main === module) main().catch(e => { console.error(e.message); process.exitCode=1; });
module.exports = { DEMO };
