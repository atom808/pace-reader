/// Every threshold Suspension decides with, each beside the measurement that
/// set it (suspension proposal §5, §8.1). Provisional ones say so: the probe
/// step on the 501-file library is where they get settled.
library;

/// A corner under this is a **Strike** (D6), metres. Provisional: at
/// Indianapolis entry 26 of 36 Le Mans race laps read under it, and the
/// Sebring GT3 bumps read −6.6 to −10.5 mm on asphalt.
const strikeFloorMetres = 0.006;

/// Above the floor by up to this is **Close** (D6): drawn fainter and left
/// out of the headline counts, metres.
const closeBandMetres = 0.003;

/// Strikes are looked for above this speed, km/h: below it the car is in a
/// hairpin or the pit lane, and a low reading is the car squatting, not a
/// strike.
const strikeMinSpeedKph = 60.0;

/// Candidate samples less than this many master rows apart (10 ms each) are
/// one strike: a touchdown that lifts for a sample or two is still one.
const strikeMergeGapRows = 5;

/// Brake over this anywhere in a strike makes it a braking strike, % (§5).
const brakingPedalPercent = 10.0;

/// Deceleration over this at the lowest point makes it a braking strike, G.
const brakingDecelerationG = 0.5;

/// |Lateral G| over this at the lowest point makes it a corner strike, G.
const cornerLateralG = 1.0;

/// Strikes from different laps within this of each other are one site, m.
/// At Indianapolis the 26 struck laps' lowest points fall within 1 m, SD
/// 0.3 m (§1), so 25 m joins one bump's laps without joining two bumps.
const siteJoinMetres = 25.0;

/// A site's view spans this either side of its place, m.
const siteWindowMetres = 150.0;

/// Each lap's lowest point at a site is looked for this far either side of
/// the site's place, m: the join distance, so a lap's minimum is the same
/// bump, not another one in the window.
const siteSearchMetres = 25.0;

/// A site needs strikes on at least this many laps.
const siteMinLaps = 2;

/// The verdict needs this many laps with a lowest point at the site.
const verdictMinLaps = 8;

/// |r| at or above this counts as "goes with" (§5).
const verdictMinR = 0.4;

/// A site struck on at least this share of laps, with neither r reaching
/// [verdictMinR], is struck **every lap**.
const everyLapShare = 0.9;

/// Laps within this share of a site's median speed are comparable: with the
/// speed held, a difference left over is line or inputs (§5).
const comparableSpeedShare = 0.01;

/// When fewer than two laps fall within [comparableSpeedShare], the band
/// widens to this.
const comparableSpeedShareWide = 0.03;

/// The platform is read above this speed, km/h: packer time, ride heights.
const platformSpeedKph = 100.0;

/// A third element within this of its ceiling is on its packers, metres.
/// The ceiling repeats to ±0.03 mm across 30 Alpine files (§3), so 0.3 mm
/// is ten times the noise and well under the travel.
const packerMarginMetres = 0.0003;

/// Roll is fitted on samples with |lateral G| over this.
const rollMinG = 0.3;

/// A lap whose front-to-rear roll ratio moves this far (as a share) from the
/// previous laps' median is marked "balance changed here": the 499P's
/// in-car bar steps showed as 10–60 % ratio steps (SPEC.md §5.4).
const balanceStepShare = 0.12;

/// How many previous laps the balance step is measured against.
const balanceWindowLaps = 3;
