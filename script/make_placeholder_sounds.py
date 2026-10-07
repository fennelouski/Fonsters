"""Original procedural prototype cues; these are not ElevenLabs-generated assets."""
import math, wave, struct, json, hashlib
from pathlib import Path
root = Path(__file__).resolve().parents[1]
out = root / 'Fonsters/Playroom/Sounds'
out.mkdir(parents=True, exist_ok=True)
specs = {'greet': ([580,760,690],.65), 'play': ([620,840,680,940],.8),
         'rest': ([460,340,260],.9), 'blink': ([900,660],.24), 'look': ([450,590],.36)}
manifest=[]
for category,(notes,duration) in specs.items():
 for variant in range(3):
  samples=[]; sr=22050; pitch=[.88,1,1.13][variant]
  for i in range(int(sr*duration)):
   t=i/sr; segment=min(len(notes)-1,int(t/duration*len(notes)))
   local=(t/duration*len(notes))%1
   env=math.sin(math.pi*local)**2
   f=notes[segment]*pitch*(1+.012*math.sin(t*39))
   # Soft rounded chirp with a second harmonic, never a startling transient.
   v=.20*env*(math.sin(2*math.pi*f*t)+.18*math.sin(4*math.pi*f*t))
   v*=min(1,t/.012,(duration-t)/.02)
   samples.append(struct.pack('<h',int(max(-1,min(1,v))*32767)))
  filename=f'fonster_{category}_{variant}.wav'
  with wave.open(str(out/filename),'wb') as wav:
   wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(sr);wav.writeframes(b''.join(samples))
  manifest.append({'id':f'{category}-{variant}','event':category,'file':filename,'duration':duration,'source':'original-procedural-placeholder','license':'project-original','gain':.55,'sha256':hashlib.sha256((out/filename).read_bytes()).hexdigest()})
(root/'docs/prototype/sound-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(f'Created {len(manifest)} original, offline placeholder cues')
