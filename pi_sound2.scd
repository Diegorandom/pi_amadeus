(
// Procesador dinámico con funciones matemáticas
~pisoundProcessor = (
    synth: nil,

    start: {
        Server.default.waitForBoot({
            SynthDef(\mathEffect, {
                var input, freq, lfo, filtered, distorted, env, output;

                // Entrada estéreo
                input = SoundIn.ar([0, 1]);

                // LFO que oscila entre 400 y 6000 Hz (modulación sinusoidal)
                lfo = SinOsc.kr(0.1).range(400, 6000);

                // Aplicar filtro pasa-bajo con frecuencia modulada
                filtered = LPF.ar(input, lfo);

                // Distorsión suave con tangente hiperbólica
                distorted = tanh(filtered * 3);

                // Envolvente de amplitud controlada por otro LFO
                env = SinOsc.kr(0.05).range(0.4, 1.0);
                output = distorted * env;

                // Enviar a salida estéreo
                Out.ar(0, output);
            }).add;

            Server.default.sync;
            ~pisoundProcessor.synth = Synth(\mathEffect);
        });
    },

    stop: {
        if(~pisoundProcessor.synth.notNil) {
            ~pisoundProcessor.synth.free;
            "Procesamiento detenido".postln;
        } {
            "No hay un synth activo".postln;
        }
    }
);
)

~pisoundProcessor.start
