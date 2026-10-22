# MATLAB HMI, Calibration, and Hardware Bring-Up

## What the MATLAB program does

`matlab/tank_hmi.m` creates a MATLAB UI figure with a COM-port field, connection status, large calibrated level value, raw air gap, echo time, pump state, live level trend, and an export button. It opens an ASCII serial connection at 115200 baud and reads the firmware's `D,...` line. Each valid echo is converted from raw distance to level using the calibration CSV. A reading outside the table range is marked invalid and the requested pump state is forced off.

The pump controller keeps state between thresholds. Below `LOW_LEVEL_MM` it requests ON; above `HIGH_LEVEL_MM` it requests OFF; in between it retains its prior state. The two thresholds must be selected from the real tank's safe operating range and kept apart to prevent rapid switching. A 0.5 second heartbeat sends `P,0` or `P,1`; loss of valid recent data sends OFF. The Arduino independently forces the relay off after command timeout or invalid/stale measurement.

The session records host timestamp, Arduino milliseconds, echo time, raw gap, calibrated level, echo validity, and reported relay state in memory. **Export History CSV** writes those session samples to `matlab/history.csv`. Close the window or disconnecting the COM link sends an OFF request before closing where possible; the firmware timeout remains the fallback.

## COM port setup

1. Upload the firmware to the Uno and open the operating system's device list to identify its COM port.
2. Close Arduino Serial Monitor/Plotter because only one program can own the serial port at a time.
3. Run `tank_hmi` in MATLAB with the `matlab` folder as current folder or on the MATLAB path. Enter the actual port name, for example `COM5`, then select **Connect**.
4. Confirm the UI receives raw gap readings and that the displayed level is invalid until a real calibration table replaces the example data.

## Create a real tank calibration table

The committed `calibration_template.csv` contains illustrative 300–1800 mm raw-gap points for a hypothetical 2 m tank only. They are not measured data and must not be used to control a real pump. Replace them with measured `RawGap_mm` and `ReferenceLevel_mm` pairs for the installation. `ResidualCorrection_mm` starts at zero and can hold the iterative correction described below.

1. Measure the reference distance from the acoustic face to the tank's level datum. Mark the usable water-level span and the sensor's near-field dead zone.
2. With pump control disconnected, take repeated readings at several ruler-measured levels spanning the usable range. Include more points where nonlinearity or tank geometry changes; record the median raw gap and actual level at each point.
3. Sort rows by raw gap; no duplicate raw-gap keys. MATLAB linearly interpolates only between the first and last measured gap. Outside the range, the HMI requests pump off and displays INVALID.
4. Reserve intermediate levels as holdout checks where practical. Compare the HMI estimate with the ruler reference and calculate residual `e = reference_level - interpolated_level`.
5. To iteratively correct, add correction knots in `ResidualCorrection_mm`, using measured residuals at corresponding raw gaps, interpolate the residual correction linearly, refill/check the holdout levels, and repeat with fresh independent measurements. Avoid fitting and validating on the same set only.
6. Save a copy of every table revision with date, tank geometry, mounting position, water temperature, firmware revision, and measured residuals. Recalibrate after moving the transducers or changing tank geometry.

For adjacent knots `(x0,y0)` and `(x1,y1)`, the base estimate is `y=y0+(x-x0)*(y1-y0)/(x1-x0)`. With correction knots `(x,e)`, the displayed estimate is `y_corrected=y+e(x)`. This is piecewise linear interpolation plus an iteratively updated residual table; it is not an extrapolator or a guarantee of accuracy beyond observed data.

## Day 2 receiver tuning support

With the Uno connected, watch `Air gap`, `Echo`, and status while using a fixed flat reflector. First observe the LM358 outputs, detector node, and comparator output with a scope. Set threshold above noise/ring-down and below the weakest repeatable reflector echo. If comparator transitions occur before the blanking time or randomly with no reflector, improve TX/RX separation and grounding, reduce gain, and inspect the threshold before changing firmware. Record actual blanking, carrier frequency, and missed-echo rate in the Day 2 log.

## Known Day 1 limits

- Firmware estimates sound speed as 343 m/s; temperature compensation is not fitted.
- The discrete receiver circuit has not yet been measured on this user's selected components. Distances, echo polarity, and the usable tank range must be verified at the bench.
- History is held in MATLAB memory until CSV export; use the export button regularly for a long run.
- The HMI uses the local PC clock for log timestamps; firmware milliseconds are included for relative timing.
- The relay command is a prototype supervisor. Use an independent hardwired overflow cutout and pump protection.
