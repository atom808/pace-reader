// LMU results files for tests, shaped exactly like the real ones in
// `UserData\Log\Results` (DOCTYPE, CRLF line ends, `--.---` placeholders,
// `&quot;` inside event text), with invented drivers.
//
// `bahrainPracticeXml` keeps the real lap and sector times of the user's
// 5 Nov 2026 Bahrain practice, which matched its recording
// (`Bahrain International Circuit_P_2026-11-05T02_38_28Z.duckdb`) to
// 0.0001 s, trimmed to five laps. `sartheRaceXml` is a three-car online race.

String _crlf(String s) => s.replaceAll('\n', '\r\n');

/// 2026-11-05 02:37:23Z: 65 s before the recording's 02:38:28Z.
const bahrainPracticeStartEpoch = 1793846243;

final bahrainPracticeXml = _crlf('''
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE rF [
<!ENTITY rFEnt "rFactor Entity">
]>
<rFactorXML version="1.0">
<RaceResults>
<Setting>Race Weekend</Setting>
<ServerName></ServerName>
<ClientFuelVisible>2</ClientFuelVisible>
<PlayerFile>Settings</PlayerFile>
<DateTime>1793846243</DateTime>
<TimeString>2026/11/04 23:37:23</TimeString>
<TrackVenue>Bahrain International Circuit</TrackVenue>
<TrackCourse>Bahrain International Circuit</TrackCourse>
<TrackEvent>8 Hours of Bahrain</TrackEvent>
<TrackData>C:\\Program Files (x86)\\Steam\\steamapps\\common\\Le Mans Ultimate\\Installed\\Locations\\BahrainWEC_2023\\1.27\\layoutBahrain.mas</TrackData>
<TrackLength>5386.8</TrackLength>
<GameVersion>1.4200</GameVersion>
<Dedicated>0</Dedicated>
<ConnectionType upload="100000" download="100000">Custom</ConnectionType>
<RaceLaps>0</RaceLaps>
<RaceTime>60</RaceTime>
<MechFailRate>1</MechFailRate>
<DamageMult>100</DamageMult>
<FuelMult>1</FuelMult>
<TireMult>1</TireMult>
<VehiclesAllowed>Hyper,</VehiclesAllowed>
<ParcFerme>3</ParcFerme>
<FixedSetups>0</FixedSetups>
<FreeSettings>0</FreeSettings>
<FixedUpgrades>0</FixedUpgrades>
<TireWarmers>0</TireWarmers>
<Practice1>
<DateTime>1793846245</DateTime>
<TimeString>2026/11/04 23:37:25</TimeString>
<Laps>2147483647</Laps>
<Minutes>60</Minutes>
<Stream>
<TrackLimits Driver="Test Driver" ID="0" Lap="3" WarningPoints="0" CurrentPoints="0" Resolution="7" et="503.9">No Further Action</TrackLimits>
<TrackLimits Driver="Test Driver" ID="0" Lap="3" WarningPoints="0" CurrentPoints="0" Resolution="5" et="510.2">Invalid Lap Cut Track</TrackLimits>
</Stream>
<MostLapsCompleted>5</MostLapsCompleted>
<Driver>
<Name>Test Driver</Name>
<Connected>1</Connected>
<VehFile>50_26_FERR45066807.VEH</VehFile>
<UpgradeCode>00000000 00000000 00000000 00000000</UpgradeCode>
<VehName>Ferrari AF Corse 2026 #50:LM</VehName>
<Category>WEC 2026, Hypercar, Ferrari 499P</Category>
<CarType>Ferrari 499P</CarType>
<CarClass>Hyper</CarClass>
<CarNumber>50</CarNumber>
<TeamName>Ferrari AF Corse</TeamName>
<isPlayer>1</isPlayer>
<ServerScored>1</ServerScored>
<Position>1</Position>
<ClassPosition>1</ClassPosition>
<LapRankIncludingDiscos>1</LapRankIncludingDiscos>
<Lap num="1" p="1" et="--.---" topspeed="270.46" fuel="0.694" fuelUsed="0.024" ve="0.969" veUsed="0.031" twfl="0.988" twfr="0.988" twrl="0.984" twrr="0.988" fcompound="1,Medium" rcompound="1,Medium" FL="1,Medium" FR="1,Medium" RL="1,Medium" RR="1,Medium">--.----</Lap>
<Lap num="2" p="1" et="201.4094" s1="33.3804" s2="49.2028" s3="27.2932" topspeed="293.69" fuel="0.671" fuelUsed="0.024" ve="0.937" veUsed="0.031" twfl="0.969" twfr="0.973" twrl="0.976" twrr="0.976" fcompound="1,Medium" rcompound="1,Medium" FL="1,Medium" FR="1,Medium" RL="1,Medium" RR="1,Medium">109.8764</Lap>
<Lap num="3" p="1" et="311.2858" s1="32.7442" s2="48.6046" s3="26.8033" topspeed="297.79" fuel="0.647" fuelUsed="0.024" ve="0.902" veUsed="0.035" twfl="0.957" twfr="0.969" twrl="0.965" twrr="0.969" fcompound="1,Medium" rcompound="1,Medium" FL="1,Medium" FR="1,Medium" RL="1,Medium" RR="1,Medium">108.1520</Lap>
<Lap num="4" p="1" et="419.4378" topspeed="297.39" fuel="0.620" fuelUsed="0.027" ve="0.867" veUsed="0.035" twfl="0.945" twfr="0.961" twrl="0.957" twrr="0.957" fcompound="1,Medium" rcompound="1,Medium" FL="1,Medium" FR="1,Medium" RL="1,Medium" RR="1,Medium">107.7979</Lap>
<Lap num="5" p="1" et="527.2357" topspeed="0.00" fuel="0.718" fuelUsed="-0.322" ve="1.000" veUsed="-0.439" twfl="1.000" twfr="1.000" twrl="1.000" twrr="1.000" fcompound="1,Medium" rcompound="1,Medium" FL="1,Medium" FR="1,Medium" RL="1,Medium" RR="1,Medium">--.----</Lap>
<BestLapTime>107.7979</BestLapTime>
<Laps>5</Laps>
<Pitstops>0</Pitstops>
<FinishStatus>None</FinishStatus>
<ControlAndAids startLap="1" endLap="5">PlayerControl,Clutch,AutoBlip</ControlAndAids>
</Driver>
</Practice1>
</RaceResults>
</rFactorXML>
''');

