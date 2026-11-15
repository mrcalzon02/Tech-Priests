"""Original forge hydraulic/auger/tooling SFX; compressor keeps mix priority."""
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
    out.mkdir(parents=True);rng=np.random.default_rng(574903);records=[]
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
    def pulse(start,attack,decay):
        d=(t-start)%8
        return (1-np.exp(-d/attack))*np.exp(-d/decay)
    # Timing follows the actual eight-second source cycle. This preview aligns
    # the two; native event/phase synchronization is a separate runtime gate.
    feeder=np.exp(-((t-2.05)/1.05)**8)
    press=np.exp(-((t-5.20)/.85)**8)
    pump=.11*np.sin(math.tau*50*t)+.04*np.sin(math.tau*100*t+.4)
    motor=.045*noise(rng,len(t),45,560)*(1+.14*np.sin(math.tau*11*t))
    screw=feeder*(.065*noise(rng,len(t),160,2100)+.045*np.sin(math.tau*173*t)*(1+.4*np.sin(math.tau*9*t)))
    load=press*(.12*np.sin(math.tau*75*t)+.08*noise(rng,len(t),70,850))
    working=pump+motor+screw+load
    for start in (4.84,5.76):
        d=(t-start)%8
        working+=pulse(start,.002,.10)*(.24*np.sin(math.tau*157*d)+.10*np.sin(math.tau*391*d))
    working+=pulse(6.08,.01,.16)*.08*noise(rng,len(t),380,3200)
    for start in (6.47,7.58):
        d=(t-start)%8
        working+=pulse(start,.001,.045)*(.12*np.sin(math.tau*1127*d)+.07*np.sin(math.tau*1703*d))
    emit('forge-working',working,.145,True,'Closed hydraulic pump/motor bed; short auger grit during feed, pressure-load rise and two restrained press-frame knocks, return-valve wash and small die/tray metal ticks. Eight-second source-phase preview; no compressor roar.')
    emit('forge-idle',.045*np.sin(math.tau*50*t)+.015*noise(rng,len(t),35,290),.025,True,'Powered idle hydraulic cabinet hum; auger and press loading stopped.')
    q=np.arange(int(RATE*1.6))/RATE
    envelope=(1-np.exp(-q/.08))*np.minimum(1,(1.6-q)/.10)
    start=envelope*(.13*np.sin(math.tau*(24*q+8*q*q))+.035*noise(rng,len(q),70,1100))
    start+=.14*np.exp(-q/.025)*noise(rng,len(q),450,3500)
    emit('forge-start',start,.12,False,'Power contactor and hydraulic drive spin-up, with no unsupported press impact at startup.')
    q=np.arange(int(RATE*1.8))/RATE
    stop=(1-np.exp(-q/.004))*np.exp(-q/.48)*np.minimum(1,(1.8-q)/.10)*(.12*np.sin(math.tau*(50*q-6*q*q))+.04*noise(rng,len(q),80,1300))
    emit('forge-stop',stop,.085,False,'Drive rundown with a brief closed-circuit valve release; no continuous atmospheric vent.')
    comp=json.loads(Path(args.compressor_receipt).read_text());comp_rms=next(a['decoded_rms'] for a in comp['assets'] if a['name']=='compressor-working')
    working=next(a['decoded_rms'] for a in records if a['name']=='forge-working');difference=20*math.log10((working*.70)/(comp_rms*1.15))
    if difference>-3:raise RuntimeError('Forge obscures compressor mix priority')
    report=dict(passed=True,provenance='Entirely authored oscillators, seeded filtered noise and resonances; no sampled or third-party recordings',generator_sha256=sha(__file__),assets=records,
        native_mix=dict(working_gain=.70,audible_distance_modifier=2.0,priority=40,idle_gain=.09,start_gain=.65,stop_gain=.55),
        compressor_comparison=dict(receipt_sha256=sha(args.compressor_receipt),effective_rms_difference_db=difference,compressor_gain=1.15),
        owner_audition_approved=False,native_binding_verified=False)
    (out/'audio-receipt.json').write_text(json.dumps(report,indent=2)+'\n');print('FORGE_AUDIO_AUTHORED',round(difference,2),'dB below compressor',flush=True)


if __name__=='__main__':main()
