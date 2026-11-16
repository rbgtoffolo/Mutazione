# Mutazione — Live Guitar & Real-Time Processing

Software developed in **SuperCollider** for the real-time electroacoustic processing of the piece *Mutazione* (Rael B. Gimenes Toffolo, 2008; revised in 2010 and 2025). The system performs live pitch and amplitude analysis of the acoustic guitar input to trigger harmonic textures, granular synthesis, resonant filters, and spectral processing (*phase vocoder*).

## Prerequisites

* [SuperCollider](https://supercollider.github.io/) (version 3.13 or higher recommended)
* Audio interface configured with input on channel `0` (*Input 1*) and stereo output on channels `0` and `1`

## How to Run

1. **Open the file:** Launch the SuperCollider IDE and open `mutazione2025.scd`.
2. **Evaluate the main block:** Click anywhere inside the outer parentheses `(...)` of the code and press `Ctrl + Enter` (Windows/Linux) or `Cmd + Enter` (macOS).
3. **Wait for initialization:** The audio server will boot automatically with expanded memory (`memSize = 2.pow(20)`), compile the `SynthDefs`, and open the graphical user interface (**Main Controls**).

> **Important:** To prevent audio feedback, the server starts in **Muted mode (`s.mute`)**. Unmute the server window (or evaluate `s.unmute;`) before starting the performance.

## Graphical User Interface (GUI) Guide

### Main Controls
* **amp min / amp med / amp max:** Define the dynamic (amplitude) thresholds that trigger different response layers during interactive sections (default values: `0.009`, `0.15`, `0.4`).
* **Input Amp:** Controls the input gain of the guitar signal routed to the detection algorithms.
* **Trigger Speed:** Adjusts the update rate (in Hz) of the pitch and amplitude analysis sent back to the client.
* **Clean Vol:** Controls the direct pass-through (dry signal) volume of the guitar to the output.
* **Scope and Input Meter:** Display the real-time waveform and input signal level (with visual warnings at `0.6` and `0.95`).

### Piece Sections (`P01` to `P07`)
Trigger the corresponding buttons according to the score progression:

* **P01:** Activates filtered chord synthesis (`\playchords`), responding dynamically to the three configured amplitude ranges (*minimum*, *medium*, and *loud*).
* **P02:** Turns off `P01` and triggers an asynchronous polyphonic cloud of granular synthesis (`\granularSynth`) paired with sustained chords.
* **P03:** Activates pitch tracking; signals below `amp med` trigger transposed resonant filters (`\filter01`), while stronger attacks trigger sustained resonant chords (`\chordsustain`).
* **P04:** Launches the *Phase Vocoder* (`\vocoder`) with spectral bin scrambling (`PV_BinScramble`) modulated by amplitudes exceeding `amp med`.
* **P05:** Triggers granular gestures derived from the harmonic series based on detected frequencies above `174 Hz`.
* **P06:** Resumes dynamic amplitude-range responses (`\playchords`) with subtle adjustments to modulation and timbre.
* **P07:** Reactivates the *Phase Vocoder* with continuous amplitude control for the closing section.

## Closing

Close the main GUI window to automatically free all running synthesizers and terminate active processes on the server.

## Support & Contact

If you encounter any runtime errors, audio routing issues, or need assistance setting up the environment for a performance, feel free to get in touch with the composer, **Rael B. Gimenes Toffolo**, via GitHub Issues or direct contact.
