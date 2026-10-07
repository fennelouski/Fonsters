"""Check authored PCM cues and the actual built app resources without device recording."""
import hashlib, json, struct, wave
from pathlib import Path

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'docs/prototype/sound-manifest.json').read_text())
resources = root / '.prototype-build/Build/Products/Debug/Fonsters.app/Contents/Resources'
assert len(manifest) == 15
assert len({item['sha256'] for item in manifest}) == 15
for item in manifest:
    source = root / 'Fonsters/Playroom/Sounds' / item['file']
    assert hashlib.sha256(source.read_bytes()).hexdigest() == item['sha256']
    assert (resources / item['file']).read_bytes() == source.read_bytes()
    with wave.open(str(source), 'rb') as sound:
        assert sound.getnchannels() == 1 and sound.getsampwidth() == 2
        duration = sound.getnframes() / sound.getframerate()
        assert abs(duration - item['duration']) < .001 and .1 < duration < 1.1
        data = sound.readframes(sound.getnframes())
        samples = struct.unpack('<' + 'h' * (len(data) // 2), data)
        assert .01 < max(map(abs, samples)) / 32768 < .3
        assert abs(samples[0]) < 10 and abs(samples[-1]) < 10
print('PASS: 15 distinct authored mono PCM WAV cues, bounded duration/peak, silent endpoints, provenance hashes, and identical bundled resources.')
