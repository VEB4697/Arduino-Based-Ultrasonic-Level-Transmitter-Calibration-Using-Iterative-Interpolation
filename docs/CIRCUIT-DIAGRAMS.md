# Circuit Diagrams

These diagrams show the signal and power connections; use the DIP pin-by-pin schedule in `HARDWARE.md` for soldering. They are the Day 1 design to bench-validate, not a certified construction drawing. The supplied reference images are not the approved netlist.

## System interconnect

```mermaid
flowchart LR
  U[Arduino Uno\nD2 burst enable\nD3 echo edge\nD8 relay command] --> G[2N2222 + 2N3906\nRESET level shifter]
  G --> T[NE555\n40 kHz carrier gated in bursts]
  T --> Q[2N2222 TX driver]
  Q --> TX[40 kHz transmitter]
  RX[Separate 40 kHz receiver] --> A[LM358 stage A\ngain about 11]
  A --> B[LM358 stage B\ngain about 11]
  B --> D[10 nF coupling + 1N4148\nenvelope detector]
  D --> C[LM393 threshold + hysteresis]
  C --> U
  U <-->|USB serial 115200| M[MATLAB HMI\ninterpolation + log + pump hysteresis]
  M -->|P,0 / P,1| U
  U --> R[5 V relay module\nlow voltage bench load]
```

## Transmitter net diagram

```mermaid
flowchart LR
  V9[+9 V] --> RA[RA 1 kΩ]
  RA --> PIN7[NE555 pin 7]
  PIN7 --> RB[RB 1 kΩ]
  RB --> NODE[NE555 pins 2 + 6 tied]
  NODE --> CT[C 12 nF]
  CT --> GND[Star GND]
  V9 --> PNP[2N3906 emitter]
  PNP --> RESET[NE555 pin 4 RESET]
  RESET --> RPD[100 kΩ to GND]
  PNPBASE[PNP base] --- RPU[10 kΩ to +9 V]
  PNPBASE --- QG[2N2222 collector]
  QG --> GND
  D2[Uno D2] --> RBASE[4.7 kΩ]
  RBASE --> QGBASE[2N2222 gate NPN base]
  QGBASE --> RBD[10 kΩ to GND]
  PIN3[NE555 pin 3] --> RDRV[1 kΩ]
  RDRV --> QTX[2N2222 TX base]
  QTX -->|collector| PIEZO[TX transducer low lead]
  V9 --> RS[100 Ω initial series resistor]
  RS -->|other lead| PIEZO
  QTX --> GND
```

Pin 4 is enabled only when Uno D2 is high: the gate NPN pulls the PNP base low, allowing the PNP to raise RESET to +9 V. A floating/low D2 leaves RESET pulled down and disables the 555.

## Receiver and comparator net diagram

```mermaid
flowchart LR
  V9[+9 V] --> DIV[10 kΩ + 10 kΩ divider]
  DIV --> VREF[VREF about 4.5 V\n10 µF bypass]
  RX[RX transducer] --> CIN[10 nF series]
  CIN --> APLUS[LM358 pin 3 +]
  VREF --> APBIAS[1 MΩ bias to pin 3]
  AOUT[LM358 pin 1] --> AFB[100 kΩ feedback]
  AFB --> AMIN[LM358 pin 2 -]
  AMIN --> ARG[10 kΩ to VREF]
  AOUT --> C12[10 nF coupling]
  C12 --> BPLUS[LM358 pin 5 +]
  VREF --> BPBIAS[1 MΩ bias to pin 5]
  BOUT[LM358 pin 7] --> BFB[100 kΩ feedback]
  BFB --> BMIN[LM358 pin 6 -]
  BMIN --> BRG[10 kΩ to VREF]
  BOUT --> CENV[10 nF AC coupling]
  CENV --> DIODE[1N4148 anode]
  DIODE --> ENV[Envelope node]
  ENV --> CENVH[100 nF to GND]
  ENV --> RENV[1 kΩ to GND]
  ENV --> CP[LM393 pin 3 + via 10 kΩ]
  POT[10 kΩ threshold pot\nends +5 V and GND] --> CN[LM393 pin 2 -]
  OUT[LM393 pin 1 open collector] --> HYS[100 kΩ hysteresis]
  HYS --> CP
  OUT --> PULL[10 kΩ pull-up to Uno +5 V]
  PULL --> D3[Uno D3]
```

Add 100 nF directly across the supply pins of each IC. LM358 pins 8/4 use +9 V/GND; LM393 pins 8/4 use Uno +5 V/GND. All signal grounds return to the star point. The envelope diode polarity, gain, and threshold must be checked on a scope with the actual transducers.
