# Serial Protocol and Calibration

## Wire format

USB serial is 115200 baud, 8-N-1. One ASCII line per message, LF terminated. Firmware emits a header on reset followed by:

`D,<millis>,<echo_us>,<distance_mm>,<valid>,<relay>,<temperature_C>`

`temperature_C` is `nan` in this Day 1 build; no temperature sensor is fitted. `valid` is 1 only when a rising comparator edge arrives inside the allowed window. `distance_mm` is one-way air distance computed as `echo_us * 0.343 / 2`; MATLAB applies tank-specific calibration afterward. Invalid readings use `-1` fields.

MATLAB sends `P,0` or `P,1` to request pump off/on. Firmware acknowledges with `A,<requested>,<actual>`. The current control is supervisory: firmware additionally rejects ON unless it has seen a valid echo recently and a valid level has been within configured guard distance. Configure the guard for the actual installation; independent float switches remain required.

## Interpolation model

Each row of `calibration_template.csv` maps a measured raw air gap (mm) to a ruler-measured water level (mm). Sort rows by raw gap. MATLAB uses piecewise linear interpolation between adjacent points. For a segment `(x0,y0),(x1,y1)`, `y=y0+(x-x0)*(y1-y0)/(x1-x0)`. It rejects values outside the table; no extrapolation is allowed.

For iterative residual calibration, compare interpolated values with independent reference measurements: `e_i = reference_i - estimate_i`. Store residual knots against raw gap and linearly interpolate residuals. Corrected result is `estimate + interpolated(e)`. Repeat fill-measure cycles until residuals meet the project's chosen tolerance. Do not use the same measurements as both the sole fit points and independent validation set; retain holdout check levels.

## Control behavior

The MATLAB HMI uses low/high level thresholds with hysteresis: below low asks ON; above high asks OFF; between thresholds it retains prior state. On serial loss, invalid/out-of-range level, or MATLAB closure, the firmware's watchdog turns the relay OFF. Firmware watchdog is not a replacement for hardwired float switches. Relay output is active-low only if using the recommended module; set `RELAY_ON_LEVEL` for the exact module after testing with an LED.
