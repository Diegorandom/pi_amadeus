(
s.reboot;
s.waitForBoot {
    var mixBus = Bus.audio(s, 2);
    var mainOut = 0;
    var activeNotes = IdentityDictionary.new;
    var midiOrder = List.new;

    // Mezclador con compresión y control de ganancia
    SynthDef(\mixerWithCompressor, {
        |inBus, outBus, amp = 0.6, thresh = 0.5, slopeBelow = 1.0, slopeAbove = 0.2, clampTime = 0.01, relaxTime = 0.1|
        var sig, comp, filtered, chorusMod, chorusDelay, chorusSignal, verb, mixOut;

        sig = In.ar(inBus, 2);
        sig = LeakDC.ar(sig);  // eliminación de DC

        comp = Compander.ar(sig, sig, thresh, slopeBelow, slopeAbove, clampTime, relaxTime);
        filtered = LPF.ar(comp, 6500);
        filtered = filtered * amp;

        chorusMod = SinOsc.kr(0.3, 0, 0.003, 0.005);
        chorusDelay = DelayL.ar(filtered, 0.02, chorusMod);
        chorusSignal = (filtered * 0.7) + (chorusDelay * 0.3);

        verb = FreeVerb.ar(chorusSignal, mix: 0.2, room: 0.6, damp: 0.5);
        mixOut = Mix([chorusSignal * 0.9, verb * 0.1]);

        mixOut = Limiter.ar(mixOut, level: 0.98, dur: 0.02);  // control final
        Out.ar(outBus, mixOut);
    }).add;

    // Pitch tracker
    SynthDef(\simplePitchTracker, {
        |inBus = 0|
        var input = SoundIn.ar([inBus, inBus + 1]);
        var mono = Mix(input);
        var pitchFreq, hasFreq, amp;

        # pitchFreq, hasFreq = Pitch.kr(mono, execFreq: 60, minFreq: 20, maxFreq: 1500, median: 1);
        amp = Amplitude.kr(mono, attackTime: 0.01, releaseTime: 0.1);
        SendReply.kr(Impulse.kr(60), '/pitch', [0, pitchFreq.cpsmidi, hasFreq, amp]);
    }).add;

    // Melody Synth
    SynthDef(\trackedMelody, {
        |freq = 440, gate = 1, outBus = 0, modulation = 0.1, postGain = 0.15, reverbMix = 0.3|
        var amp = 0.1;
        var env = EnvGen.kr(Env.asr(0.01, 1, 0.9), gate, doneAction: 2);
        var sig, vibrato, osc1, osc2, osc3, body, presence, withReverb;

        vibrato = SinOsc.kr(5, 0, 2);
        osc1 = Saw.ar(freq + vibrato);
        osc2 = Saw.ar(freq * 0.997 + vibrato);
        osc3 = Saw.ar(freq * 1.003 + vibrato);

        sig = Mix([osc1, osc2, osc3]) * 0.33;
        sig = sig * env * amp;
        sig = RLPF.ar(sig, freq * 2 + SinOsc.kr(0.1).range(-100, 100), 0.2);
        presence = BHiShelf.ar(sig, freq: 4500, rs: 0.3, db: 3);
        sig = sig + (presence * 0.2);
        withReverb = FreeVerb.ar(sig, mix: reverbMix, room: 0.3, damp: 0.5);
        body = withReverb * postGain;
        body = Limiter.ar(body, level: 0.95, dur: 0.01);
        Out.ar(outBus, Pan2.ar(body, 0));
    }).add;

    // Delay glitch
    SynthDef(\pisoundDelayGlitch, {
        |inBus = 0, outBus = 0, delayTime = 0.1, feedback = 0.9, aggression = 0.8|
        var input, delayed, glitchMod, glitchSignal, mix, distorted, boosted;

        input = SoundIn.ar([inBus, inBus + 1]);
        delayed = DelayC.ar(input, 1, delayTime);
        delayed = input + (delayed * feedback.clip(0, 1.1));

        glitchMod = LFNoise1.kr(25 * aggression).range(0.3, 2.0);
        glitchSignal = delayed * glitchMod;
        distorted = (glitchSignal * (1.2 * aggression)).tanh;
        boosted = BPeakEQ.ar(distorted, freq: 3000, rq: 0.3, db: 6 * aggression);
        mix = (delayed + boosted) * 0.08;
        Out.ar(outBus, mix);
    }).add;

    // Pitch tracking listener
    OSCFunc({
        |msg|
        var pitchFreq = msg[4];
        var hasFreq = msg[5];
        var amp = msg[6];
        var midi = pitchFreq.round(1);
        var freq, synth, oldest, allowedSynths = 1+(amp*10);

        if (hasFreq == 0) {
            activeNotes.values.do { |s| s.set(\gate, 0) };
            activeNotes.clear;
            midiOrder.clear;
        } {
            if (activeNotes[midi].isNil) {
                while { activeNotes.size >= allowedSynths.round } {
                    oldest = midiOrder.removeAt(0);
                    if (activeNotes[oldest].notNil) {
                        activeNotes[oldest].set(\gate, 0);
                        activeNotes.removeAt(oldest);
                    };
                };
                freq = midi.midicps;
                synth = Synth(\trackedMelody, [\freq, freq, \gate, 1, \outBus, mixBus, \modulation, amp]);
                activeNotes[midi] = synth;
                midiOrder.add(midi);
            } {
                activeNotes[midi].set(\gate, 1);
                midiOrder.remove(midi);
                midiOrder.add(midi);
            };
        };
    }, '/pitch').add;

    // Lanzar sintes base
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
