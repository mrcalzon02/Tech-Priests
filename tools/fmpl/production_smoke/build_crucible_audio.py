"""Original closed-pressure/thermal SFX, deliberately behind compressor in mix."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
import wave
import numpy as np
from build_machinery_audio import RATE,noise


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--out',required=True);ap.add_argument('--compressor-receipt',required=True);args=ap.parse_args()
    out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve audio studies')
    out.mkdir(parents=True);rng=np.random.default_rng(574211);records=[]
    def emit(name,signal,target_rms,loop,plan):
        signal=np.tanh((signal-np.mean(signal))*1.25);signal*=target_rms/max(float(np.std(signal)),1e-9)
        if np.max(abs(signal))>.82:signal*=.82/np.max(abs(signal))
        wav=out/(name+'.wav');ogg=out/(name+'.ogg')
        with wave.open(str(wav),'wb') as handle:
            handle.setnchannels(1);handle.setsampwidth(2);handle.setframerate(RATE);handle.writeframes(np.round(signal*32767).astype('<i2').tobytes())
        subprocess.run(['ffmpeg','-v','error','-i',str(wav),'-c:a','libvorbis','-q:a','6',str(ogg)],check=True)
        raw=subprocess.run(['ffmpeg','-v','error','-i',str(ogg),'-f','f32le','-ar',str(RATE),'-ac','1','-'],capture_output=True,check=True).stdout
        decoded=np.frombuffer(raw,dtype='<f4');peak=float(np.max(abs(decoded)));rms=float(np.sqrt(np.mean(decoded**2)))
        seam=float(abs(decoded[0]-decoded[-1]));step=float(np.quantile(abs(np.diff(decoded)),.999))
        if not np.isfinite(decoded).all() or peak>=1 or rms<.002:raise RuntimeError('Decoded audio/headroom gate '+name)
        if loop and seam>max(.025,step*1.4):raise RuntimeError('Decoded loop seam '+name)
        records.append(dict(name=name,seconds=len(decoded)/RATE,sample_rate=RATE,channels=1,loop=loop,plan=plan,
            wav_sha256=sha(wav),ogg_sha256=sha(ogg),decoded_peak=peak,decoded_rms=rms,decoded_rms_dbfs=20*math.log10(rms),loop_seam_step=seam,ordinary_99_9_percent_step=step))
    t=np.arange(RATE*8)/RATE
    coil=.22*np.sin(math.tau*60*t)+.10*np.sin(math.tau*120*t+.35)+.035*np.sin(math.tau*240*t)
    cabinet=.075*noise(rng,len(t),28,380)*(1+.10*np.sin(math.tau*t/8))
    coolant=.065*noise(rng,len(t),140,2300)*(1+.12*np.sin(math.tau*3*t/8))
    load=(.75+.25*np.sin(math.tau*t/8-.45))*coil
    signal=load+cabinet+coolant
    for offset in (0,4):
        d=(t-offset)%8;envelope=(1-np.exp(-d/.004))*np.exp(-d/.10)
        signal+=envelope*(.045*np.sin(math.tau*263*d)+.030*noise(rng,len(t),500,3200))
    emit('crucible-working',signal,.16,True,'Damped 60/120Hz induction/contactor bed, loaded cabinet resonance and closed cooling-circuit wash. Restrained half-cycle relay knocks; no compressor strokes or invented exposed discharge.')
    emit('crucible-idle',.08*np.sin(math.tau*60*t)+.025*noise(rng,len(t),35,350),.032,True,'Powered but inactive cabinet coil; fan and process work stopped.')
    q=np.arange(int(RATE*2.4))/RATE
    attack=(1-np.exp(-q/.10))*np.minimum(1,(2.4-q)/.12)
    start=attack*(.18*np.sin(math.tau*(28*q+8*q*q))+.05*noise(rng,len(q),120,1900))
    start+=.25*np.exp(-q/.035)*noise(rng,len(q),500,4200)
    emit('crucible-start',start,.14,False,'Heavy contactor engagement followed by induction/cooling ramp-up.')
    q=np.arange(int(RATE*2.4))/RATE
    stop=(1-np.exp(-q/.006))*np.exp(-q/.75)*np.minimum(1,(2.4-q)/.10)*(.17*np.sin(math.tau*(60*q-8*q*q))+.075*noise(rng,len(q),80,1600))
    emit('crucible-stop',stop,.105,False,'Contactor releases; closed cooling drive and coil decay. No unsupported pressure-vent hiss.')
    comp=json.loads(Path(args.compressor_receipt).read_text());comp_rms=next(a['decoded_rms'] for a in comp['assets'] if a['name']=='compressor-working')
    working=next(a['decoded_rms'] for a in records if a['name']=='crucible-working');difference=20*math.log10((working*.65)/(comp_rms*1.15))
    if difference>-3:raise RuntimeError('Crucible obscures compressor mix priority')
    report=dict(passed=True,provenance='Entirely authored oscillators, seeded filtered noise and resonances; no sampled or third-party recordings',generator_sha256=sha(__file__),assets=records,
        native_mix=dict(working_gain=.65,audible_distance_modifier=2.0,priority=40,idle_gain=.10,start_gain=.70,stop_gain=.60),
        compressor_comparison=dict(receipt_sha256=sha(args.compressor_receipt),effective_rms_difference_db=difference,compressor_gain=1.15),
        owner_audition_approved=False,native_binding_verified=False)
    (out/'audio-receipt.json').write_text(json.dumps(report,indent=2)+'\n');print('CRUCIBLE_AUDIO_AUTHORED',round(difference,2),'dB below compressor',flush=True)


if __name__=='__main__':main()
