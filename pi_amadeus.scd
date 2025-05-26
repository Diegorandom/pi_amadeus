(
s.reboot;
s.waitForBoot {
    var mixBus = Bus.audio(s, 2);
    var mainOut = 0;
    var activeNotes = IdentityDictionary.new;
    var midiOrder = List.new;

    // Definiciones
    SynthDef(\mixerWithCompressor, {
        |inBus, outBus, amp = 0.9, thresh = 0.5, slopeBelow = 1.0, slopeAbove = 0.3, clampTime = 0.01, relaxTime = 0.1|
        var sig = In.ar(inBus, 2);
        var comp = Compander.ar(sig, sig, thresh, slopeBelow, slopeAbove, clampTime, relaxTime);
        comp = (comp * amp).tanh;
        Out.ar(outBus, comp);
    }).add;

    SynthDef(\simplePitchTracker, {
        |inBus = 0|
        var input = SoundIn.ar([inBus, inBus + 1]);
        var mono = Mix(input);
        var pitchFreq, hasFreq;
        # pitchFreq, hasFreq = Pitch.kr(mono, execFreq: 20, minFreq: 50, maxFreq: 5000, median: 1);
        SendReply.kr(Impulse.kr(2), '/pitch', [0, pitchFreq.cpsmidi, hasFreq]);
    }).add;

    SynthDef(\trackedMelody, {
        |freq = 440, gate = 1, outBus = 0|
        var amp = 0.2;
        var env = EnvGen.kr(Env.asr(0.001, 0.1, 0.1), gate, doneAction: 2);
        var sig = SinOsc.ar(freq, 0, amp * env);
        Out.ar(outBus, Pan2.ar(sig, 0));
    }).add;

    OSCFunc({
        |msg|
        var pitchFreq = msg[4];
        var hasFreq = msg[5];
        var midi = pitchFreq.round(1);
        var freq, synth, oldest;

        if (hasFreq == 0) {
            // No hay nota: apaga todo y limpia
            activeNotes.values.do { |synth| synth.set(\gate, 0) };
            activeNotes.clear;
            midiOrder.clear;
        } {
            if (activeNotes[midi].isNil) {
                // Si superamos 4 synths, apaga los más viejos hasta 4
                while { activeNotes.size >=1 } {
                    oldest = midiOrder.removeAt(0);
                    if (activeNotes[oldest].notNil) {
                        activeNotes[oldest].set(\gate, 0);
                        activeNotes.removeAt(oldest);
                    };
                };

                // Crea nuevo synth para esta nota
                freq = midi.midicps;
                synth = Synth(\trackedMelody, [\freq, freq, \gate, 1, \outBus, mixBus]);
                activeNotes[midi] = synth;
                midiOrder.add(midi);
            } {
                // Nota ya activa: simplemente reafirma el gate a 1
                activeNotes[midi].set(\gate, 1);

                // También actualiza el orden para que esta nota sea la más nueva
                midiOrder.remove(midi);
                midiOrder.add(midi);
            };
        };
    }, '/pitch').add;

    s.sync;

    Synth(\mixerWithCompressor, [
        \inBus, mixBus,
        \outBus, mainOut,
        \thresh, 0.4,
        \slopeAbove, 0.2,
        \amp, 0.9
    ]);

    Synth(\simplePitchTracker, [\inBus, 0]);
};
)
