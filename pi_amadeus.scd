(
s.reboot;
s.waitForBoot {
    var mixBus = Bus.audio(s, 2);
    var mainOut = 0;
    var activeNotes = IdentityDictionary.new;
    var midiOrder = List.new;

    // Definiciones
    SynthDef(\mixerWithCompressor, {
        |inBus, outBus, amp = 0.9, thresh = 0.5, slopeBelow = 1.0, slopeAbove = 0.2, clampTime = 0.01, relaxTime = 0.3|
        var sig, comp, glued, softened, verb, chorusMod, chorusDelay, chorusSignal, mixOut;

        // Entrada estéreo
        sig = In.ar(inBus, 2);

        // Compresión para pegar fuentes
        comp = Compander.ar(sig, sig, thresh, slopeBelow, slopeAbove, clampTime, relaxTime);

        // Saturación suave para compactar
        glued = (comp * amp).tanh;

        // Filtro de agudos muy suave (pegamento sutil)
        softened = LPF.ar(glued, 18000);

        // Chorus: delay modulado lento para efecto de detune/duplicación sutil
        chorusMod = SinOsc.kr(0.3, 0, 0.003, 0.005);  // modulación delay entre 2ms y 8ms
        chorusDelay = DelayL.ar(softened, 0.02, chorusMod);
        chorusSignal = (softened * 0.7) + (chorusDelay * 0.3);

        // Reverb suave para amalgamar espacio
        verb = FreeVerb.ar(chorusSignal, mix: 0.3, room: 0.9, damp: 0.5);

        // Mezcla original con reverb, más cohesión
        mixOut = (chorusSignal * 0.9) + (verb * 0.1);

        // Evitar clipeo con saturación suave final
        mixOut = mixOut.tanh;

        Out.ar(outBus, mixOut);
    }).add;


    SynthDef(\simplePitchTracker, {
        |inBus = 0|
        var input = SoundIn.ar([inBus, inBus + 1]);
        var mono = Mix(input);
        var pitchFreq, hasFreq, amp;

        // Pitch tracking
        # pitchFreq, hasFreq = Pitch.kr(mono, execFreq: 60, minFreq: 20, maxFreq: 1500, median: 1);

        // Amplitud (volumen) usando RMS
        amp = Amplitude.kr(mono, attackTime: 0.01, releaseTime: 0.1);

        // Enviar pitch, hasFreq y volumen en un solo mensaje
        SendReply.kr(Impulse.kr(60), '/pitch', [0, pitchFreq.cpsmidi, hasFreq, amp]);
    }).add;

    SynthDef(\trackedMelody, {
    |freq = 440, gate = 1, outBus = 0, modulation = 0.1, preGain = 2, postGain = 0.2,
    reverbMix = 0.3, pitchRatio = 1.2, pitchModDepth = 0.1|

    var amp = 0.15;
    var env = EnvGen.kr(Env.asr(1, modulation, modulation * 10), gate, doneAction: 2);
    var sig, vibrato, osc1, osc2, osc3, body, presence, shifted, shiftMod, withReverb;

    // Suave vibrato
    vibrato = SinOsc.kr(5, 0, 3); // ±3 Hz

    // Tres osciladores LFSaw ligeramente desafinados
    osc1 = Saw.ar(freq + vibrato);
    osc2 = Saw.ar(freq * 0.995 + vibrato);
    osc3 = Saw.ar(freq * 1.005 + vibrato);

    // Mezcla y envolvente
    sig = Mix([osc1, osc2, osc3]) * 0.33;
    sig = sig * env * amp;

    // Filtro con modulación lenta y mayor resonancia para agresividad
    sig = RLPF.ar(sig, freq * 2 + SinOsc.kr(0.1).range(-200, 200), 0.15);

    // Modulación para el shift ratio
    shiftMod = SinOsc.kr(modulation, 0, pitchModDepth);

    // Pitch shifting sin feedback
    shifted = PitchShift.ar(
        sig,
        windowSize: 0.2,
        pitchRatio: pitchRatio + shiftMod,
        pitchDisp: 0.0,
        timeDisp: 0.0
    );

    // Presencia
    sig = shifted + (BHiShelf.ar(shifted, 4500, 0.3, 9) * 0.3);

    // Reverb
    withReverb = FreeVerb.ar(sig, mix: reverbMix, room: 3 * modulation, damp: modulation);

    // Salida final
    body = withReverb * postGain;
    Out.ar(outBus, Pan2.ar(body, 0));
}).add;


    // Delay con feedback y modulación
	SynthDef(\pisoundDelayGlitch, {
        |inBus = 0, outBus = 0, delayTime = 0.1, feedback = 1.0, aggression = 1.0|
        var input, delayed, glitchMod, glitchSignal, mix, distorted, boosted, withReverb;

        input = SoundIn.ar([inBus, inBus + 1]);

        // Delay con realimentación modulada
        delayed = DelayC.ar(input, 1, delayTime);
        delayed = input + (delayed * feedback.clip(0, 1.2));

        // Glitch más agresivo
        glitchMod = LFNoise1.kr(25 * aggression).range(0.3, 2.0);
        glitchSignal = delayed * glitchMod;

        // Distorsión post-glitch
        distorted = (glitchSignal * (1.5 * aggression)).tanh;

        // --- Reverb ---
        withReverb = FreeVerb.ar(distorted, mix: 0.3, room: 0.9, damp: 0.4);

        // Realce agresivo de medios-altos
        boosted = BPeakEQ.ar(distorted, freq: 3000, rq: 0.3, db: 6 * aggression);

        // Mezcla final controlada
        mix = (delayed + boosted) * 0.12;

        Out.ar(outBus, mix);
    }).add;

    // // Texture follower basado en pitch
	SynthDef(\delayFollowerTexture, {
		|inBus = 0, outBus = 0, delayTime = 0.35, feedback = 0.6|
		var input, monoIn, delayed, pitchFreq, hasFreq, texture, vibrato, distortedVib, distorted;

		input = SoundIn.ar([inBus, inBus + 1]);
		monoIn = Mix(input);
		delayed = DelayC.ar(monoIn, 5, delayTime);
		delayed = monoIn + (delayed * feedback);

        // Distorsión post-glitch
        distorted = (delayed * (1.5 * 2.0)).tanh;

		# pitchFreq, hasFreq = Pitch.kr(monoIn, execFreq: 20, minFreq: 20, maxFreq: 1350, median: 1);

        vibrato= Vibrato.ar(pitchFreq,pitchFreq,0.02, rateVariation: pitchFreq);

        distortedVib = (vibrato * (1.5 * 2.0)).tanh;

		texture = Saw.ar(freq: pitchFreq + distortedVib, mul: 0.2) * distorted;

		Out.ar(outBus, [texture, texture] * 0.1);
	}).add;

    Routine {
        OSCFunc({
            |msg|
            var pitchFreq = msg[4];
            var hasFreq = msg[5];
            var amp = msg[6];
            var midi = pitchFreq.round(1);
            var freq, synth, oldest, allowedSynths = 1 +(amp* 100);

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
                    synth = Synth(\trackedMelody, [\freq, freq, \gate, 1, \outBus, mixBus, \modulation, amp]);
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
        //Synth(\delayFollowerTexture, [\inBus, 0, \outBus, mixBus]);
    }.play;
};
)
