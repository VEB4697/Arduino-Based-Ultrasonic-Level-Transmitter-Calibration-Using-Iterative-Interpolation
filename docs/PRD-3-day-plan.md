# Mission PRD: Discrete Ultrasonic Water-Level Instrument

**Status:** Day 1 design and source package complete; hardware validation remains.  
**Mission:** Build a low-cost, top-mounted ultrasonic transmitter/receiver from discrete electronics; calculate tank level with measured calibration and interpolation; display live level and system state in MATLAB; command a pump relay with safe defaults; preserve time-series history.

## User need

The user wants to fabricate the ultrasonic transmitter and receiver from commonly available ICs and components rather than use an integrated ultrasonic sensor; connect an Arduino Uno to MATLAB through a COM port; calibrate the water-level result using interpolation; operate a pump relay; and receive circuit, BOM, soldering layout, code, and a practical staged build plan.

## Goals and measurable requirements

1. **Acoustic measurement:** transmit a short 40 kHz burst and detect the water-surface echo with a separate receiver. Produce raw echo time in microseconds and uncalibrated air gap in millimetres.
2. **Calibrated level:** determine level from a measured empty/reference distance and a tank-specific calibration table. Apply piecewise linear interpolation and an iterative correction using calibration residuals. Reject out-of-range values instead of silently extrapolating.
3. **HMI:** MATLAB shows level, air gap, raw time, valid/invalid state, pump state, serial state, live trend, and an append-only session log export.
4. **Control:** pump starts below a low threshold and stops above a high threshold, with hysteresis, explicit MATLAB commands, and a firmware communications timeout that turns the output off.
5. **Buildability:** publish a component list, point-to-point circuit connections, zero-PCB hole plan, assembly sequence, commissioning process, and electrical safety instructions.

## Day plan

### Day 1 — design package and software baseline (complete)

- Fixed architecture and interface boundaries: separate 40 kHz TX/RX cans, 555 burst source, BJT output stage, two-stage op-amp receiver, diode envelope detector, comparator, Uno timing/relay/serial, MATLAB HMI/calibration.
- Wrote this PRD, hardware/BOM/zero-PCB plan, protocol, Arduino sketch, MATLAB HMI, and starter calibration table.
- Defined fail-safe output behavior: relay defaults OFF; malformed commands and serial timeout keep it OFF; commands are bounded by local level limits.
- Open items for bench: verify actual transducer drive limits, receiver gain/stability, echo polarity/threshold, and tank geometry before calibration.

**Day 1 exit criteria:** all source/design files exist; pin and packet assignments agree across firmware and MATLAB; hazards and the mains boundary are documented; the user can start assembly without relying on the reference images alone.

### Day 2 — assemble and characterize electronics

- Buy parts and verify exact package pinouts/datasheets. Build supply decoupling, 555 transmitter, and analog receive chain on separate zero-PCB sections.
- Check 555 output frequency and burst length with an oscilloscope before attaching the transducer. Confirm transistor current and transducer rating.
- Inject/test receiver at 40 kHz, observe each amplifier stage and comparator output, set threshold, and check blanking/ring-down.
- Wire Uno and test serial in MATLAB with a fixed echo/bench target; tune gain, blanking, and timeout. Test relay with an LED only.

**Day 2 exit criteria:** clean 40 kHz burst within transducer rating; repeatable comparator edge on a stationary reflector; valid serial packets; no false relay energization on disconnect/reset.

### Day 3 — tank calibration and guarded operation

- Mount above a still-water tank; measure tank reference geometry and fill at ruler-verified increments across the usable range.
- Record raw echo distance versus actual level, create the calibration CSV, inspect residuals, and apply piecewise interpolation/correction only within the calibration span.
- Test empty/full, splash, inlet, foam, obstruction, lost echo, sensor disconnection, MATLAB closure, USB removal, Uno reset, and both relay thresholds.
- Review independent float switches, maximum pump runtime, overflow protection, enclosure, strain relief, fusing, and electrician-approved isolation before pump integration.

**Day 3 exit criteria:** repeatability/error documented over the calibrated range; pump starts/stops at the required thresholds with hysteresis; every fault state leaves the pump off or is independently interrupted by hardwired safety devices; user signs off before unattended use.

## Acceptance checklist

- [ ] No integrated range sensor is used; separate transducers and analog receive electronics are present.
- [ ] UNO sends raw timing/measurement and system status over USB serial.
- [ ] MATLAB receives live data, applies the calibration table, displays a trend, and saves timestamped history.
- [ ] Interpolation uses sorted measured points, rejects out-of-range points, and reports the calibration revision/validity.
- [ ] Relay command is hysteretic, bounded, fail-off on serial loss, and bench-tested at low voltage.
- [ ] Hardware is built and inspected against the datasheets; actual water tests document error and repeatability.
- [ ] Pump power is isolated and protected independently of this prototype.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Weak or missed echo, splashing, foam, multipath | Separate TX/RX, rigid aligned mounting, quiet-zone placement, median filtering, echo-valid status, hardwired level switches |
| 555 burst amplitude/current exceeds transducer rating | Verify transducer datasheet and scope the drive; current-limit/series resistor as required; no assumed 9 V rating |
| Receiver oscillates or saturates from TX feedthrough | Separate physical sections, ground return discipline, staged gain, blanking, scope checks, shield/partition if needed |
| MATLAB/USB disconnect leaves pump running | Firmware communication timeout and default-off relay; independent safety switches and contactor |
| Calibration extrapolated beyond measured tank | HMI rejects out-of-range values and shows invalid; recalibrate after mechanical changes |
| Mains shock, fire, or overflow | No mains on prototype board; enclosure, fuse, isolation, electrician, independent float/thermal protection |

## Explicit assumptions and open decisions

- Prototype target is a small stationary tank with roughly 0.3–2.0 m usable air gap; the 1.5 ms receiver blanking interval makes the near dead zone at least about 0.26 m, and actual transducer geometry can increase it.
- Transducers are a matched 40 kHz open-type transmitter and receiver, not a sealed integrated module.
- The pump's voltage/current and required relay ratings are not supplied; select the final contactor from the pump nameplate.
- The image schematics are reference-only and have unclear supply/ground/pin details. Verify all IC pinouts against the exact datasheet before wiring.
- The project is a prototype and not a safety-rated industrial control.
