s.waitForBoot {
	var mixBus = Bus.audio(s, 2);
	var mainOut = 0;

	// Mezcladora con compresor
	SynthDef(\mixerWithCompressor, {
		|inBus, outBus, amp = 0.9, thresh = 0.5, slopeBelow = 1.0, slopeAbove = 0.3, clampTime = 0.01, relaxTime = 0.3|
		var sig, comp;

		sig = In.ar(inBus, 2);

		// Aplicamos compresión estéreo
		comp = Compander.ar(
			in: sig,
			control: sig,
			thresh: thresh,         // Umbral de compresión (ajustable)
			slopeBelow: slopeBelow, // Ganancia por debajo del umbral (1.0 = lineal)
			slopeAbove: slopeAbove, // Ganancia por encima del umbral (<1 = compresión)
			clampTime: clampTime,   // Tiempo de ataque
			relaxTime: relaxTime    // Tiempo de liberación
		);

		// Saturación suave para redondear picos residuales
		comp = (comp * amp).tanh;

		Out.ar(outBus, comp);
	}).add;

	// Delay con feedback y modulación
	// SynthDef(\pisoundDelayGlitch, {
	// 	|inBus = 0, outBus = 0, delayTime = 0.3, feedback = 1.0|
	// 	var input, delayed, glitchMod, glitchSignal, mix;

	// 	input = SoundIn.ar([inBus, inBus + 1]);
	// 	delayed = DelayC.ar(input, 1, delayTime);
	// 	delayed = input + (delayed * feedback);

	// 	glitchMod = LFNoise1.kr(20).range(0.5, 1.5);
	// 	glitchSignal = delayed * glitchMod;

	// 	mix = (delayed + glitchSignal) * 0.5;

	// 	Out.ar(outBus, mix);
	// }).add;

	// // Texture follower basado en pitch
	// SynthDef(\delayFollowerTexture, {
	// 	|inBus = 0, outBus = 0, delayTime = 0.35, feedback = 0.6|
	// 	var input, monoIn, delayed, pitchFreq, hasFreq, texture;

	// 	input = SoundIn.ar([inBus, inBus + 1]);
	// 	monoIn = Mix(input);
	// 	delayed = DelayC.ar(monoIn, 1, delayTime);
	// 	delayed = monoIn + (delayed * feedback);

	// 	# pitchFreq, hasFreq = Pitch.kr(monoIn, execFreq: 20, minFreq: 50, maxFreq: 10000, median: 7);
	// 	SendReply.kr(Impulse.kr(1), '/pitch', [0, pitchFreq, hasFreq]);

	// 	texture = SinOsc.ar(freq: pitchFreq / 3, mul: 0.2) * delayed;

	// 	Out.ar(outBus, [texture, texture] * 0.5);
	// }).add;

    SynthDef(\trackedMelody, {
    |inBus = 0, outBus = 0|
    var input, monoIn, pitchFreq, hasFreq, freq, amp, sig;

    input = SoundIn.ar([inBus, inBus + 1]);
    monoIn = Mix(input);

    // Seguimiento de pitch
    # pitchFreq, hasFreq = Pitch.kr(monoIn, execFreq: 20, minFreq: 50, maxFreq: 10000);

    // Selección de frecuencia: si no hay pitch, el valor se congela o mutea
    freq = pitchFreq;

    // Amp sujeta a hasFreq (suavizada)
    amp = Lag.kr(hasFreq, 0.2);  // tarda 0.2s en subir/bajar

    // Oscilador
    sig = SinOsc.ar(freq, 0, amp * 0.3); // solo suena cuando amp > 0

    Out.ar(outBus, Pan2.ar(sig, 0));
}).add;





    // SynthDef(\fase, {arg freq=440, fase=0, gate=1, mul=1, out=0;
    //     var env;
    //     env = EnvGen.kr(Env.asr(1, 1, 1),gate, doneAction: 2);
    //     Out.ar(out, Pan2.ar(SinOsc.ar(freq, phase:SinOsc.ar(fase, mul:2pi), mul:mul*env),0));
    // }).add;

    // SynthDef(\paneo, {arg pan = 0, mul=1, out=0;
    //     var env;
    //     env = EnvGen.kr(Env([0,1,0],[0.05,0.05]), doneAction: 2);
    //     Out.ar(out, Pan2.ar(SinOsc.ar(440, mul:mul*env),pan))
    // }).add;

    // SynthDef(\noise, {arg freq = 800, out=0;
    //     var env;
    //     var noise = WhiteNoise.ar(1);
    //     env = EnvGen.kr(Env([0,1,0],[0.05,0.05]), doneAction: 2);
    //     Out.ar(out, Pan2.ar(RLPF.ar(noise,freq*freq+100)),0)
    // }).add;

    // SynthDef(\gaussian, {arg gauss, mul=1, out=0;
    //     var env, signal;
    //     env = EnvGen.kr(Env([0,1,0],[1,1]), doneAction: 2);
    //     signal= LFGauss.ar(XLine.kr(0.1, (0.001), 5), 0.003, gauss+0.00001, doneAction: 2);
    //     Out.ar(out, Pan2.ar(signal,0));
    // }).add;

    // SynthDef(\dusty, {arg dust=0, out=0;
    //     var env, signal, mul=1;
    //     env = EnvGen.kr(Env([0,1,0.5],[0.5,0.5]), doneAction: 2);
    //     signal = Dust.ar(XLine.kr(0.0001+dust*100, 0.0001+dust*100, 1), 0.5);
    //     Out.ar(out, Pan2.ar(signal,0))
    // }).add;

    // SynthDef(\delay, {arg delay=1, out=0;
    //     var env, signal, signalproc;
    //     env = EnvGen.kr(Env([0,1,0.5],[1,1]), doneAction: 2);
    //     signal = Decay2.ar(Dust.ar(delay, 0.5), 0.01, 0.1, Saw.ar(100 + [0, 1]));
    //     signalproc = DelayC.ar(RLPF.ar(signal, Rand(100, 3000), 0.03), 1, delay, 1, signal * 0.5);
    //     Out.ar(out, Pan2.ar(signalproc,0,1*env));
    // }).add;

    // SynthDef( \vibrato, {arg vib, out=0;
    //     var vibrato, signal, env;
    //     env = EnvGen.kr(Env([0,1,0],[0.05,0.05]), doneAction: 2);
    //     vibrato= Vibrato.ar(DC.ar(400.0),vib,0.02, rateVariation: vib);
    //     signal=SinOsc.ar(vibrato, mul:1*env);
    //     Out.ar(out, Pan2.ar(signal, 0));
    // }).add;

	// Receptor de pitch
	OSCFunc({
		|msg|
		var id = msg[3];
		var pitch = msg[4];
		var hasFreq = msg[5];
		if (hasFreq > 0) {
			("[ID: " ++ id ++ "] Pitch: " ++ pitch).postln;
		} {
			("[ID: " ++ id ++ "] No pitch detected").postln;
		};
	}, '/pitch').add;

	s.sync;

	// Instanciar mezcladora con compresión
	Synth(\mixerWithCompressor, [
		\inBus, mixBus,
		\outBus, mainOut,
		\thresh, 0.4,      // Umbral de compresión más bajo = más protección
		\slopeAbove, 0.2,  // Compresión más fuerte sobre el umbral
		\amp, 0.9
	]);

	// Enviar señales a la mezcla
	// Synth(\pisoundDelayGlitch, [\inBus, 0, \outBus, mixBus]);
	// Synth(\delayFollowerTexture, [\inBus, 0, \outBus, mixBus]);
    Synth(\trackedMelody, [\outBus, mixBus])
};
