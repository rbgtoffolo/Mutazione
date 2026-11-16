/***** Mutazione - violão e processamento em tempo real
**
** Rael B. Gimenes Toffolo - 2008
**
** 2010 - reformulação do software de processamento.
** 2025 - Nova revisão
**
***********************************************************************/

(
s = Server.default;
s.options.memSize = 2.pow(20);
//s.reboot;

s.waitForBoot({

	// Main window sizes
	var 	largura = 380, altura = 560, ajuste = 0, mwLargura = 1280, mwAltura=800,
	sizeKnob = 40;
	// variaveis das janelas;
	var 	scopeWindow,
	scopeAltura = 200, scopeLargura = 200, inicioScope = 310;

	var 	itemInputArray, mainInputChannel, masterInputAmp,
	mTriggerSpeed, mTriggerSpeedNumber, detect = 0.6, cleanOutAmp;

	var minBox, medBox, maxBox, inputVU;

	var 	buttonChord1, buttonChord2, buttonChord3, buttonChord4,
	buttonChord5, buttonChord6, buttonChord7;

	var 	controlTrigger, sectionCounter = 0;

	var 	mSyn, chord1Syn, grainSyn, resonSyn, cleanSyn,
	chord2Syn, vocoderSyn;

	var min, med, max;

	s.makeWindow;
	s.mute;

	s.sync;
	// Criando Synths

	// Definindo ControlSpecs
	controlTrigger = ControlSpec(0.01,100,\exp,0.01,10);

	/************************* Synth para enviar triggers ao client ************************/

	SynthDef.new(\soundControl,

		{
			arg inChannel = 0, inAmp=0, triggerSpeed = 5;

			var ampTrig, input, freq, hasFreq, trigger;

			input = SoundIn.ar(0)*inAmp;
			// pitch detect
			# freq, hasFreq = Pitch.kr(input,22,22,4000,ampThreshold: 0.000001) ;
			// amp detect
			trigger = Impulse.kr(triggerSpeed);
			ampTrig = Peak.kr(input, trigger);
			// enviando amp e pitch de volta para o client
			SendReply.kr(trigger,'/tartini', [freq,hasFreq,ampTrig], trigger) ;
	}).load(s);

	/************* Chord1 *********************************************************/

	SynthDef.new(\playchords, {

		arg ampOut=1, freq=261, outChannel = 0, duration = 2, curvature=1, atack=0.1, qfactor= 0.05, vibrato=1, vibrato2=0.5, /* vibrato = tempo em segundos do vibrato .... vibrato2 = amplitude do vibrato */
		damp = 0.1 , guitarAmp;
		var audioOut, panVelocity, mix, room, spread;

		panVelocity = guitarAmp.linlin(0.0, 1.0, 0.5, 3);
		mix = guitarAmp.linlin(0.0, 1.0, 0.5, 0.9);
		room = guitarAmp.linlin(0.0, 1.0, 0.3, 1.0);
		spread = guitarAmp.linlin(0.0, 1.0, 1.0, 0.2);


		audioOut = BPF.ar(WhiteNoise.ar(1),freq+SinOsc.kr(vibrato, 0, vibrato2),qfactor,1)*EnvGen.kr(Env.linen(atack,1,duration), doneAction: 2);
		audioOut = FreeVerb.ar(audioOut, mix, room, damp);
		Out.ar(outChannel, Splay.ar(audioOut,spread,ampOut,SinOsc.kr(panVelocity)));

	}).load(s);
	/********************** Synth para tocar o input Clean **********************/

	SynthDef.new(\clean, { arg ampOut, inChannel = 0, outChannel= 0, verb = 0;
		var saida, roomsize, revtime, damping, inputbw, spread, drylevel, earlylevel, taillevel, maxroomsize;
		roomsize = 10;
		revtime = 1.24;
		damping = 0.10;
		inputbw = 0.95;
		drylevel = -3;
		earlylevel = -15;
		taillevel = 17;
		spread = 5;
		saida = SoundIn.ar(inChannel)*ampOut!2;
		Out.ar(outChannel, saida );

	}).load(s);

	/**************** Chord2 SinGrain ************************************************/

	SynthDef(\granularSynth, {arg midi = 60, tone = 3, art = 1.5, amp = 0.25, pan = 0, outChannel = 0, verbmix = 0.6;
		var env, out, mod, freq;

		freq = midi.midicps;
		env = Env.perc(0, art);
		mod = 5 + (1/IRand(2,6));

		out = PMOsc.ar(freq, mod*freq,
			pmindex: EnvGen.kr(env, timeScale: art, levelScale: tone),
			mul: EnvGen.kr(env, timeScale: art, levelScale: 0.2));

		out = FreeVerb.ar(Pan2.ar(out,pan), verbmix, 0.6, 0.5);

		//out = out * EnvGen.kr(env, timeScale: 1.3*art, levelScale: Rand(0.1, 0.5), doneAction:2);
		out = out * EnvGen.kr(Env.linen(1,0.1, 1), doneAction:2)* amp;
		Out.ar(outChannel,out);

	}).load(s);


	/********    Resonate filter para P03 associado à frequência de entrada do sinal transpondo 2 oitavas para cima do original */



	SynthDef(\filter01,{ arg inChannel = 0, outChannel = 0, transp = 2, ampInput = 0.8, pDisp = 0, tDisp= 0, ampOut=0.1, freq = 294;
		var input, output, env;
		input = SoundIn.ar(inChannel*ampInput);
		output = CombC.ar(PitchShift.ar(input,0.2, transp, pDisp, tDisp), 4, 0.04, 4);
		output = HPF.ar(output, freq);
		env = EnvGen.kr(Env.linen(3, 0.1, 10), 1, doneAction:2);
		output = output * env * ampOut;
		output = FreeVerb.ar(output, 0.8, 0.8, 0.1);
		Out.ar(outChannel, Pan2.ar(output,SinOsc.kr(0.8)));

	}).load(s);

	/************** Chord sustain para P03 *****************************************************/

	SynthDef(\chordsustain,{ arg outChannel = 0, freq=100, ampOut = 0.8;
		var output, env;

		output = Klank.ar(`[[	40.midicps*LFNoise1.kr(0.5).range(1,4),
			54.midicps*LFNoise0.kr(0.5).range(1, 8.999).floor,
			59.midicps*LFNoise0.kr(0.5).range(1, 8.999).floor,
			60.midicps*LFNoise0.kr(0.5).range(1, 8.999).floor,
			65.midicps*LFNoise0.kr(0.5).range(1, 8.999).floor,
			71.midicps*LFNoise0.kr(0.5).range(1, 8.999).floor,
			78.midicps*LFNoise0.kr(0.5).range(1, 8.999).floor],
		Array.rand(7,0.01, ampOut/7),
		Array.rand(7,0.5,4)], PinkNoise.ar(1)); // estava 0.007 - Verificar
		env = EnvGen.kr(Env.linen(3, 0.1, 8, 1,'\sin'  ), doneAction:2);
		output = output * env* ampOut/7;
		output = FreeVerb.ar(output, 0.9, 0.8, 0.1);
		Out.ar(outChannel, Pan2.ar(output,LFNoise2.kr(0.3).range(-0.6, 0.6)));


	}).load(s);

	/********************************* Phase vocoder *****************************************/

	// SynthDef(\vocoder, { arg amp, inChannel = 0, outChannel = 0;
	//
	// 	var in, chain, signal, real, imag, output, delaytime, pantime;
	// 	// var real = MouseX.kr(0.01,2.0, 'exponential');
	// 	// var imag = MouseY.kr(0.01,10.0, 'exponential');
	// 	real = amp.linexp(0.0, 1.0, 0.01, 2);
	// 	imag = amp.linexp(0.0, 1.0, 0.01, 10.0);
	//
	// 	in = SoundIn.ar(inChannel);
	//
	// 	chain = FFT(LocalBuf(2048), in);
	// 	chain = PV_ConformalMap(chain, real, imag);
	// 	signal = IFFT(chain);
	// 	delaytime = amp.linlin(0,1,5,10);
	// 	pantime = amp.linlin(0,1,0.1,1);
	// 	output = Pan2.ar(CombN.ar(signal, 0.1, 0.1, delaytime, 0.5),SinOsc.kr(pantime),1 );
	// 	// ampOut = EnvGen.kr(Env.perc(0.001, 2),1, timeScale: 2.6, levelScale: 0.9, doneAction:2);
	// 	Out.ar(outChannel, output );
	//
	// }).load(s);


	SynthDef(\vocoder, { arg amp=1, inChannel = 0, outChannel = 0;

		var in, chain, signal, output, delaytime, decaytime, pantime;
		// var real = MouseX.kr(0.01,2.0, 'exponential');
		// var imag = MouseY.kr(0.01,10.0, 'exponential');

		in = SoundIn.ar(inChannel);

		chain = FFT(LocalBuf(2048), in);
		chain = PV_BinScramble(chain, amp, amp);
		signal = IFFT(chain);
		decaytime = amp.linlin(0.0,1.0,5,10);
	//	delaytime = amp.linlin(0.0, 1.0, 0.03, 0.1);
		delaytime = 0.1;
		pantime = amp.linlin(0,1,0.1,1);
		output = Pan2.ar(CombN.ar(signal, 5, delaytime, decaytime, 0.5),LFNoise1.kr(pantime).range(-0.6,0.6),1 );
		// ampOut = EnvGen.kr(Env.perc(0.001, 2),1, timeScale: 2.6, levelScale: 0.9, doneAction:2);
		output = FreeVerb.ar(output);
		Out.ar(outChannel, output );


	}).load(s);

	s.sync;


	/**********************************************************************
	/ INICIANDO GUI
	***********************************************************************/

	// criando Janelas
	w = Window("M U T A Z I O N E - Guitar & live - RBGToffolo", Rect((mwLargura-largura)/2,(mwAltura-altura)/2, largura,altura), resizable: false);

	StaticText (w, Rect(80,5, 200, 24)).font_(Font("Arial Black", 13,0)).string_('Main Controls').align_(\center);


	//StaticText (w, Rect(10,50,250,24)).font_(Font("Arial Black", 14,0)).string_('Press Any Key');
	minBox = NumberBox(w, Rect(10, 50, 60,24)).valueAction_(0.009);
	medBox = NumberBox(w, Rect(80, 50, 60, 24)).valueAction_(0.15);
	maxBox = NumberBox(w, Rect(150,50, 60, 24)).valueAction_(0.4);

	StaticText(w, Rect(15, 30, 69, 24)).string_("amp min").font_(Font("Bitstream Vera Sans", 10));
	StaticText(w, Rect(85, 30, 69, 24)).string_("amp med").font_(Font("Bitstream Vera Sans", 10));
	StaticText(w, Rect(155, 30, 69, 24)).string_("amp max").font_(Font("Bitstream Vera Sans", 10));

	// Master input Volume
	StaticText (w, Rect (250,75, 110, 24)).string_('Input Amp').align_(\center).font_(Font( "Bitstream Vera Sans", 10 ));
	masterInputAmp = Knob(w, Rect (290, 40, sizeKnob, sizeKnob));
	masterInputAmp.value = 0;

	// Slider para selecionar o Timer do Trigger
	StaticText (w, Rect (20,90, 90, 40)).string_('Trigger Speed').align_(\left).font_(Font( "Bitstream Vera Sans", 10 ));
	mTriggerSpeed = QSlider(w,Rect(95,100,170,20));
	mTriggerSpeedNumber = NumberBox(w,Rect(290,100,60,24));
	mTriggerSpeedNumber.value = mTriggerSpeed.value;

	// Clean Volume Out
	StaticText (w, Rect (5,140, 110, 24)).string_('Clean Vol').align_(\center).font_(Font( "Bitstream Vera Sans", 10 ));
	cleanOutAmp = Knob(w, Rect (40, 160, sizeKnob, sizeKnob));
	cleanOutAmp.value = 0;


	// botoes para partes da música
	buttonChord1 = Button( w, Rect( 30, 210, 90, 30 )).font_(Font("Bitstream Vera Sans", 10));
	buttonChord1.states = [    // array of states
		[ "P01 OFF", Color.black ], // first state
		[ "P01 ON", Color.white, Color.red ],  // second state etc.
	];


	buttonChord2 = Button( w, Rect( 140, 210, 90, 30 )).font_(Font("Bitstream Vera Sans", 10));
	buttonChord2.states = [    // array of states
		[ "P02 OFF", Color.black ], // first state
		[ "P02 ON", Color.white, Color.red ],  // second state etc.
	];

	buttonChord3 = Button( w, Rect( 255, 210, 90, 30 )).font_(Font("Bitstream Vera Sans", 10));
	buttonChord3.states = [    // array of states
		[ "P03 OFF", Color.black ], // first state
		[ "P03 ON", Color.white, Color.red ],  // second state etc.
	];

	//Chord4, Chord5, Chord6
	buttonChord4 = Button( w, Rect( 30, 260, 70, 30 )).font_(Font("Bitstream Vera Sans", 10));
	buttonChord4.states = [    // array of states
		[ "P04 OFF", Color.black ], // first state
		[ "P04 ON", Color.white, Color.red ],  // second state etc.
	];

	buttonChord5 = Button( w, Rect( 112, 260, 70, 30 )).font_(Font("Bitstream Vera Sans", 10));
	buttonChord5.states = [    // array of states
		[ "P05 OFF", Color.black ], // first state
		[ "P05 ON", Color.white, Color.red ],  // second state etc.
	];

	buttonChord6 = Button( w, Rect( 193, 260, 70, 30 )).font_(Font("Bitstream Vera Sans", 10));
	buttonChord6.states = [    // array of states
		[ "P06 OFF", Color.black ], // first state
		[ "P06 ON", Color.white, Color.red ],  // second state etc.
	];

	buttonChord7 = Button( w, Rect( 275, 260, 70, 30 )).font_(Font("Bitstream Vera Sans", 10));
	buttonChord7.states = [    // array of states
		[ "P07 OFF", Color.black ], // first state
		[ "P07 ON", Color.white, Color.red ],  // second state etc.
	];

	//scopeWindow = CompositeView(w, Rect((largura-scopeLargura)/2,inicioScope,scopeLargura,scopeAltura));

	scopeWindow = CompositeView(w, Rect(10,inicioScope,scopeLargura+32,scopeAltura+32));
	Stethoscope.new(s, 2, 0, 1024, view: scopeWindow );

	StaticText (w, Rect (scopeLargura+55,inicioScope, 110, 24)).string_('Input Meter').align_(\center).font_(Font( "Bitstream Vera Sans", 10 ));

	inputVU = LevelIndicator.new(w, Rect(scopeLargura+85, inicioScope+32, 50,scopeAltura));
	inputVU.warning_(0.6).critical_(0.95);

	// Criando OSCdef para VuMeter

	~sensor = OSCFunc({
		| msg |
		~amplitude = msg[5].value;
		{
			inputVU.value = ~amplitude;
		}.defer;
	}, '/tartini');



	/***************************************************************************************/
	// Instanciando Synths
	/***************************************************************************************/

	mSyn = Synth(\soundControl);
	cleanSyn = Synth(\clean);


	/***************************************************************************************/
	// Ações do GUI
	//
	// Determinação dos comportamentos padrões do processamento são programados nesta
	// parte do código. Veja comentários abaixo.
	/***************************************************************************************/

	/* retirado na revisão de 2013
	mainInputChannel.action_({ arg select;
	mSyn.set(\inChannel, select.value);
	cleanSyn.set(\inChannel, select.value);
	});
	*/

	/* sensor de teclas


	w.view.keyDownAction_({
	case
	{ sectionCounter == 0}
	{ s.unmute;
	s.volume = 0;
	buttonChord1.valueAction = 1;
	sectionCounter = sectionCounter + 1;  }

	{ sectionCounter == 1}
	{
	buttonChord2.valueAction = 1;
	sectionCounter = sectionCounter + 1;  }

	{ sectionCounter == 2}
	{
	buttonChord3.valueAction = 1;
	sectionCounter = sectionCounter + 1;  }

	{ sectionCounter == 3}
	{
	buttonChord4.valueAction = 1;
	sectionCounter = sectionCounter + 1;  }

	{ sectionCounter == 4}
	{
	AppClock.sched(8,{buttonChord4.valueAction = 0});
	buttonChord5.valueAction = 1;
	sectionCounter = sectionCounter + 1;  }

	{ sectionCounter == 5}
	{
	buttonChord6.valueAction = 1;
	sectionCounter = sectionCounter + 1;  }

	{ sectionCounter == 6}
	{
	buttonChord7.valueAction = 1;
	sectionCounter = sectionCounter + 1;  }

	{ sectionCounter == 7}
	{

	~fadeOut = Routine({
	var sInicial, sFinal, sTime, sDelta, sElaps;
	sInicial = 0.0; sFinal = -99; sTime = 10;
	sDelta = sFinal-sInicial;
	sElaps = 1/(1024/sTime);

	1024.do({ s.volume = sInicial;

	sInicial = sInicial + (sDelta/1024);
	//sInicial.postln;
	sElaps.yield;
	})
	});


	AppClock.sched(0,~fadeOut);


	};



	});

	*/

	masterInputAmp.action_({
		mSyn.set(\inAmp, masterInputAmp.value);
	});


	mTriggerSpeed.action_({
		mSyn.set(\triggerSpeed, controlTrigger.map(mTriggerSpeed.value));
		mTriggerSpeedNumber.value = controlTrigger.map(mTriggerSpeed.value);
	});


	cleanOutAmp.action_({ cleanSyn.set(\ampOut, cleanOutAmp.value);
	});



	// buttons actions

	buttonChord1.action_({ arg button; // fazer variação dos três acordes básicos a partir da dinâmica

		if (button.value == 1,
			{
				mTriggerSpeed.valueAction = 0.68;
				cleanOutAmp.valueAction = 1.0;
				masterInputAmp.valueAction = 1.0;


				~b1Sensor = OSCFunc({ | msg |		// Função Responder
					{
						var amplitude;

						amplitude = msg[5].value;

						if (amplitude <= minBox.value, {
							//	"silencio".postln;
						},{});

						if ( amplitude > maxBox.value , { //"tocando acorde forte".postln;
							[ 164.81377845643, 369.99442271163, 391.99543598175, 440, 659.25511382574, 880, 932.32752303618, 1108.7305239075 ].do({arg item;
								var frequency, transpose, curvature, atack;
								transpose = [0.25,0.5,1,2,3,4,5,6,7].choose;
								frequency = item*transpose;
								curvature = 4.rand2;
								atack = rrand(0.1, 0.3);

								Synth(\playchords, [\freq, frequency, \curvature, curvature, \atack, atack, \qfactor, 0.05, \ampOut, 0.4, \vibrato, 4, \vibrato2, 50, \guitarAmp, amplitude, \duration, 3]);
							});
						}, { });

						if ( ( amplitude > minBox.value) && ( amplitude < medBox.value), {	//"tocando acorde mínimo".postln;
							[ 164.81377845643, 184.99721135582, 195.99771799087, 220].do({arg item;
								var frequency, transpose, curvature, atack;
								transpose = [2,4,8,10].choose;
								frequency = item*transpose;
								curvature = 4.rand2;
								atack = rand(1.5,3.8);

								Synth(\playchords, [\freq, frequency, \curvature, curvature, \atack, atack, \qfactor, 0.001, \vibrato, 0.5, \vibrato2, 20, \guitarAmp, amplitude, \duration, 8]);
							});
						}, { });


						if ( ( amplitude > medBox.value) && ( amplitude < maxBox.value), { //"acorde tocando médio".postln;
							[ 164.81377845643, 184.99721135582, 195.99771799087, 220, 277.18263097687 ].do({arg item;
								var frequency, transpose, curvature, atack;
								transpose = [0.5,1,2].choose;
								frequency = item*transpose;
								curvature = 2.rand2;
								atack = rand(0.3, 0.8);

								Synth(\playchords, [\freq, frequency, \curvature, curvature, \atack, atack, \qfactor, 0.007, \ampOut, 0.15, \vibrato, 1.5, \vibrato2, 35, \guitarAmp, amplitude, \duration, 4.6]);
							});
						}, { });

					}.defer;
				}, '/tartini');

			}, //true if
			{ ~b1Sensor.free;
			} // false if

		);

	});

	buttonChord2.action_({arg button;
		if (button.value ==1, {

			buttonChord1.valueAction = 0;


			[ 82.406889228217, 164.81377845643, 246.94165062806, 349.228231433, 493.88330125612, 659.25511382574 ].do({arg item;
				var frequency, transpose, curvature, atack;
				//"valor do item ".post;
				transpose = [0.5,1,2,4].choose;
				frequency = item*transpose;
				//"frequency ".post;
				//frequency.postln;
				curvature = 4.rand2;
				atack = 1.5.rand;
				//"atack ".post;
				//atack.postln;
				Synth(\playchords, [\freq, frequency, \curvature, curvature, \atack, atack, \qfactor, 0.1, \ampOut, 0.6, \vibrato, 0.2, \vibrato2, 10]

			);});

			Task({20.do({ var freq, pan;
				pan = rrand(-1.0,1.0);
				freq = [ 112, 107, 101, 100, 95].at(5.rand);
				Synth(\granularSynth,[\midi, freq, \pan, pan, \verbmix, 0.2]);
				[0.05,0.2,0.07].choose.wait;
			});
			}).play;

			Task({20.do({ var freq, pan;
				pan = rrand(-1.0,1.0);
				freq = [ 112, 107, 101, 100, 95, 95, 89, 88].at(8.rand);
				Synth(\granularSynth,[\midi, freq, \pan, pan , \verbmix, 0.3]);
				[0.07,0.3,0.09].choose.wait;
			});
			}).play;

			Task({20.do({ var freq, pan;
				pan = rrand(-1.0,1.0);
				freq = [ 101, 100, 95, 95, 89, 88, 87, 83].at(8.rand);
				Synth(\granularSynth,[\midi, freq, \pan,pan, \verbmix, 0.4]);
				[0.09,0.4,0.1].choose.wait;
			});
			}).play;

			Task({20.do({ var freq, pan;
				pan = rrand(-1.0,1.0);
				freq = [100, 95, 95, 89, 88, 87, 83, 83, 77, 76 ].at(10.rand);
				Synth(\granularSynth,[\midi, freq,\pan,pan, \verbmix, 0.5]);
				[0.1,0.45,0.13].choose.wait;
			});
			}).play;

			Task({20.do({ var freq, pan;
				pan = rrand(-1.0,1.0);
				freq = [95, 89, 88, 87, 83, 83, 77, 76, 76, 75, 71 ].at(11.rand);
				Synth(\granularSynth,[\midi, freq,\pan,pan, \verbmix, 0.6]);
				[0.15,0.5,0.17].choose.wait;
			});
			}).play;

			Task({20.do({ var freq, pan;
				pan = rrand(-1.0,1.0);
				freq = [ 89, 88, 87, 83, 83, 77, 76, 76, 75, 71, 71, 65 ].at(12.rand);
				Synth(\granularSynth,[\midi, freq, \pan, pan, \verbmix, 0.7]);
				[0.2,0.56,0.2].choose.wait;
			});
			}).play;

			Task({20.do({ var freq, pan;
				pan = rrand(-1.0,1.0);
				freq = [ 88, 87, 83, 83, 77, 76, 76, 75, 71, 71, 65, 64, 63 ].at(13.rand);
				Synth(\granularSynth,[\midi, freq, \pan, pan, \verbmix, 0.8]);
				[0.3,0.7,0.28].choose.wait;
			});
			}).play;

			Task({20.do({ var freq, pan;
				pan = rrand(-1.0,1.0);
				freq =[ 87, 83, 83, 77, 76, 76, 75, 71, 71, 65, 64, 63, 59 ].at(13.rand);
				Synth(\granularSynth,[\midi, freq, \pan, pan, \verbmix, 0.9 ]);
				[0.35,0.8,0.30].choose.wait;
			});
			}).play;

			Task({20.do({ var freq, pan;
				pan = rrand(-1.0,1.0);
				freq = [ 83, 77, 76, 76, 75, 71, 71, 65, 64, 63, 59, 52, 51 ].at(13.rand);
				Synth(\granularSynth,[\midi, freq, \pan, pan, \verbmix, 0.9]);
				[0.4,0.9,0.32].choose.wait;
			});
			}).play;

			Task({20.do({ var freq, pan;
				pan = rrand(-1.0,1.0);
				freq =[ 77, 76, 76, 75, 71, 71, 65, 64, 63, 59, 52, 51, 40 ].at(13.rand);
				Synth(\granularSynth,[\midi, freq, \pan, pan, \verbmix, 1]);
				[0.5,1,0.4].choose.wait;
			});
			}).play;



		},{ }); // final do if button.value ==1;




	});


	buttonChord3.action_({  arg button;
		if (button.value ==1, {
			mTriggerSpeed.valueAction = 0.80;
			buttonChord1.valueAction = 0;
			buttonChord2.valueAction = 0;


			~b3Sensor = OSCFunc({ | msg |
				{
					var freq, amp, hasFreq, transp;
					hasFreq = msg[4].value;
					amp = msg[5].value;
					if ( hasFreq > 0.5,
						{ freq = msg[3].value;
							transp = freq/(28.midicps);

						},
						{freq = 20;
							transp = [1,2,3,4].choose;

					});
					if ( amp <= medBox.value, {
						Synth(\filter01, [\freq, freq, \inChannel, mainInputChannel.value, \ampInput, masterInputAmp.value, \pDisp, amp.linlin(0.0, 1.0, 0.001, 0.1), \tDisp, amp.linlin(0.0, 1.0, 0.01, 0.05), \transp, transp, \ampOut, 0.1, \freq, freq]);
					},{

						Synth(\chordsustain, [\freq, freq,\ampOut, 0.2]);
					});
				}.defer;
			}, '/tartini');



		},{~b3Sensor.free;}

		);



	});


	buttonChord4.action_({ arg button;
		if (button.value == 1, {
			vocoderSyn = Synth(\vocoder);
			vocoderSyn.set(\inChannel, mainInputChannel.value);
			buttonChord3.valueAction = 0;
			mTriggerSpeed.valueAction = 0.75;

			~b4Sensor = OSCFunc({ | msg |
				{
					var freq, amp;
					freq = msg[3].value;
					amp = msg[5].value;
					//amp.postln;
					if (amp > medBox.value, {
						vocoderSyn.set(\amp, amp); }
					,{ amp = 0;
						vocoderSyn.set(\amp, amp); });

				}.defer;
			}, '/tartini');


		},
		{vocoderSyn.free;
			~b4Sensor.free;
		} // else-if button
		);


	});

	buttonChord5.action_({ arg button;
		if (button.value == 1, {
			mTriggerSpeed.valueAction = 0.5;

			~b5Sensor = OSCFunc({ | msg |
				{
					var freq;
					freq = msg[3].value;
					if (freq > 174, {
						Task({15.do({ var notes, pan;
							pan = rrand(-1.0,1.0);
							notes = freq* [ 1,2,3,4,5,6,7,8].at(8.rand);
							//notes.postln;
							Synth(\granularSynth,[\midi, notes.cpsmidi, \pan, pan, \verbmix, 1, \amp, 0.2]);
							[0.1,0.2,0.5].choose.wait;
						});
						}).play;
				}, {});	}.defer;
			}, '/tartini');
		},
		{~b5Sensor.free;}); //else-if button
	});


	buttonChord6.action_({ arg button; // fazer variação dos três acordes básicos a partir da dinâmica

		if (button.value == 1,
			{
				mTriggerSpeed.valueAction = 0.5;

				~b6Sensor = OSCFunc({ | msg |		// Função Responder
					{
						var amplitude;

						amplitude = msg[5].value;

						if (amplitude <= minBox.value, {
							//"silencio".postln;
						},{});

						if ( amplitude > maxBox.value , { // "tocando acorde forte".postln;
							[ 164.81377845643, 369.99442271163, 391.99543598175, 440, 659.25511382574, 880, 932.32752303618, 1108.7305239075 ].do({arg item;
								var frequency, transpose, curvature, atack;
								transpose = [0.25,0.5,1,2,3,4,5,6,7].choose;
								frequency = item*transpose;
								curvature = 4.rand2;
								atack = rrand(0.1, 0.3);

								Synth(\playchords, [\freq, frequency, \curvature, curvature, \atack, atack, \qfactor, 0.05, \ampOut, 0.2, \vibrato, 4, \vibrato2, 50, \guitarAmp, amplitude, \duration, 3]);
							});
						}, { });

						if ( ( amplitude > minBox.value) && ( amplitude < medBox.value), {//	"tocando acorde mínimo".postln;
							[ 164.81377845643, 184.99721135582, 195.99771799087, 220].do({arg item;
								var frequency, transpose, curvature, atack;
								transpose = [2,4,8,10].choose;
								frequency = item*transpose;
								curvature = 4.rand2;
								atack = rand(1.5,3.8);

								Synth(\playchords, [\freq, frequency, \curvature, curvature, \atack, atack, \qfactor, 0.001, \vibrato, 0.3, \vibrato2, 20, \guitarAmp, amplitude, \duration, 8]);
							});
						}, { });


						if ( ( amplitude > medBox.value) && ( amplitude < maxBox.value), { // "acorde tocando médio".postln;
							[ 164.81377845643, 184.99721135582, 195.99771799087, 220, 277.18263097687 ].do({arg item;
								var frequency, transpose, curvature, atack;
								transpose = [0.5,1,2].choose;
								frequency = item*transpose;
								curvature = 2.rand2;
								atack = rand(0.3, 0.8);

								Synth(\playchords, [\freq, frequency, \curvature, curvature, \atack, atack, \qfactor, 0.007, \ampOut, 0.08, \vibrato, 1.5, \vibrato2, 35, \guitarAmp, amplitude, \duration, 4.6]);
							});
						}, { });

					}.defer;
				}, '/tartini');


			}, //true if
			{ ~b6Sensor.free;
			} // false if

		);

	});



	buttonChord7.action_({ arg button;
		if (button.value == 1, {
			vocoderSyn = Synth(\vocoder);
			vocoderSyn.set(\inChannel, mainInputChannel.value);
			buttonChord6.valueAction = 0;
			mTriggerSpeed.valueAction = 0.75;

			~b7Sensor = OSCFunc({ | msg |		// Função Responder

				var amplitude;
				amplitude = msg[5].value;

			vocoderSyn.set(\amp, amplitude);
			})
		}
			,{vocoderSyn.free;
		} // else-if button
		);


	});


	// criando a janela
	w.front;

	// encerrando janela e synth
	w.onClose = {	

~sensor.free;
		~b1Sensor.free;
		~b3Sensor.free;
		~b4Sensor.free;
		~b5Sensor.free;
		~b6Sensor.free;
		~b7Sensor.free;

		mSyn.free;
		chord1Syn.free;
		cleanSyn.free;
		vocoderSyn.free;
		s.freeAll;
		OSCdef.freeAll;
		Window.closeAll;

	};
});
)

