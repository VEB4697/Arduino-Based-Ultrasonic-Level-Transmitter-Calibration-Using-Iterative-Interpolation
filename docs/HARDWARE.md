# Hardware, Circuit Connections, and Zero-PCB Build

## Architecture

Use two separate 40 kHz air-coupled piezo elements. The 555 generates a continuous carrier; the Uno gates its RESET pin for a short burst. An NPN transistor drives the TX element. The RX element feeds a two-stage, AC-coupled LM358 amplifier biased at half supply; a diode/envelope node and LM393 comparator produce a logic edge on the Uno. The Uno measures the echo time and reports raw measurements. MATLAB converts raw air gap to calibrated water level.

Supply convention: use a regulated 9 V DC input for the 555/transmitter/analog front end, and power the Uno by USB. Join grounds at one star point. The Uno 5 V output powers only comparator logic/pull-up. Do not connect 9 V to an Uno I/O pin. Confirm the chosen LM358/LM393 variants and transducer ratings from datasheets.

## BOM (one prototype, approximate; local prices vary)

| Qty | Component | Notes |
|---:|---|---|
| 1 | Arduino Uno compatible | USB serial, 5 V logic |
| 1 | NE555 or TLC555 | Carrier oscillator; bipolar NE555 may have sharper edges/current draw |
| 1 | LM358 dual op amp | Receiver preamp; use DIP-8 socket |
| 1 | LM393 dual comparator | Receiver threshold detector; open collector requires 10 kΩ pull-up to 5 V |
| 2 | 2N2222/BC547 NPN | One TX transistor and one 555 gate transistor; check pinout/current |
| 1 | 2N3906/BC557 PNP | 555 RESET high-side level shift from 9 V |
| 2 | 40 kHz piezo transducer, TX and RX | Separate open-type elements, matched if possible |
| 1 | 1N4148 | Envelope detector |
| 1 | 9 V regulated DC adapter, ≥500 mA | Final sizing follows measured TX current |
| 1 | 5 V relay module, opto-isolated preferred | DC pump control only for prototype; rating selected from actual load |
| 1 | Zero PCB, 2.54 mm grid | Two physical sections; no solderless board in final prototype |
| 3 | 100 nF ceramic | Local decoupling at NE555, LM358, and LM393 |
| 1 | 10 µF electrolytic | Supply bulk decoupling |
| 1 | 10 kΩ trim pot | Comparator threshold; wire wiper with end-stop resistors |
| 2 | 1 kΩ resistors | 555 timing R values, see frequency note |
| 1 | 12 nF capacitor | 555 timing capacitor; 5% film preferred |
| 3 | 10 kΩ resistors | LM358 bias divider and LM393 pull-up |
| 2 | 10 kΩ resistors | 555 gate bias network |
| 1 | 100 kΩ resistor | 555 RESET default-disable pull-down |
| 2 | 100 kΩ resistors | LM358 stage feedback |
| 4 | 10 nF film/ceramic capacitors | RX input coupling, interstage coupling, envelope AC coupling, and NE555 pin 5 bypass |
| 2 | 1 MΩ resistors | LM358 feedback/input network |
| 2 | 10 kΩ resistors | LM358 stage gain-setting resistors |
| 1 | 10 kΩ resistor | LM393 envelope input series resistor |
| 1 | 100 kΩ resistor | LM393 hysteresis |
| 1 | 4.7 kΩ resistor | Uno D2 to 555 gate NPN base |
| 1 | 1 kΩ resistor | 555 output to TX transistor base |
| 1 | 100 nF capacitor | RX envelope hold capacitor |
| 1 | 1 kΩ resistor | RX envelope discharge |
| 1 | 100 Ω resistor | Initial TX series resistor; adjust only after scope/current check |
| as needed | headers, insulated wire, terminal blocks, enclosure, fuse | Keep TX and RX wiring separated |

This BOM describes a low-cost starting point; component availability differs by market. Buy the parts by value/part family and verify exact package pinouts and datasheets. Do not treat the 100 Ω series resistor or 9 V supply as validated until measured with your selected transducer.

## Connection schedule

### 555 transmitter, DIP-8 NE555

