(
s.reboot;
s.waitForBoot {
    var mixBus = Bus.audio(s, 2);
    var mainOut = 0;
    var lastMidi = nil;
    var activeNotes = IdentityDictionary.new;
    var midiOrder = List.new; // Para rastrear el orden de llegada

    activeNotes.do { |synth| synth.free };
    activeNotes.clear;

    // Mezcladora
    SynthDef(\mixerWithCompressor, {
        |inBus, outBus, amp = 0.9, thresh = 0.5, slopeBelow = 1.0, slopeAbove = 0.3, clampTime = 0.01, relaxTime = 0.3|
        var sig = In.ar(inBus, 2);
        var comp = Compander.ar(sig, sig, thresh, slopeBelow, slopeAbove, clampTime, relaxTime);
        Out.ar(outBus, (comp * amp).tanh);
    }).add;

    // Pitch tracker
    SynthDef(\simplePitchTracker, {
        |inBus = 0|
        var input = SoundIn.ar([inBus, inBus + 1]);
        var mono = Mix(input);
        var pitchFreq, hasFreq;
        # pitchFreq, hasFreq = Pitch.kr(mono, execFreq: 20, minFreq: 50, maxFreq: 5000, median: 1);
        SendReply.kr(Impulse.kr(20), '/pitch', [0, pitchFreq.cpsmidi.round, hasFreq]);
    }).add;

    // Melody synth
    SynthDef(\trackedMelody, {
        |freq = 0, gate = 1, outBus = 0|
        var amp = 0.2;
        var env = EnvGen.kr(Env.asr(0.001, 0.3, 0.1), gate, doneAction: 2);
        var sig = SinOsc.ar(freq, 0, amp * env);
        Out.ar(outBus, Pan2.ar(sig, 0));
    }).add;

    // Pitch callback
    OSCFunc({
        |msg|
        var pitchFreq = msg[4];
        var hasFreq = msg[5];
        var midi = pitchFreq.round(1);
        var freq, synth;

        if (hasFreq == 0) {
            // Apagar todos los synths
            activeNotes.values.do { |s| s.set(\gate, 0) };
            activeNotes.clear;
            midiOrder.clear;
        } {
            // Si ya existe un synth para esta nota, no hacer nada
            if (activeNotes[midi].notNil) {
                // Refrescar posición en midiOrder (la vuelve más reciente)
                midiOrder.removeAll(midi);  // eliminar si ya estaba
                midiOrder = midiOrder.add(midi);
            } {
                // Si no existe, crearlo
                freq = midi.midicps;
                synth = Synth(\trackedMelody, [\freq, freq, \gate, 1, \outBus, mixBus]);
                activeNotes[midi] = synth;
                midiOrder = midiOrder.add(midi);
            };

            // Si hay más de 4 notas, apagar las más viejas
            while { activeNotes.size > 4 } {
                var oldest = midiOrder.removeAt(0);
                activeNotes[oldest].set(\gate, 0);
                activeNotes.removeAt(oldest);
            };
        };
    }, '/pitch').add;


    s.sync;

    Synth(\mixerWithCompressor, [\inBus, mixBus, \outBus, mainOut]);
    Synth(\simplePitchTracker, [\inBus, 0]);
};
)
