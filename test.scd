//ServerOptions.outDevices;
s.options.outDevice = "pisound";
s.reboot;
{ SinOsc.ar(440, 0, 0.2) }.play;