- Pin 1 GND to 9 V supply return/star ground. Pin 8 VCC to +9 V rail. Pin 4 RESET connects to the PNP gate stage below (do not wire it directly to +9 V). Place 100 nF from pin 8 to pin 1 at the socket.
- Tie pins 2 TRIG and 6 THRESH together. Put 12 nF from this timing node to ground.
- Place RA=1 kΩ from +9 V to pin 7 DISCH; RB=1 kΩ from pin 7 to pins 2/6. Pin 5 CONTROL gets 10 nF to ground. Pin 3 OUT is the 40 kHz carrier.
- Frequency estimate is `1.44 / ((RA + 2*RB) * C)` = 40 kHz for RA=1 kΩ, RB=1 kΩ, C=12 nF. Real tolerance shifts frequency; verify with an oscilloscope and adjust the timing network to the particular element's resonance.
- Gate pin 4 RESET with a two-transistor level shifter so the 555 is disabled by default: put 100 kΩ from pin 4 to ground; connect a 2N3906 PNP emitter to +9 V and collector to pin 4, with 10 kΩ from its base to +9 V; connect a 2N2222 NPN emitter to ground and collector to the PNP base; Uno D2 through 4.7 kΩ to the NPN base, with 10 kΩ from that NPN base to ground. D2 HIGH turns both transistors on and raises RESET to +9 V (carrier enabled); D2 LOW or floating leaves RESET pulled low (disabled). Confirm the two transistor pinouts. This is the only point where the Uno command controls the 9 V 555 rail; do not connect RESET directly to a GPIO.
- Drive 2N2222 base from pin 3 through 1 kΩ. Emitter to ground. Collector to TX transducer low side. Other transducer lead to +9 V through 100 Ω. Connect grounds. Scope the transducer voltage/current and never exceed its datasheet rating. If actual pin 3 drive or amplitude is unsuitable, use a properly rated push-pull driver stage rather than removing protection.

### Receiver analog front end

LM358 DIP-8: pin 8 +9 V, pin 4 ground; pins 1/7 outputs, pins 2/6 inverting inputs, pins 3/5 non-inverting inputs. Decouple pin 8 to pin 4 with 100 nF.

- Create VREF ≈4.5 V using two 10 kΩ resistors between +9 V and ground; decouple midpoint with 10 µF. This is a signal bias, not a power rail.
- RX transducer low lead to ground; high lead through 10 nF series capacitor to stage-A pin 3. Put 1 MΩ from pin 3 to VREF.
- Stage A non-inverting gain: 100 kΩ from pin 1 to pin 2 and 10 kΩ from pin 2 to VREF. Gain ≈11. Do not put a 10 nF capacitor in parallel with the feedback resistor; that would shunt the 40 kHz signal and remove most of the gain.
- Couple pin 1 through 10 nF to stage-B pin 5; put 1 MΩ from pin 5 to VREF.
- Stage B: 100 kΩ from pin 7 to pin 6 and 10 kΩ from pin 6 to VREF (gain ≈11). Start with lower gain if it clips/oscillates. Short, separated RX traces are essential; total gain is high.
- Envelope: AC couple stage-B output through an additional 10 nF capacitor to the diode 1N4148 anode; diode cathode to envelope node; 100 nF from envelope node to ground and 1 kΩ from node to ground. The coupling capacitor removes the op-amp's 4.5 V bias before rectification. Confirm the envelope is positive-going experimentally and reverse diode if the chosen transducer polarity/phase requires it.
- LM393 DIP-8: pin 8 +5 V, pin 4 ground, decouple with 100 nF. Use comparator A: pin 3 (+) envelope node through 10 kΩ; pin 2 (−) adjustable threshold from 10 kΩ trim pot between +5 V and ground; pin 1 output to Uno D3 with 10 kΩ pull-up to +5 V. Add 100 kΩ hysteresis from pin 1 to pin 3. Comparator B unused: tie pin 5 to ground, pin 6 to +5 V, leave pin 7 unconnected.
- A comparator edge after the transmit burst is the echo event. D3 uses interrupt/capture logic in firmware. Keep receiver ground return away from the TX transistor current loop.

**Prototype circuit cautions:** This is a hand-build starting topology, not a validated production schematic. LM358 bandwidth and 40 kHz gain margin, envelope polarity, comparator threshold, and transmit feedthrough must be scoped and adjusted on Day 2. Never bridge op-amp rails or tie the VREF net to ground. The image's megohm feedback values and ambiguous rail wiring should not be soldered by assumption.

