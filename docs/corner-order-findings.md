# §15.5 resolved: per-corner order is FL, FR, RL, RR (2026-09-29)

Three independent methods (workflow `corner-order-investigation`), all high confidence, plus an
independent reproduction of the strongest one. Scripts: scratchpad/corner/.

## Frame handedness (needed by the kinematic method)
Projected GPS path (x = lon·cos lat, y = lat) winds CCW on Interlagos (signed lap area +396,329 m²,
net heading +359°) and CW on Spa (−926,623 m²) and Sebring School (18/18 laps −0.28 km²). Real
circuits: Interlagos anti-clockwise, Spa clockwise ⇒ the frame is not mirrored.

## Evidence
1. **Wheel-speed kinematics** (strongest, no GPS noise): over a closed lap the heading turns ±2π,
   so ∫(v_left − v_right)dt = −T·Θ. Measured ∫(v1−v2)dt per lap: Interlagos (CCW) −10.56/−10.58 m;
   Spa (CW) +10.26/+10.24 m; Sebring (CW) +10.57…+10.63 m on all 18 laps. ⇒ T = 1.68 m (GT3 front),
   1.63 m (Hypercar) with value1 = LEFT; value1 = RIGHT would need T = −1.7 m. Rear pair identical
   (v3−v4). Instantaneous OLS slope −1.68 m, corr −0.996, same in left and right turns.
2. **Thermal/pressure/wear by known circuit direction** (needs no GPS frame): outside tyres of the
   dominant turn run hotter. CW Sebring lap 18 carcass FL 93.4 vs FR 83.3 °C; CCW Interlagos FR 65.0
   vs FL 58.8 °C. Sebring wear over 18 laps FL 99.39→92.12 (fastest), FR →94.67, RL →94.50, RR →95.04.
3. **Roll**: (RideHeights v1 − v2) vs lateral accel: inside wheel rises; corr +0.95…+0.99.

CarSetup offers no answer key: all 15 WM_*-W_{FL,FR,RL,RR} groups are L/R symmetric in all three
files, and each setup carries `"symmetric": true`.

## Other findings worth keeping (for Tires & Brakes, Technique, SPEC §5.4)
- **G channels are swapped in the export.** `G Force Long` is LATERAL (positive = left): corr with
  steering −0.81…−0.85, slope vs GPS lateral accel 1.005. `G Force Lat` is LONGITUDINAL (positive =
  decelerating): corr with Brake Pos +0.67…+0.88, slope vs dv/dt −1.00. Any G-G / friction-circle
  view built on the names is wrong.
- Steering Pos positive = steering right.
- `TyresTempLeft/Centre/Right` are car-frame edges, not inner/outer. Inner edge hotter on all four
  (negative camber): left wheels (v1, v3) inner = TempRight, outer = TempLeft; right wheels (v2, v4)
  inner = TempLeft, outer = TempRight. Inner−outer spread 4–13 °C. Zone temps are damped (lag
  2–2.8 s behind lateral load) — a slow tread temperature, not a surface flash reading.
- Carcass 5 Hz, Rubber 10 Hz, Rim 50 Hz (°C). Practice/Qualify start at ambient (27/18 °C); the
  Race starts ~73–77 °C (pre-heated). Race tyre temps move only 1.3–2.6 °C within a lap; lap-to-lap
  drift dominates ⇒ per-lap mean is the right summary.
- `TyresPressure` kPa, continuous; setup (cold) 136/131/136 kPa; running 145–177 kPa. Sebring race
  starts at 171.7 kPa (warm tyres). Setup pressure is a reference, not the first sample.
- `Tyres Wear` = % remaining (100 new, decreasing). Per lap ≈0.8–1.1 (Interlagos GT3), 1.0–1.4 (Spa
  Hyper), 0.23–0.51 (Sebring GT3). Spa lap-3 spin drops RR 96.1→88.8 in one lap.
- `Brakes Temp` °C 50 Hz, 18–692; swings 415–467 within a lap. Brakes Temp v1 > v2 in all files
  regardless of direction (cause unknown). `Brakes Air Temp` °C 18–321.
- `Brake Thickness` declared "%" but is disc thickness in **cm** = WM_BRAKEDISC (3.56 F / 3.20 R
  GT3, 4.00 Hyper), effectively constant ⇒ a setup value, not a trace.
- `Brakes Force` declared "%" but is a 0–0.56 fraction = pedal × brake-pressure setting × axle bias
  share; front share at max reproduces setup brake balance (0.505 vs 50.5:49.5).
- `Wheel Speed` m/s, ≥0, ≈ Ground Speed; shows no longitudinal slip ⇒ cannot drive a lock-up view.
- GPS Latitude is FLOAT32 (0.42 m steps) — curvature needs ≥3-sample chords.
