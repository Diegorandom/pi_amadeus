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
        var pitchFreq, hasFreq, amp;

        // Pitch tracking
        # pitchFreq, hasFreq = Pitch.kr(mono, execFreq: 20, minFreq: 50, maxFreq: 5000, median: 1);

        // Amplitud (volumen) usando RMS
        amp = Amplitude.kr(mono, attackTime: 0.01, releaseTime: 0.1);

        // Enviar pitch, hasFreq y volumen en un solo mensaje
        SendReply.kr(Impulse.kr(20), '/pitch', [0, pitchFreq.cpsmidi, hasFreq, amp]);
    }).add;

    SynthDef(\trackedMelody, {
        |freq = 440, gate = 1, outBus = 0, release=0.1|
        var amp = 0.2;
        var env = EnvGen.kr(Env.asr(0.001, 0.3, release), gate, doneAction: 2);
        var sig = SinOsc.ar(freq, 0, amp * env);
        Out.ar(outBus, Pan2.ar(sig, 0));
    }).add;

    // Delay con feedback y modulación
	SynthDef(\pisoundDelayGlitch, {
		|inBus = 0, outBus = 0, delayTime = 0.1, feedback = 1.0|
		var input, delayed, glitchMod, glitchSignal, mix;

		input = SoundIn.ar([inBus, inBus + 1]);
		delayed = DelayC.ar(input, 1, delayTime);
		delayed = input + (delayed * feedback);

		glitchMod = LFNoise1.kr(20).range(0.5, 1.5);
		glitchSignal = delayed * glitchMod;

		mix = (delayed + glitchSignal) * 0.5;

		Out.ar(outBus, mix);
	}).add;

    OSCFunc({
        |msg|
        var pitchFreq = msg[4];
        var hasFreq = msg[5];
        var amp = msg[6];
        var midi = pitchFreq.round(1);
        var freq, synth, oldest, allowedSynths = 1+(amp*3);

        if (hasFreq == 0) {
            // No hay nota: apaga todo y limpia
            activeNotes.values.do { |synth| synth.set(\gate, 0) };
            activeNotes.clear;
            midiOrder.clear;
        } {
            if (activeNotes[midi].isNil) {
                // Si superamos 4 synths, apaga los más viejos hasta 4
                while { activeNotes.size >= allowedSynths.round } {
                    oldest = midiOrder.removeAt(0);
                    if (activeNotes[oldest].notNil) {
                        activeNotes[oldest].set(\gate, 0);
                        activeNotes.removeAt(oldest);
                    };
                };

                // Crea nuevo synth para esta nota
                freq = midi.midicps;
                synth = Synth(\trackedMelody, [\freq, freq, \gate, 1, \outBus, mixBus, \release, amp]);
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
    Synth(\pisoundDelayGlitch, [\inBus, 0, \outBus, mixBus]);
};
)