## Arduino I/O

| Uno | Connection |
|---|---|
| D2 | 555 RESET gate NPN base via 4.7 kΩ; HIGH enables a burst |
| D3 | LM393 open-collector output, 10 kΩ pull-up to +5 V |
| D8 | Relay module input; use a low-voltage LED during commissioning |
| GND | Common star point with 9 V supply return and analog ground |
| USB | PC/MATLAB serial; do not simultaneously feed Uno 9 V through VIN unless supply arrangement is reviewed |

## Zero-PCB hole plan (top view)

Orientation: component side up; 2.54 mm holes, columns A–T left-to-right, rows 1–30 top-to-bottom. This is a *placement and net-map* guide, not a promise that every copper pad is isolated: inspect your exact board and use a continuity meter. Install IC sockets spanning the center groove. Insulate every underside jumper and check for bridges before power.

| Region | Placement | Wiring route |
|---|---|---|
| Columns A–D, rows 2–10 | 555 socket centered D5; timing R/C in rows 2–4 | +9 rail along row 2; GND along row 10; D2 gate transistors enter A8 |
| Columns A–D, rows 12–18 | TX transistor near D15; series resistor/transducer terminal A15 | Keep TX current loop on left edge; do not route under RX section |
| Columns G–L, rows 2–10 | LM358 socket centered I5; VREF divider at G2/G3; decoupler directly at pins | RX input enters at G8; first-stage and second-stage parts sit adjacent to pins |
| Columns G–L, rows 12–17 | LM393 socket centered I14; pot at L14; output header L17 | +5 comparator rail and pull-up route to Uno header; keep comparator output off TX path |
| Columns N–T, rows 2–8 | Arduino header / terminal blocks | D2, D3, D8 and GND only; no 9 V on digital header |
| Columns N–T, rows 12–18 | TX and RX transducer connectors at N14 and T14 | Use separate twisted pairs, with RX pair shield/ground if available |
| Row 30 | Shared star ground terminal at J30; +9 V input at A30 | One short ground link to each section; keep TX return first to supply/star, not through RX ground |

Before soldering, mark the actual socket pin positions on paper. A labeled coordinate diagram with nets is a safer guide than guessing continuous rails on perfboard; zero PCB hole connectivity varies. Use insulated point-to-point jumpers and a multimeter continuity checklist. Leave at least two empty columns between TX and RX. Route no traces underneath the transducer input or LM358 feedback nodes.

## Assembly and commissioning sequence

1. With power disconnected, identify all IC notch orientation and check package pinout. Solder headers/sockets first, then passive parts, then transistor, then terminals. Keep separate TX/RX zones and add strain relief.
2. Inspect both sides under bright light. Check no shorts between +9 V, +5 V, VREF, and GND. Verify every jumper against the connection schedule with a continuity meter.
3. Power only the 555 from current-limited 9 V. Check carrier frequency and pin-3 waveform. Gate RESET and verify a finite burst. Then connect TX through the series resistor and measure amplitude/current.
4. Power receiver; inspect VREF, both amplifier outputs, envelope, and comparator threshold. Ensure outputs are not railed/oscillating. Adjust trim for a clean echo edge after the blanking interval.
5. Connect Uno and relay input. Keep relay contacts unloaded; test output with an LED. Confirm reset, serial loss, no echo, and invalid range all lead to relay off. Confirm active-high/active-low polarity of the exact relay module and add an external pull resistor that holds it OFF while the Uno resets.
6. Mount over a quiet tank, align elements, and record ruler references for calibration. Never make a live wiring change.

## Tank installation and pump caution

Mount transducers at the tank top, normal to the undisturbed water surface, above the maximum water level and outside the near-field/dead zone. Use a splash/condensation baffle that does not obstruct the beam. Provide an independent overflow float switch and a low-water cut-out wired in the pump control circuit. The relay module's markings are not proof of safe mains isolation. Mains work requires correctly rated enclosure, fuse, cable gland, earth, separation, and qualified installation; use an appropriately rated contactor. Day 1 does not specify a final mains circuit because pump nameplate and jurisdiction are unknown.
