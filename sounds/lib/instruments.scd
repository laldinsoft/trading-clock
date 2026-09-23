// Shared instruments for the Trading Clock chimes. Everything is quiet by design:
// the sounds sit under a trading session, they must never startle.

// A soft bell: fundamental, a gentle octave and a faint third partial, low-passed,
// with a short attack so it reads as a tap rather than a strike.
~def.(SynthDef(\softbell, { |out=0, freq=660, amp=0.05, dec=1.6, pan=0|
    var env = EnvGen.kr(Env.perc(0.004, dec, amp, -5), doneAction: 2);
    var sig = SinOsc.ar(freq) + SinOsc.ar(freq * 2.0, 0, 0.22) + SinOsc.ar(freq * 3.01, 0, 0.06 * EnvGen.kr(Env.perc(0.001, 0.25)));
    sig = LPF.ar(sig, 5200);
    Out.ar(out, Pan2.ar(sig * env, pan));
}));

// A wooden tick: a filtered noise burst with a sine body, 60 ms.
~def.(SynthDef(\tick, { |out=0, freq=1400, amp=0.06, dec=0.07, pan=0|
    var env = EnvGen.kr(Env.perc(0.001, dec, amp, -4), doneAction: 2);
    var body = SinOsc.ar(freq) * 0.8 + (BPF.ar(WhiteNoise.ar, freq * 1.5, 0.5) * 0.7);
    Out.ar(out, Pan2.ar(body * env, pan));
}));

// Light room so the bells do not sound dry, then a limiter for safety.
~def.(SynthDef(\master, { var s = In.ar(0, 2); s = FreeVerb2.ar(s[0], s[1], 0.18, 0.7, 0.4); ReplaceOut.ar(0, Limiter.ar(s, 0.8)); }));
~fx.(0, \master);
