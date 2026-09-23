// Shared non-realtime (NRT) render helpers. Prepended to every piece by render.sh.
// Usage inside a piece:
//   ~def.(SynthDef(\name, { ... }))            register a SynthDef
//   ~note.(time, \name, [\freq, 440, \dur, 2]) start a synth at `time` seconds
//   ~fx.(time, \name, args)                    start a synth at the TAIL (master effects)
//   ~finish.(totalSeconds)                     render to the WAV path passed on argv
~score = Score.new;
~nid = 1000;
~seed = 2026;
thisThread.randSeed = ~seed;
~def = { |def| ~score.add([0.0, ['/d_recv', def.asBytes]]); };
~note = { |t, name, args|
    ~nid = ~nid + 1;
    ~score.add([t, ['/s_new', name, ~nid, 0, 0] ++ (args ? [])]);
};
~fx = { |t, name, args|
    ~nid = ~nid + 1;
    ~score.add([t, ['/s_new', name, ~nid, 1, 0] ++ (args ? [])]);
};
~finish = { |dur|
    var out = (thisProcess.argv[0] ? "out.wav").standardizePath;
    ~score.add([dur, ['/c_set', 0, 0]]);
    ~score.sort;
    ~score.recordNRT(
        ("/tmp/sc_nrt_" ++ Date.getDate.stamp ++ ".osc").standardizePath, out,
        sampleRate: 44100, headerFormat: "WAV", sampleFormat: "int16",
        options: ServerOptions.new.numOutputBusChannels_(2).memSize_(2 ** 18),
        action: { ("RENDER_DONE " ++ out).postln; 0.exit }
    );
};
