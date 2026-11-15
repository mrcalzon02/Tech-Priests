"""Original procedural machinery SFX. NumPy + ffmpeg; no borrowed recordings."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
import wave
import numpy as np

RATE=48000


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def noise(rng,n,low,high):
    spectrum=np.fft.rfft(rng.standard_normal(n));f=np.fft.rfftfreq(n,1/RATE)
    response=(1-np.exp(-(f/max(low,1))**4))*np.exp(-(f/high)**6)/np.maximum(f,20)**.28
    result=np.fft.irfft(spectrum*response,n=n);return result/max(np.std(result),1e-9)


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--out',required=True);ap.add_argument('--ffmpeg',default='ffmpeg');ap.add_argument('--baseline')
    args=ap.parse_args();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Retain previous authored audio')
    out.mkdir(parents=True);rng=np.random.default_rng(501783);records=[]
    def emit(name,signal,peak=.82,loop=False,plan=''):
        signal=signal-np.mean(signal);signal=np.tanh(signal*1.45)
        signal*=peak/max(abs(signal).max(),1e-9)
        path=out/(name+'.wav');pcm=np.round(signal*32767).astype('<i2')
        with wave.open(str(path),'wb') as handle:handle.setnchannels(1);handle.setsampwidth(2);handle.setframerate(RATE);handle.writeframes(pcm.tobytes())
        ogg=out/(name+'.ogg')
        subprocess.run([args.ffmpeg,'-hide_banner','-loglevel','error','-i',str(path),'-c:a','libvorbis','-q:a','6',str(ogg)],check=True)
        decoded=subprocess.run([args.ffmpeg,'-hide_banner','-loglevel','error','-i',str(ogg),'-f','f32le','-ac','1','-ar',str(RATE),'-'],capture_output=True,check=True).stdout
        samples=np.frombuffer(decoded,dtype='<f4');rms=float(np.sqrt(np.mean(samples**2)));highest=float(np.max(abs(samples)))
        if not np.isfinite(samples).all() or highest>=1 or rms<.005:raise RuntimeError('Decoded audio validity/headroom failure '+name)
        # A periodic waveform need not have equal first/last samples. Bound the
        # seam step against ordinary adjacent-sample steps rather than forcing
        # silence, which would create a rhythmic dip on every loop.
        step=float(abs(signal[0]-signal[-1]));ordinary=float(np.quantile(abs(np.diff(signal)),.999))
        if loop and step>max(.025,ordinary*1.4):raise RuntimeError('Loop discontinuity '+name)
        records.append(dict(name=name,seconds=len(signal)/RATE,sample_rate=RATE,channels=1,loop=loop,plan=plan,
            wav_sha256=sha(path),ogg_sha256=sha(ogg),decoded_rms=rms,decoded_rms_dbfs=20*math.log10(rms),decoded_peak=highest,
            loop_seam_step=step,ordinary_99_9_percent_step=ordinary))
    # Compressor: continuous dirty motor/gear bed plus cyclical loaded strokes,
    # hard valve flutter and metal housing resonances. Loudness is authored in
    # the sample and native gain/range, never in the user's OS volume setting.
    seconds=8;n=RATE*seconds;t=np.arange(n)/RATE
    low=noise(rng,n,22,440);chatter=noise(rng,n,650,6200);air=noise(rng,n,160,3600)
    motor=.16*np.sin(2*np.pi*48*t)+.075*np.sin(2*np.pi*96*t+.4)+.035*np.sin(2*np.pi*192*t)
    rough=.075*low*(.8+.2*np.sin(2*np.pi*6*t))
    rattle=.095*chatter*(.15+.85*np.maximum(0,np.sin(2*np.pi*27*t)+.15)**3)
    compressor=motor+rough+rattle
    for phase in (0,seconds/3,2*seconds/3):
        d=(t-phase)%seconds
        impact=(1-np.exp(-d/.0018))*np.exp(-d/.055)
        body=(1-np.exp(-d/.004))*np.exp(-d/.20)
        metal=sum(a*np.sin(2*np.pi*f*d)*np.exp(-d/decay) for a,f,decay in ((.24,137,.13),(.15,263,.09),(.11,517,.065),(.07,1103,.035)))
        compressor+=.38*impact*low+.25*body*np.sin(2*np.pi*57*d)+metal
        release=(t-phase-.14)%seconds;envelope=(1-np.exp(-release/.004))*np.exp(-release/.21)
        compressor+=.24*envelope*air+.13*envelope*chatter
    emit('compressor-working',compressor,loop=True,plan='Heavy motor rumble, 27Hz dry mechanical chatter, loaded three-phase body knocks, rattling metal resonances and short pressure chuffs. Eight-second periodic bed.')
    idle=.035*noise(rng,n,25,270)+.02*np.sin(2*np.pi*48*t)
    emit('compressor-idle',idle,peak=.24,loop=True,plan='Quiet powered-cabinet resonance; no working strokes or continuous discharge.')
    n2=int(RATE*1.8);q=np.arange(n2)/RATE;phase=2*np.pi*(18*q+17*q*q)
    start=(1-np.exp(-q/.025))*np.minimum(1,q/.30)*(.20*np.sin(phase)+.06*noise(rng,n2,80,2400))
    start+=.25*np.exp(-q/.035)*noise(rng,n2,350,3800);start*=np.minimum(1,(1.8-q)/.06)
    emit('compressor-start',start,peak=.78,plan='Contactor clack and heavy motor run-up into the working bed.')
    q=np.arange(int(RATE*2.0))/RATE;phase=2*np.pi*(48*q-9*q*q)
    stop=(.17*np.sin(phase)+.14*noise(rng,len(q),130,4200))*np.exp(-q/1.0)*(1-np.exp(-q/.006))*np.minimum(1,(2-q)/.08)
    emit('compressor-stop',stop,peak=.75,plan='Decelerating motor and short unloading bleed, then silence.')
    # Distinct quieter beds for the two already-built chain machines.
    n=RATE*4;t=np.arange(n)/RATE
    pump=.07*np.sin(2*np.pi*58*t)+.025*np.sin(2*np.pi*116*t)+.045*noise(rng,n,80,1000)
    water=noise(rng,n,350,4500)*(.045+.025*np.sin(2*np.pi*1.5*t)**2)
    emit('purifier-working',pump+water,peak=.52,loop=True,plan='Low pump motor with flowing water/filter burble; quieter than compressor.')
    rectifier=.065*np.sin(2*np.pi*100*t)+.022*np.sin(2*np.pi*200*t)+.012*np.sin(2*np.pi*400*t)
    cells=.025*noise(rng,n,450,5200)*(.6+.4*np.sin(2*np.pi*3*t)**2)
    emit('electrolyzer-working',rectifier+cells,peak=.43,loop=True,plan='Rectifier hum and restrained fine electrode/process fizz; no invented UI beeps.')
    baseline=None
    if args.baseline:
        raw=subprocess.run([args.ffmpeg,'-hide_banner','-loglevel','error','-i',args.baseline,'-f','f32le','-ac','1','-ar',str(RATE),'-'],capture_output=True,check=True).stdout
        data=np.frombuffer(raw,dtype='<f4');level=float(np.sqrt(np.mean(data**2)))
        comp=next(r for r in records if r['name']=='compressor-working')['decoded_rms']
        baseline=dict(path=str(Path(args.baseline).resolve()),source_sha256=sha(args.baseline),rms=level,existing_native_gain=.38,
            compressor_native_gain=1.15,effective_rms_difference_db=20*math.log10((comp*1.15)/(level*.38)))
    receipt=dict(status='ORIGINAL_AUTHORED_AUDIO; NATIVE_INTEGRATION_AND_OWNER_AUDITION_PENDING',generator_sha256=sha(__file__),
        provenance='Entirely procedural oscillators, filtered seeded noise and resonators; no sampled recordings or third-party music',
        assets=records,comparison=baseline,
        native_mix=dict(compressor_working_gain=1.15,compressor_audible_distance_modifier=3.5,priority=16,
            purifier_working_gain=.46,electrolyzer_working_gain=.40),
        owner_request='Compressor should be the loudest machinery nearby, an ungodly racket. Add machinery sounds to chain.')
    (out/'audio-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print('MACHINERY_AUDIO_AUTHORED',[(r['name'],round(r['decoded_rms_dbfs'],1)) for r in records],baseline,flush=True)


if __name__=='__main__':main()
