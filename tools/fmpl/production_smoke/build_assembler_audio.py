"""Original sixteen-second cap slide, pellet gate, electric sealer and index SFX."""
import argparse
import json
import math
from pathlib import Path
import subprocess
import wave
import numpy as np
from build_machinery_audio import RATE,noise,sha


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--out',required=True);ap.add_argument('--compressor-receipt',required=True)
    args=ap.parse_args();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve original audio studies')
    out.mkdir(parents=True);rng=np.random.default_rng(716025);assets=[]
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
        if loop and seam>max(.025,step*1.4):raise RuntimeError('Loop seam '+name)
        assets.append(dict(name=name,seconds=len(decoded)/RATE,loop=loop,sample_rate=RATE,channels=1,plan=plan,wav_sha256=sha(wav),ogg_sha256=sha(ogg),decoded_peak=peak,decoded_rms=rms,decoded_rms_dbfs=20*math.log10(rms),loop_seam_step=seam,ordinary_99_9_percent_step=step))
    t=np.arange(RATE*16)/RATE
    def window(a,b,edge=.035):return .5*(np.tanh((t-a)/edge)-np.tanh((t-b)/edge))
    def impact(at,decay=.045):
        d=(t-at)%16;return (1-np.exp(-d/.002))*np.exp(-d/decay)
    motor=noise(rng,len(t),120,1300);pellets=noise(rng,len(t),1600,6500);contacts=noise(rng,len(t),600,3400)
    work=.018*np.sin(math.tau*50*t)+.008*noise(rng,len(t),40,260)
    for start in (0,5,10):
        slides=window(start+.24,start+.72)+window(start+2.4,start+2.96)
        lift=window(start+.02,start+.24)+window(start+2.96,start+3.2)
        work+=(slides+.55*lift)*(.038*motor+.018*np.sin(math.tau*181*t))
        gate=window(start+.88,start+1.28)+window(start+1.92,start+2.4)
        work+=gate*(.014*np.sin(math.tau*317*t)+.017*contacts)
        work+=window(start+1.28,start+1.92)*.020*pellets*(.65+.35*np.sin(math.tau*29*t)**2)
        work+=window(start+3.12,start+3.76)*(.046*np.sin(math.tau*137*t)+.026*motor)
        for at,level in [(start+.24,.035),(start+2.96,.048),(start+3.44,.075)]:work+=impact(at)*(level*np.sin(math.tau*263*(t-at))+.020*contacts)
    index=window(4,5)+window(9,10)+window(14,15.98)
    work+=index*(.048*np.sin(math.tau*193*t)+.026*motor)
    emit('assembler-working',work,.075,True,'Actual sixteen-second source cycle: supported cap lift/slide, brief pellet-gate linkage and granular patter, restrained electric sealing drive and seated-cap clunk. Head index at 4–5/9–10s and return at 14–16s. No compressor roar or hydraulic forming pump.')
    emit('assembler-idle',.020*np.sin(math.tau*50*t)+.008*noise(rng,len(t),40,230),.014,True,'Quiet powered controls and electric-drive standby. No lid movement, pellet rattle or sealing clunk while idle.')
    q=np.arange(int(RATE*1.1))/RATE;env=(1-np.exp(-q/.045))*np.minimum(1,(1.1-q)/.09)
    emit('assembler-start',env*(.05*np.sin(math.tau*(44*q+5*q*q))+.012*noise(rng,len(q),110,1100))+.025*np.exp(-q/.02)*noise(rng,len(q),700,3200),.055,False,'Contactor and electric servo enable; process impacts remain in the working loop.')
    q=np.arange(int(RATE*1.3))/RATE;env=(1-np.exp(-q/.004))*np.exp(-q/.32)*np.minimum(1,(1.3-q)/.09)
    emit('assembler-stop',env*(.06*np.sin(math.tau*(50*q-7*q*q))+.012*noise(rng,len(q),100,1200)),.045,False,'Short electric-drive rundown; no invented pressure release from the solid pellet feed.')
    comp=json.loads(Path(args.compressor_receipt).read_text());reference=next(r['decoded_rms'] for r in comp['assets'] if r['name']=='compressor-working');rms=assets[0]['decoded_rms'];difference=20*math.log10(rms*.65/(reference*1.15))
    if difference>-6:raise RuntimeError('Compressor must dominate mix')
    (out/'audio-receipt.json').write_text(json.dumps(dict(passed=True,generator_sha256=sha(__file__),provenance='Original oscillators, seeded filtered noise and resonances; no borrowed samples',assets=assets,native_mix=dict(working_gain=.65,idle_gain=.07,start_gain=.45,stop_gain=.40,audible_distance_modifier=1.5,priority=25),compressor_comparison=dict(receipt_sha256=sha(args.compressor_receipt),effective_rms_difference_db=difference),native_binding_verified=False,native_phase_synchronization_verified=False,owner_audition_approved=False),indent=2)+'\n')
    print('ASSEMBLER_AUDIO',round(difference,2),'dB relative to compressor',flush=True)


if __name__=='__main__':main()
