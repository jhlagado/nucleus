// Development-only replay using an explicitly supplied built Triptych checkout.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = process.argv[2];
if (!root) throw Error('Usage: node examples/games/check-cpm.cjs TRIPTYCH_CHECKOUT');
const {TriptychCpu, CpmDisk} = require(path.resolve(root, 'dist/wasm/triptych_host_wasm.js'));
const site = path.resolve(root, 'dist/wasm-browser');
const manifest = JSON.parse(fs.readFileSync(path.join(site, 'deployment-manifest.json')));
const launch = manifest.directLaunches.launches.find(x => x.id === 'games');
const compiler = manifest.distribution.components.find(x => x.id === 'nucleus');
assert.equal(compiler.sha256, '1c047ac1ed5ff1c4e914321b66476b842a1b28cc0dfef4cfdb86f691ca037334');
const boot = fs.readFileSync(path.join(site, 'bootstrap-triptych-cpm-2m-n04-v1.bin'));
const a = fs.readFileSync(path.join(site, launch.image.asset));
function session(b) {
  const cpu = new TriptychCpu(boot);
  cpu.install_drive(0, a, false);
  cpu.install_drive(1, b, true);
  return {
    cpu,
    step(input, suffix) {
      assert(cpu.enqueue_serial_input(Buffer.from(input)));
      let text = '';
      for (let i = 0; i < 4000; i++) {
        cpu.run_slice(50000, 500000);
        text += Buffer.from(cpu.take_serial_output()).toString();
        if (text.endsWith(suffix)) return text;
      }
      throw Error(`Expected ${suffix}: ${text}`);
    }
  };
}
const disk = CpmDisk.create_two_mib();
for (const name of ['GUESS', 'MATCH23']) disk.add_import(name + '.NU', fs.readFileSync(path.join(__dirname, name + '.NU')));
const build = session(disk.export_candidate());
build.step('', 'A>'); build.step('B:\r', 'B>');
for (const name of ['GUESS', 'MATCH23']) {
  const output = build.step(`A:NUC ${name}.NU\r`, 'B>');
  assert(!/error|\?/.test(output), output);
}
const compiled = build.cpu.export_drive(1);
const files = new CpmDisk(compiled);
for (const name of ['GUESS', 'MATCH23']) console.log(name + '.COM', files.read_file(name + '.COM').length, 'bytes');
const guess = session(compiled);
guess.step('', 'A>'); guess.step('B:\r', 'B>'); guess.step('GUESS\r', 'Your guess? ');
for (const [key, expected] of [['1','Too low!'], ['9','Too high!'], ['x','Please type'], ['0','Please type']]) assert(guess.step(key, 'Your guess? ').includes(expected));
assert(guess.step('\r\n7', 'B>').includes('Correct!'));
const prompt = 'Your move (1-3)? ';
function play(keys, ending) {
  const game = session(compiled);
  game.step('', 'A>'); game.step('B:\r', 'B>');
  assert(game.step('MATCH23\r', prompt).includes('Matches left: 23'));
  for (const key of ['0','4','x']) assert(game.step(key, prompt).includes('Matches left: 23'));
  let remaining = 23, fallback = 1;
  for (let i = 0; i < keys.length; i++) {
    const take = Number(keys[i]);
    if (i === keys.length - 1) { assert(game.step(keys[i], 'B>').includes(ending)); break; }
    remaining -= take;
    let reply = (remaining - 1) % 4;
    if (!reply) reply = 1;
    remaining -= reply;
    const text = game.step(keys[i], prompt);
    assert(text.includes(`I take ${reply}\r\n`), text);
    assert(text.includes(`Matches left: ${remaining}\r\n`), text);
  }
  game.cpu.free();
}
play(['1','1','1','1','1','1','1'], 'I win!');
play(['2','3','3','3','3','3'], 'You win!');
play(['1','1','1','1','1','1','3'], 'I win!');
play(['q'], 'B>');
play(['Q'], 'B>');
console.log('PASS: both compiled games, guesses, invalid input, both outcomes, overtake and quit');
guess.cpu.free(); build.cpu.free(); files.free(); disk.free();
