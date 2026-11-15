"""Original twelve-second seam-welding, clamp and pressure-pump soundscape."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
import wave
import numpy as np
from build_machinery_audio import RATE,noise


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--out',required=True);ap.add_argument('--compressor-receipt',required=True);args=ap.parse_args();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve authored audio studies')
    out.mkdir(parents=True);rng=np.random.default_rng(635201);assets=[]
    def emit(name,signal,target,loop,plan):
        signal=np.tanh((signal-np.mean(signal))*1.25);signal*=target/max(float(np.std(signal)),1e-9)
        if np.max(abs(signal))>.82:signal*=.82/np.max(abs(signal))
        wav=out/(name+'.wav');ogg=out/(name+'.ogg')
        with wave.open(str(wav),'wb') as f:
            f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(np.round(signal*32767).astype('<i2').tobytes())
        subprocess.run(['ffmpeg','-v','error','-i',str(wav),'-c:a','libvorbis','-q:a','6',str(ogg)],check=True)
        raw=subprocess.run(['ffmpeg','-v','error','-i',str(ogg),'-f','f32le','-ar',str(RATE),'-ac','1','-'],capture_output=True,check=True).stdout
        decoded=np.frombuffer(raw,dtype='<f4');peak=float(np.max(abs(decoded)));rms=float(np.sqrt(np.mean(decoded**2)));seam=float(abs(decoded[0]-decoded[-1]));step=float(np.quantile(abs(np.diff(decoded)),.999))
        if not np.isfinite(decoded).all() or peak>=1 or rms<.002:raise RuntimeError('Audio decode/headroom '+name)
        if loop and seam>max(.025,step*1.4):raise RuntimeError('Decoded loop seam '+name)
        assets.append(dict(name=name,seconds=len(decoded)/RATE,loop=loop,sample_rate=RATE,channels=1,plan=plan,wav_sha256=sha(wav),ogg_sha256=sha(ogg),decoded_peak=peak,decoded_rms=rms,decoded_rms_dbfs=20*math.log10(rms),loop_seam_step=seam,ordinary_99_9_percent_step=step))
    t=np.arange(RATE*12)/RATE
    def window(a,b,edge=.07):return .5*(np.tanh((t-a)/edge)-np.tanh((t-b)/edge))
    def pulse(start,decay):
        d=(t-start)%12;return (1-np.exp(-d/.003))*np.exp(-d/decay)
    weld=window(.36,3.0);close=window(4.2,6.0);form=window(6.0,8.16,.12);opening=window(9.0,10.8)
    working=.045*np.sin(math.tau*50*t)+.018*noise(rng,len(t),35,420)
    crackle=noise(rng,len(t),1600,8500)*(1+.30*np.sin(math.tau*43*t))
    working+=weld*(.052*crackle+.022*np.sin(math.tau*120*t))
    working+=(close+opening)*(.038*np.sin(math.tau*173*t)+.022*noise(rng,len(t),180,1700))
    working+=form*(.13*np.sin(math.tau*83*t)+.055*np.sin(math.tau*166*t)+.055*noise(rng,len(t),80,1400))
    for at in (6.0,9.0):working+=pulse(at,.055)*(.13*np.sin(math.tau*231*(t-at))+.04*noise(rng,len(t),600,3100))
    working+=pulse(8.70,.18)*.045*noise(rng,len(t),400,2500)
    emit('fabricator-working',working,.105,True,'Twelve-second source cycle: exposed seam welding .36–3s, clamp drive 4.2–6s, loaded forming pump 6–8.16s, restrained pressure return and clamp opening 9–10.8s. Quiet continuous cabinet motor; no compressor roar or invented repeated press impacts.')
    emit('fabricator-idle',.025*np.sin(math.tau*50*t)+.010*noise(rng,len(t),35,250),.018,True,'Powered standby cabinet hum; welding arc and forming pressure cycle stopped.')
    q=np.arange(int(RATE*1.4))/RATE;env=(1-np.exp(-q/.06))*np.minimum(1,(1.4-q)/.10)
    emit('fabricator-start',env*(.09*np.sin(math.tau*(30*q+7*q*q))+.018*noise(rng,len(q),80,1000))+.06*np.exp(-q/.018)*noise(rng,len(q),600,3500),.085,False,'Contactor click and pump cabinet spin-up. No welding or clamp impact triggered by startup alone.')
    q=np.arange(int(RATE*1.6))/RATE;env=(1-np.exp(-q/.004))*np.exp(-q/.42)*np.minimum(1,(1.6-q)/.10)
    emit('fabricator-stop',env*(.09*np.sin(math.tau*(50*q-6*q*q))+.025*noise(rng,len(q),90,1200)),.065,False,'Motor rundown and restrained closed-circuit return wash.')
    comparison=json.loads(Path(args.compressor_receipt).read_text());comp=next(r['decoded_rms'] for r in comparison['assets'] if r['name']=='compressor-working');rms=next(r['decoded_rms'] for r in assets if r['name']=='fabricator-working');difference=20*math.log10(rms*.70/(comp*1.15))
    if difference>-3:raise RuntimeError('Compressor mix priority')
    (out/'audio-receipt.json').write_text(json.dumps(dict(passed=True,generator_sha256=sha(__file__),provenance='Original oscillators, seeded filtered noise and resonances; no sampled or third-party recordings',assets=assets,native_mix=dict(working_gain=.70,audible_distance_modifier=1.8,priority=30,idle_gain=.08,start_gain=.55,stop_gain=.45),compressor_comparison=dict(receipt_sha256=sha(args.compressor_receipt),effective_rms_difference_db=difference),native_binding_verified=False,owner_audition_approved=False),indent=2)+'\n')
    print('FABRICATOR_AUDIO',round(difference,2),'dB relative to compressor',flush=True)


if __name__=='__main__':main()
