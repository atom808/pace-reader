/// The recording's channel and event table names, typed once (map stage
/// proposal §14.1).
///
/// Every name here is a table in the `.duckdb` file, spelled exactly as the
/// game writes it — spaces, capitals and its own abbreviations included —
/// because the SQL quotes them verbatim. Features keep their own named
/// aliases (`techniqueBrakeChannel`, `tyrePressureChannelName`, …) where the
/// alias says what *they* use a channel for; those aliases point here rather
/// than retyping the string.
///
/// The constants are named after the game's names, not after their meaning,
/// on purpose: the meaning is sometimes not what the name says. The file's
/// `G Force Long` is the lateral axis and `G Force Lat` the longitudinal one
/// (both readers that use them, Suspension and Driving Technique, measured
/// this independently), so [Channels.gForceLong] is named for the table and
/// the alias that uses it says "lateral".
library;

/// Sampled channels (§5.1: value tables on the master grid).
abstract final class Channels {
  static const ambientTemperature = 'Ambient Temperature';
  static const brakePos = 'Brake Pos';
  static const brakesTemp = 'Brakes Temp';
  static const engineRpm = 'Engine RPM';
  static const fuelLevel = 'Fuel Level';
  static const front3rdDeflection = 'Front3rdDeflection';

  /// The lateral axis, despite its name — see the library comment.
  static const gForceLong = 'G Force Long';

  /// The longitudinal axis, despite its name — see the library comment.
  static const gForceLat = 'G Force Lat';
  static const gForceVert = 'G Force Vert';
  static const gpsLatitude = 'GPS Latitude';
  static const gpsLongitude = 'GPS Longitude';

  /// The master grid's clock (§5.2).
  static const gpsTime = 'GPS Time';
  static const groundSpeed = 'Ground Speed';
  static const lapDist = 'Lap Dist';
  static const pathLateral = 'Path Lateral';
  static const rear3rdDeflection = 'Rear3rdDeflection';
  static const rideHeights = 'RideHeights';
  static const soc = 'SoC';
  static const steeringPos = 'Steering Pos';
  static const suspPos = 'Susp Pos';
  static const throttlePos = 'Throttle Pos';
  static const throttlePosUnfiltered = 'Throttle Pos Unfiltered';
  static const timeBehindNext = 'Time Behind Next';
  static const totalDist = 'Total Dist';
  static const trackEdge = 'Track Edge';
  static const trackTemperature = 'Track Temperature';
  static const tyresCarcassTemp = 'TyresCarcassTemp';
  static const tyresPressure = 'TyresPressure';
  static const tyresRimTemp = 'TyresRimTemp';
  static const tyresTempCentre = 'TyresTempCentre';
  static const tyresTempLeft = 'TyresTempLeft';
  static const tyresTempRight = 'TyresTempRight';
  static const tyresWear = 'Tyres Wear';
  static const virtualEnergy = 'Virtual Energy';
}

/// Events (§5.1: `ts`/`value` tables written on change).
abstract final class Events {
  static const abs = 'ABS';
  static const absLevel = 'ABSLevel';
  static const bestLapTime = 'Best LapTime';
  static const brakeBiasRear = 'Brake Bias Rear';
  static const brakeMigration = 'Brake Migration';
  static const currentSector = 'Current Sector';
  static const fuelMixtureMap = 'FuelMixtureMap';
  static const gear = 'Gear';
  static const inPits = 'In Pits';
  static const lap = 'Lap';
  static const lapTime = 'Lap Time';
  static const lastImpactMagnitude = 'LastImpactMagnitude';
  static const lastSector1 = 'Last Sector1';
  static const lastSector2 = 'Last Sector2';
  static const minimumPathWetness = 'Minimum Path Wetness';
  static const speedLimiter = 'Speed Limiter';
  static const surfaceTypes = 'SurfaceTypes';
  static const tc = 'TC';
  static const tcCut = 'TCCut';
  static const tcLevel = 'TCLevel';
  static const tcSlipAngle = 'TCSlipAngle';
  static const tyresCompound = 'TyresCompound';
  static const wheelsDetached = 'WheelsDetached';
}