/// 2026-10-23 02:42:04Z.
const sartheRaceStartEpoch = 1792723324;

final sartheRaceXml = _crlf('''
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE rF [
<!ENTITY rFEnt "rFactor Entity">
]>
<rFactorXML version="1.0">
<RaceResults>
<Setting>Multiplayer</Setting>
<ServerName>Test Server 2</ServerName>
<DateTime>1792722000</DateTime>
<TimeString>2026/10/22 23:20:00</TimeString>
<TrackVenue>Circuit de la Sarthe</TrackVenue>
<TrackCourse>Circuit de la Sarthe</TrackCourse>
<TrackEvent>24 Hours of Le Mans</TrackEvent>
<TrackLength>13626.0</TrackLength>
<GameVersion>1.4150</GameVersion>
<RaceLaps>0</RaceLaps>
<RaceTime>60</RaceTime>
<DamageMult>50</DamageMult>
<FuelMult>2</FuelMult>
<TireMult>3</TireMult>
<Race>
<DateTime>1792723324</DateTime>
<TimeString>2026/10/22 23:42:04</TimeString>
<Laps>2147483647</Laps>
<Minutes>60</Minutes>
<Stream>
<Score et="605.5">Driver One(10) lap=3 point=0 t=207.063 et=605.520</Score>
<ChatMessage et="610.0">Someone: gg</ChatMessage>
<Incident et="2965.7">Driver One(10) reported contact (1081.22) with Immovable</Incident>
<Incident et="2965.7">Driver One(10) reported contact (54.77) with Wing</Incident>
<Incident et="3001.0">Driver Two(31) reported contact (221.88) with another vehicle Driver One(10)</Incident>
<Sector et="3100.4">Driver Two(31) reports new suspension damage</Sector>
<Penalty Driver="Driver Two" ID="31" Penalty="Drive Thru" Time="0" Laps="0" Reason="Track Limits" et="3200.8">Driver Two received Drive Thru penalty, 0s, 0laps for Track Limits. Result: penalties=1, 1st=Drive Thru,0s</Penalty>
<Penalty et="3300.6">Driver Two served 1st Drive Thru penalty, result: penalties=0, 1st=Drive Thru,0s</Penalty>
<DriverChange et="3400.0">Slot=44 Vehicle=&quot;Lexus Custom Team 2026 #397&quot; Old=&quot;Driver Three&quot; New=&quot;Driver Four&quot;</DriverChange>
<Sent et="3401.5">Driver Four Is now driving #397 Lexus Custom Team</Sent>
</Stream>
<FormationAndStart>1</FormationAndStart>
<MostLapsCompleted>3</MostLapsCompleted>
<Driver>
<Name>Driver One</Name>
<Connected>1</Connected>
<VehFile>35_26_ALPINE.VEH</VehFile>
<VehName>Alpine Endurance Team 2026 #35:LM</VehName>
<Category>WEC 2026, Hypercar, Alpine A424</Category>
<CarType>Alpine A424</CarType>
<CarClass>Hyper</CarClass>
<CarNumber>35</CarNumber>
<TeamName>Alpine Endurance Team</TeamName>
<isPlayer>1</isPlayer>
<Position>1</Position>
<ClassPosition>1</ClassPosition>
<GridPos>4</GridPos>
<ClassGridPos>3</ClassGridPos>
<Lap num="1" p="3" et="186.5025" topspeed="331.10" fuel="0.950" fuelUsed="0.050" twfl="0.990" twfr="0.990" twrl="0.990" twrr="0.990" fcompound="1,Medium" rcompound="1,Medium">--.----</Lap>
<Lap num="2" p="2" et="398.6399" s1="41.1" s2="79.9" s3="85.8879" topspeed="333.00" fuel="0.900" fuelUsed="0.050" twfl="0.970" twfr="0.975" twrl="0.972" twrr="0.973" fcompound="1,Medium" rcompound="1,Medium">206.8879</Lap>
<Lap num="3" p="1" et="605.5200" s1="41.0" s2="80.0" s3="86.0628" topspeed="333.33" fuel="0.850" fuelUsed="0.050" twfl="0.950" twfr="0.955" twrl="0.952" twrr="0.953" fcompound="1,Medium" rcompound="1,Medium" pit="1">207.0628</Lap>
<BestLapTime>206.8879</BestLapTime>
<FinishTime>812.6001</FinishTime>
<Laps>3</Laps>
<Pitstops>1</Pitstops>
<FinishStatus>Finished Normally</FinishStatus>
</Driver>
<Driver>
<Name>Driver Two</Name>
<Connected>1</Connected>
<VehFile>397_26_BMWMH.VEH</VehFile>
<VehName>BMWMH Custom Team 2026 #397</VehName>
<Category>WEC 2026, Hypercar, BMW M Hybrid V8</Category>
<CarType>BMW M Hybrid V8</CarType>
<CarClass>Hyper</CarClass>
<CarNumber>212</CarNumber>
<TeamName>Test Team 212</TeamName>
<isPlayer>0</isPlayer>
<Position>2</Position>
<ClassPosition>2</ClassPosition>
<Lap num="1" p="1" et="186.0000" topspeed="330.00" fuel="0.950" fuelUsed="0.050">--.----</Lap>
<Lap num="2" p="1" et="398.0000" s1="41.0" s2="79.5" s3="85.6" topspeed="332.00" fuel="0.900" fuelUsed="0.050">206.1000</Lap>
<BestLapTime>206.1000</BestLapTime>
<Laps>2</Laps>
<Pitstops>0</Pitstops>
<FinishStatus>DNF</FinishStatus>
<DNFReason>Accident</DNFReason>
</Driver>
<Driver>
<Name>Driver Four</Name>
<Connected>1</Connected>
<VehFile>397_26_LEXUS.VEH</VehFile>
<VehName>Lexus Custom Team 2026 #397</VehName>
<Category>WEC 2026, LMGT3, Lexus RC F LMGT3</Category>
<CarType>Lexus RC F LMGT3</CarType>
<CarClass>GT3</CarClass>
<CarNumber>397</CarNumber>
<TeamName>Test Team 397</TeamName>
<isPlayer>0</isPlayer>
<Position>3</Position>
<ClassPosition>1</ClassPosition>
<Lap num="1" p="3" et="190.0000" fuel="0.950" fuelUsed="0.050">--.----</Lap>
<Laps>1</Laps>
<Pitstops>0</Pitstops>
<FinishStatus>Finished Normally</FinishStatus>
<ControlAndAids startLap="1" endLap="1">UnknownControl</ControlAndAids>
<Swap startLap="1" endLap="1">???</Swap>
<Swap startLap="1" endLap="1">Driver Three</Swap>
<Swap startLap="1" endLap="1">Driver Four</Swap>
</Driver>
</Race>
</RaceResults>
</rFactorXML>
''');
