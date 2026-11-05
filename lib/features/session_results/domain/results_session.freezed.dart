// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'results_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ResultsSession {

/// The session element's name, verbatim (`Practice1`).
 String get sessionElement; ResultsSessionKind get kind;/// The session's own `<DateTime>`, the second one in the file: UTC epoch
/// seconds. Unique across all 1,054 files measured. Never the file name
/// or `<TimeString>`, which are local time.
 DateTime get startedAt;/// The weekend's `<DateTime>`, the first in the file. Restarts of an
/// offline weekend share it, so it identifies nothing on its own.
 DateTime get weekendStartedAt;/// `Multiplayer` or `Race Weekend` (offline).
 String get setting; String get serverName;/// `= metadata.TrackName` of a recording of the same session.
 String get trackVenue;/// `= metadata.TrackLayout`.
 String get trackCourse;/// `8 Hours of Bahrain`.
 String get trackEvent; double? get trackLengthMetres; String get gameVersion;/// 0 for a timed race, which then has [raceMinutes].
 int? get raceLaps; int? get raceMinutes; double? get fuelMultiplier; double? get tyreMultiplier;/// `DamageMult`, a percentage: 100 is full damage.
 double? get damagePercent; List<ResultsDriver> get drivers;/// Race control's log, in file order. Timing lines (`Score`) and chat are
/// not read: the first repeats the laps, the second is other people's
/// conversation.
 List<ResultsEvent> get events;
/// Create a copy of ResultsSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResultsSessionCopyWith<ResultsSession> get copyWith => _$ResultsSessionCopyWithImpl<ResultsSession>(this as ResultsSession, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ResultsSession;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResultsSession&&(identical(other.sessionElement, _this.sessionElement) || other.sessionElement == _this.sessionElement)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.startedAt, _this.startedAt) || other.startedAt == _this.startedAt)&&(identical(other.weekendStartedAt, _this.weekendStartedAt) || other.weekendStartedAt == _this.weekendStartedAt)&&(identical(other.setting, _this.setting) || other.setting == _this.setting)&&(identical(other.serverName, _this.serverName) || other.serverName == _this.serverName)&&(identical(other.trackVenue, _this.trackVenue) || other.trackVenue == _this.trackVenue)&&(identical(other.trackCourse, _this.trackCourse) || other.trackCourse == _this.trackCourse)&&(identical(other.trackEvent, _this.trackEvent) || other.trackEvent == _this.trackEvent)&&(identical(other.trackLengthMetres, _this.trackLengthMetres) || other.trackLengthMetres == _this.trackLengthMetres)&&(identical(other.gameVersion, _this.gameVersion) || other.gameVersion == _this.gameVersion)&&(identical(other.raceLaps, _this.raceLaps) || other.raceLaps == _this.raceLaps)&&(identical(other.raceMinutes, _this.raceMinutes) || other.raceMinutes == _this.raceMinutes)&&(identical(other.fuelMultiplier, _this.fuelMultiplier) || other.fuelMultiplier == _this.fuelMultiplier)&&(identical(other.tyreMultiplier, _this.tyreMultiplier) || other.tyreMultiplier == _this.tyreMultiplier)&&(identical(other.damagePercent, _this.damagePercent) || other.damagePercent == _this.damagePercent)&&const DeepCollectionEquality().equals(other.drivers, _this.drivers)&&const DeepCollectionEquality().equals(other.events, _this.events));
}


@override
int get hashCode {
  final _this = this as ResultsSession;
  return Object.hash(runtimeType,_this.sessionElement,_this.kind,_this.startedAt,_this.weekendStartedAt,_this.setting,_this.serverName,_this.trackVenue,_this.trackCourse,_this.trackEvent,_this.trackLengthMetres,_this.gameVersion,_this.raceLaps,_this.raceMinutes,_this.fuelMultiplier,_this.tyreMultiplier,_this.damagePercent,const DeepCollectionEquality().hash(_this.drivers),const DeepCollectionEquality().hash(_this.events));
}

@override
String toString() {
  final _this = this as ResultsSession;
  return 'ResultsSession(sessionElement: ${_this.sessionElement}, kind: ${_this.kind}, startedAt: ${_this.startedAt}, weekendStartedAt: ${_this.weekendStartedAt}, setting: ${_this.setting}, serverName: ${_this.serverName}, trackVenue: ${_this.trackVenue}, trackCourse: ${_this.trackCourse}, trackEvent: ${_this.trackEvent}, trackLengthMetres: ${_this.trackLengthMetres}, gameVersion: ${_this.gameVersion}, raceLaps: ${_this.raceLaps}, raceMinutes: ${_this.raceMinutes}, fuelMultiplier: ${_this.fuelMultiplier}, tyreMultiplier: ${_this.tyreMultiplier}, damagePercent: ${_this.damagePercent}, drivers: ${_this.drivers}, events: ${_this.events})';
}


}

/// @nodoc
abstract mixin class $ResultsSessionCopyWith<$Res>  {
  factory $ResultsSessionCopyWith(ResultsSession value, $Res Function(ResultsSession) _then) = _$ResultsSessionCopyWithImpl;
@useResult
$Res call({
 String sessionElement, ResultsSessionKind kind, DateTime startedAt, DateTime weekendStartedAt, String setting, String serverName, String trackVenue, String trackCourse, String trackEvent, double? trackLengthMetres, String gameVersion, int? raceLaps, int? raceMinutes, double? fuelMultiplier, double? tyreMultiplier, double? damagePercent, List<ResultsDriver> drivers, List<ResultsEvent> events
});




}
/// @nodoc
class _$ResultsSessionCopyWithImpl<$Res>
    implements $ResultsSessionCopyWith<$Res> {
  _$ResultsSessionCopyWithImpl(this._self, this._then);

  final ResultsSession _self;
  final $Res Function(ResultsSession) _then;

/// Create a copy of ResultsSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionElement = null,Object? kind = null,Object? startedAt = null,Object? weekendStartedAt = null,Object? setting = null,Object? serverName = null,Object? trackVenue = null,Object? trackCourse = null,Object? trackEvent = null,Object? trackLengthMetres = freezed,Object? gameVersion = null,Object? raceLaps = freezed,Object? raceMinutes = freezed,Object? fuelMultiplier = freezed,Object? tyreMultiplier = freezed,Object? damagePercent = freezed,Object? drivers = null,Object? events = null,}) {
  return _then(ResultsSession(
sessionElement: null == sessionElement ? _self.sessionElement : sessionElement // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ResultsSessionKind,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,weekendStartedAt: null == weekendStartedAt ? _self.weekendStartedAt : weekendStartedAt // ignore: cast_nullable_to_non_nullable
as DateTime,setting: null == setting ? _self.setting : setting // ignore: cast_nullable_to_non_nullable
as String,serverName: null == serverName ? _self.serverName : serverName // ignore: cast_nullable_to_non_nullable
as String,trackVenue: null == trackVenue ? _self.trackVenue : trackVenue // ignore: cast_nullable_to_non_nullable
as String,trackCourse: null == trackCourse ? _self.trackCourse : trackCourse // ignore: cast_nullable_to_non_nullable
as String,trackEvent: null == trackEvent ? _self.trackEvent : trackEvent // ignore: cast_nullable_to_non_nullable
as String,trackLengthMetres: freezed == trackLengthMetres ? _self.trackLengthMetres : trackLengthMetres // ignore: cast_nullable_to_non_nullable
as double?,gameVersion: null == gameVersion ? _self.gameVersion : gameVersion // ignore: cast_nullable_to_non_nullable
as String,raceLaps: freezed == raceLaps ? _self.raceLaps : raceLaps // ignore: cast_nullable_to_non_nullable
as int?,raceMinutes: freezed == raceMinutes ? _self.raceMinutes : raceMinutes // ignore: cast_nullable_to_non_nullable
as int?,fuelMultiplier: freezed == fuelMultiplier ? _self.fuelMultiplier : fuelMultiplier // ignore: cast_nullable_to_non_nullable
as double?,tyreMultiplier: freezed == tyreMultiplier ? _self.tyreMultiplier : tyreMultiplier // ignore: cast_nullable_to_non_nullable
as double?,damagePercent: freezed == damagePercent ? _self.damagePercent : damagePercent // ignore: cast_nullable_to_non_nullable
as double?,drivers: null == drivers ? _self.drivers : drivers // ignore: cast_nullable_to_non_nullable
as List<ResultsDriver>,events: null == events ? _self.events : events // ignore: cast_nullable_to_non_nullable
as List<ResultsEvent>,
  ));
}

}


/// Adds pattern-matching-related methods to [ResultsSession].
extension ResultsSessionPatterns on ResultsSession {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ResultsSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ResultsSession() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ResultsSession value)  $default,){
final _that = this;
switch (_that) {
case _ResultsSession():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ResultsSession value)?  $default,){
final _that = this;
switch (_that) {
case _ResultsSession() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sessionElement,  ResultsSessionKind kind,  DateTime startedAt,  DateTime weekendStartedAt,  String setting,  String serverName,  String trackVenue,  String trackCourse,  String trackEvent,  double? trackLengthMetres,  String gameVersion,  int? raceLaps,  int? raceMinutes,  double? fuelMultiplier,  double? tyreMultiplier,  double? damagePercent,  List<ResultsDriver> drivers,  List<ResultsEvent> events)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ResultsSession() when $default != null:
return $default(_that.sessionElement,_that.kind,_that.startedAt,_that.weekendStartedAt,_that.setting,_that.serverName,_that.trackVenue,_that.trackCourse,_that.trackEvent,_that.trackLengthMetres,_that.gameVersion,_that.raceLaps,_that.raceMinutes,_that.fuelMultiplier,_that.tyreMultiplier,_that.damagePercent,_that.drivers,_that.events);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sessionElement,  ResultsSessionKind kind,  DateTime startedAt,  DateTime weekendStartedAt,  String setting,  String serverName,  String trackVenue,  String trackCourse,  String trackEvent,  double? trackLengthMetres,  String gameVersion,  int? raceLaps,  int? raceMinutes,  double? fuelMultiplier,  double? tyreMultiplier,  double? damagePercent,  List<ResultsDriver> drivers,  List<ResultsEvent> events)  $default,) {final _that = this;
switch (_that) {
case _ResultsSession():
return $default(_that.sessionElement,_that.kind,_that.startedAt,_that.weekendStartedAt,_that.setting,_that.serverName,_that.trackVenue,_that.trackCourse,_that.trackEvent,_that.trackLengthMetres,_that.gameVersion,_that.raceLaps,_that.raceMinutes,_that.fuelMultiplier,_that.tyreMultiplier,_that.damagePercent,_that.drivers,_that.events);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sessionElement,  ResultsSessionKind kind,  DateTime startedAt,  DateTime weekendStartedAt,  String setting,  String serverName,  String trackVenue,  String trackCourse,  String trackEvent,  double? trackLengthMetres,  String gameVersion,  int? raceLaps,  int? raceMinutes,  double? fuelMultiplier,  double? tyreMultiplier,  double? damagePercent,  List<ResultsDriver> drivers,  List<ResultsEvent> events)?  $default,) {final _that = this;
switch (_that) {
case _ResultsSession() when $default != null:
return $default(_that.sessionElement,_that.kind,_that.startedAt,_that.weekendStartedAt,_that.setting,_that.serverName,_that.trackVenue,_that.trackCourse,_that.trackEvent,_that.trackLengthMetres,_that.gameVersion,_that.raceLaps,_that.raceMinutes,_that.fuelMultiplier,_that.tyreMultiplier,_that.damagePercent,_that.drivers,_that.events);case _:
  return null;

}
}

}

/// @nodoc


class _ResultsSession extends ResultsSession {
  const _ResultsSession({required this.sessionElement, required this.kind, required this.startedAt, required this.weekendStartedAt, required this.setting, required this.serverName, required this.trackVenue, required this.trackCourse, required this.trackEvent, this.trackLengthMetres, required this.gameVersion, this.raceLaps, this.raceMinutes, this.fuelMultiplier, this.tyreMultiplier, this.damagePercent,  List<ResultsDriver> drivers = const <ResultsDriver>[],  List<ResultsEvent> events = const <ResultsEvent>[]}): _drivers = drivers,_events = events,super._();
  

/// The session element's name, verbatim (`Practice1`).
@override final  String sessionElement;
@override final  ResultsSessionKind kind;
/// The session's own `<DateTime>`, the second one in the file: UTC epoch
/// seconds. Unique across all 1,054 files measured. Never the file name
/// or `<TimeString>`, which are local time.
@override final  DateTime startedAt;
/// The weekend's `<DateTime>`, the first in the file. Restarts of an
/// offline weekend share it, so it identifies nothing on its own.
@override final  DateTime weekendStartedAt;
/// `Multiplayer` or `Race Weekend` (offline).
@override final  String setting;
@override final  String serverName;
/// `= metadata.TrackName` of a recording of the same session.
@override final  String trackVenue;
/// `= metadata.TrackLayout`.
@override final  String trackCourse;
/// `8 Hours of Bahrain`.
@override final  String trackEvent;
@override final  double? trackLengthMetres;
@override final  String gameVersion;
/// 0 for a timed race, which then has [raceMinutes].
@override final  int? raceLaps;
@override final  int? raceMinutes;
@override final  double? fuelMultiplier;
@override final  double? tyreMultiplier;
/// `DamageMult`, a percentage: 100 is full damage.
@override final  double? damagePercent;
 final  List<ResultsDriver> _drivers;
@override@JsonKey() List<ResultsDriver> get drivers {
  if (_drivers is EqualUnmodifiableListView) return _drivers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_drivers);
}

/// Race control's log, in file order. Timing lines (`Score`) and chat are
/// not read: the first repeats the laps, the second is other people's
/// conversation.
 final  List<ResultsEvent> _events;
/// Race control's log, in file order. Timing lines (`Score`) and chat are
/// not read: the first repeats the laps, the second is other people's
/// conversation.
@override@JsonKey() List<ResultsEvent> get events {
  if (_events is EqualUnmodifiableListView) return _events;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_events);
}


/// Create a copy of ResultsSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ResultsSessionCopyWith<_ResultsSession> get copyWith => __$ResultsSessionCopyWithImpl<_ResultsSession>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ResultsSession&&(identical(other.sessionElement, sessionElement) || other.sessionElement == sessionElement)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.weekendStartedAt, weekendStartedAt) || other.weekendStartedAt == weekendStartedAt)&&(identical(other.setting, setting) || other.setting == setting)&&(identical(other.serverName, serverName) || other.serverName == serverName)&&(identical(other.trackVenue, trackVenue) || other.trackVenue == trackVenue)&&(identical(other.trackCourse, trackCourse) || other.trackCourse == trackCourse)&&(identical(other.trackEvent, trackEvent) || other.trackEvent == trackEvent)&&(identical(other.trackLengthMetres, trackLengthMetres) || other.trackLengthMetres == trackLengthMetres)&&(identical(other.gameVersion, gameVersion) || other.gameVersion == gameVersion)&&(identical(other.raceLaps, raceLaps) || other.raceLaps == raceLaps)&&(identical(other.raceMinutes, raceMinutes) || other.raceMinutes == raceMinutes)&&(identical(other.fuelMultiplier, fuelMultiplier) || other.fuelMultiplier == fuelMultiplier)&&(identical(other.tyreMultiplier, tyreMultiplier) || other.tyreMultiplier == tyreMultiplier)&&(identical(other.damagePercent, damagePercent) || other.damagePercent == damagePercent)&&const DeepCollectionEquality().equals(other.drivers, _drivers)&&const DeepCollectionEquality().equals(other.events, _events));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sessionElement,kind,startedAt,weekendStartedAt,setting,serverName,trackVenue,trackCourse,trackEvent,trackLengthMetres,gameVersion,raceLaps,raceMinutes,fuelMultiplier,tyreMultiplier,damagePercent,const DeepCollectionEquality().hash(_drivers),const DeepCollectionEquality().hash(_events));
}

@override
String toString() {
    return 'ResultsSession(sessionElement: $sessionElement, kind: $kind, startedAt: $startedAt, weekendStartedAt: $weekendStartedAt, setting: $setting, serverName: $serverName, trackVenue: $trackVenue, trackCourse: $trackCourse, trackEvent: $trackEvent, trackLengthMetres: $trackLengthMetres, gameVersion: $gameVersion, raceLaps: $raceLaps, raceMinutes: $raceMinutes, fuelMultiplier: $fuelMultiplier, tyreMultiplier: $tyreMultiplier, damagePercent: $damagePercent, drivers: $drivers, events: $events)';
}


}

/// @nodoc
abstract mixin class _$ResultsSessionCopyWith<$Res> implements $ResultsSessionCopyWith<$Res> {
  factory _$ResultsSessionCopyWith(_ResultsSession value, $Res Function(_ResultsSession) _then) = __$ResultsSessionCopyWithImpl;
@override @useResult
$Res call({
 String sessionElement, ResultsSessionKind kind, DateTime startedAt, DateTime weekendStartedAt, String setting, String serverName, String trackVenue, String trackCourse, String trackEvent, double? trackLengthMetres, String gameVersion, int? raceLaps, int? raceMinutes, double? fuelMultiplier, double? tyreMultiplier, double? damagePercent, List<ResultsDriver> drivers, List<ResultsEvent> events
});




}
/// @nodoc
class __$ResultsSessionCopyWithImpl<$Res>
    implements _$ResultsSessionCopyWith<$Res> {
  __$ResultsSessionCopyWithImpl(this._self, this._then);

  final _ResultsSession _self;
  final $Res Function(_ResultsSession) _then;

/// Create a copy of ResultsSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionElement = null,Object? kind = null,Object? startedAt = null,Object? weekendStartedAt = null,Object? setting = null,Object? serverName = null,Object? trackVenue = null,Object? trackCourse = null,Object? trackEvent = null,Object? trackLengthMetres = freezed,Object? gameVersion = null,Object? raceLaps = freezed,Object? raceMinutes = freezed,Object? fuelMultiplier = freezed,Object? tyreMultiplier = freezed,Object? damagePercent = freezed,Object? drivers = null,Object? events = null,}) {
  return _then(_ResultsSession(
sessionElement: null == sessionElement ? _self.sessionElement : sessionElement // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ResultsSessionKind,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,weekendStartedAt: null == weekendStartedAt ? _self.weekendStartedAt : weekendStartedAt // ignore: cast_nullable_to_non_nullable
as DateTime,setting: null == setting ? _self.setting : setting // ignore: cast_nullable_to_non_nullable
as String,serverName: null == serverName ? _self.serverName : serverName // ignore: cast_nullable_to_non_nullable
as String,trackVenue: null == trackVenue ? _self.trackVenue : trackVenue // ignore: cast_nullable_to_non_nullable
as String,trackCourse: null == trackCourse ? _self.trackCourse : trackCourse // ignore: cast_nullable_to_non_nullable
as String,trackEvent: null == trackEvent ? _self.trackEvent : trackEvent // ignore: cast_nullable_to_non_nullable
as String,trackLengthMetres: freezed == trackLengthMetres ? _self.trackLengthMetres : trackLengthMetres // ignore: cast_nullable_to_non_nullable
as double?,gameVersion: null == gameVersion ? _self.gameVersion : gameVersion // ignore: cast_nullable_to_non_nullable
as String,raceLaps: freezed == raceLaps ? _self.raceLaps : raceLaps // ignore: cast_nullable_to_non_nullable
as int?,raceMinutes: freezed == raceMinutes ? _self.raceMinutes : raceMinutes // ignore: cast_nullable_to_non_nullable
as int?,fuelMultiplier: freezed == fuelMultiplier ? _self.fuelMultiplier : fuelMultiplier // ignore: cast_nullable_to_non_nullable
as double?,tyreMultiplier: freezed == tyreMultiplier ? _self.tyreMultiplier : tyreMultiplier // ignore: cast_nullable_to_non_nullable
as double?,damagePercent: freezed == damagePercent ? _self.damagePercent : damagePercent // ignore: cast_nullable_to_non_nullable
as double?,drivers: null == drivers ? _self._drivers : drivers // ignore: cast_nullable_to_non_nullable
as List<ResultsDriver>,events: null == events ? _self._events : events // ignore: cast_nullable_to_non_nullable
as List<ResultsEvent>,
  ));
}


}

/// @nodoc
mixin _$ResultsDriver {

/// 0-based order in the file. The slot numbers in the event log
/// (`Name(10)`, `ID="21"`) are the server's and are not this.
 int get index;/// The car's driver when the file was written. For a shared car, every
/// driver is in [swaps].
 String get name; bool get isPlayer; String get vehicleFile;/// `= metadata.CarName` of a recording in this car.
 String get vehicleName;/// The model, `Ferrari 499P`.
 String get carType;/// `= metadata.CarClass` (`Hyper`, `GT3`, `LMP2_ELMS`).
 String get carClass;/// `WEC 2026, Hypercar, Ferrari 499P`.
 String get category; String get teamName; String get carNumber; int? get gridPosition; int? get classGridPosition; int? get position; int? get classPosition; double? get bestLapSeconds; double? get finishElapsed; int get lapsCompleted; int get pitStops; String get finishStatus; String? get dnfReason; List<ResultsStint> get swaps; List<ResultsStint> get aids; List<ResultsLap> get laps;
/// Create a copy of ResultsDriver
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResultsDriverCopyWith<ResultsDriver> get copyWith => _$ResultsDriverCopyWithImpl<ResultsDriver>(this as ResultsDriver, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ResultsDriver;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResultsDriver&&(identical(other.index, _this.index) || other.index == _this.index)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.isPlayer, _this.isPlayer) || other.isPlayer == _this.isPlayer)&&(identical(other.vehicleFile, _this.vehicleFile) || other.vehicleFile == _this.vehicleFile)&&(identical(other.vehicleName, _this.vehicleName) || other.vehicleName == _this.vehicleName)&&(identical(other.carType, _this.carType) || other.carType == _this.carType)&&(identical(other.carClass, _this.carClass) || other.carClass == _this.carClass)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.teamName, _this.teamName) || other.teamName == _this.teamName)&&(identical(other.carNumber, _this.carNumber) || other.carNumber == _this.carNumber)&&(identical(other.gridPosition, _this.gridPosition) || other.gridPosition == _this.gridPosition)&&(identical(other.classGridPosition, _this.classGridPosition) || other.classGridPosition == _this.classGridPosition)&&(identical(other.position, _this.position) || other.position == _this.position)&&(identical(other.classPosition, _this.classPosition) || other.classPosition == _this.classPosition)&&(identical(other.bestLapSeconds, _this.bestLapSeconds) || other.bestLapSeconds == _this.bestLapSeconds)&&(identical(other.finishElapsed, _this.finishElapsed) || other.finishElapsed == _this.finishElapsed)&&(identical(other.lapsCompleted, _this.lapsCompleted) || other.lapsCompleted == _this.lapsCompleted)&&(identical(other.pitStops, _this.pitStops) || other.pitStops == _this.pitStops)&&(identical(other.finishStatus, _this.finishStatus) || other.finishStatus == _this.finishStatus)&&(identical(other.dnfReason, _this.dnfReason) || other.dnfReason == _this.dnfReason)&&const DeepCollectionEquality().equals(other.swaps, _this.swaps)&&const DeepCollectionEquality().equals(other.aids, _this.aids)&&const DeepCollectionEquality().equals(other.laps, _this.laps));
}


@override
int get hashCode {
  final _this = this as ResultsDriver;
  return Object.hashAll([runtimeType,_this.index,_this.name,_this.isPlayer,_this.vehicleFile,_this.vehicleName,_this.carType,_this.carClass,_this.category,_this.teamName,_this.carNumber,_this.gridPosition,_this.classGridPosition,_this.position,_this.classPosition,_this.bestLapSeconds,_this.finishElapsed,_this.lapsCompleted,_this.pitStops,_this.finishStatus,_this.dnfReason,const DeepCollectionEquality().hash(_this.swaps),const DeepCollectionEquality().hash(_this.aids),const DeepCollectionEquality().hash(_this.laps)]);
}

@override
String toString() {
  final _this = this as ResultsDriver;
  return 'ResultsDriver(index: ${_this.index}, name: ${_this.name}, isPlayer: ${_this.isPlayer}, vehicleFile: ${_this.vehicleFile}, vehicleName: ${_this.vehicleName}, carType: ${_this.carType}, carClass: ${_this.carClass}, category: ${_this.category}, teamName: ${_this.teamName}, carNumber: ${_this.carNumber}, gridPosition: ${_this.gridPosition}, classGridPosition: ${_this.classGridPosition}, position: ${_this.position}, classPosition: ${_this.classPosition}, bestLapSeconds: ${_this.bestLapSeconds}, finishElapsed: ${_this.finishElapsed}, lapsCompleted: ${_this.lapsCompleted}, pitStops: ${_this.pitStops}, finishStatus: ${_this.finishStatus}, dnfReason: ${_this.dnfReason}, swaps: ${_this.swaps}, aids: ${_this.aids}, laps: ${_this.laps})';
}


}

/// @nodoc
abstract mixin class $ResultsDriverCopyWith<$Res>  {
  factory $ResultsDriverCopyWith(ResultsDriver value, $Res Function(ResultsDriver) _then) = _$ResultsDriverCopyWithImpl;
@useResult
$Res call({
 int index, String name, bool isPlayer, String vehicleFile, String vehicleName, String carType, String carClass, String category, String teamName, String carNumber, int? gridPosition, int? classGridPosition, int? position, int? classPosition, double? bestLapSeconds, double? finishElapsed, int lapsCompleted, int pitStops, String finishStatus, String? dnfReason, List<ResultsStint> swaps, List<ResultsStint> aids, List<ResultsLap> laps
});




}
/// @nodoc
class _$ResultsDriverCopyWithImpl<$Res>
    implements $ResultsDriverCopyWith<$Res> {
  _$ResultsDriverCopyWithImpl(this._self, this._then);

  final ResultsDriver _self;
  final $Res Function(ResultsDriver) _then;

/// Create a copy of ResultsDriver
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? index = null,Object? name = null,Object? isPlayer = null,Object? vehicleFile = null,Object? vehicleName = null,Object? carType = null,Object? carClass = null,Object? category = null,Object? teamName = null,Object? carNumber = null,Object? gridPosition = freezed,Object? classGridPosition = freezed,Object? position = freezed,Object? classPosition = freezed,Object? bestLapSeconds = freezed,Object? finishElapsed = freezed,Object? lapsCompleted = null,Object? pitStops = null,Object? finishStatus = null,Object? dnfReason = freezed,Object? swaps = null,Object? aids = null,Object? laps = null,}) {
  return _then(ResultsDriver(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isPlayer: null == isPlayer ? _self.isPlayer : isPlayer // ignore: cast_nullable_to_non_nullable
as bool,vehicleFile: null == vehicleFile ? _self.vehicleFile : vehicleFile // ignore: cast_nullable_to_non_nullable
as String,vehicleName: null == vehicleName ? _self.vehicleName : vehicleName // ignore: cast_nullable_to_non_nullable
as String,carType: null == carType ? _self.carType : carType // ignore: cast_nullable_to_non_nullable
as String,carClass: null == carClass ? _self.carClass : carClass // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,teamName: null == teamName ? _self.teamName : teamName // ignore: cast_nullable_to_non_nullable
as String,carNumber: null == carNumber ? _self.carNumber : carNumber // ignore: cast_nullable_to_non_nullable
as String,gridPosition: freezed == gridPosition ? _self.gridPosition : gridPosition // ignore: cast_nullable_to_non_nullable
as int?,classGridPosition: freezed == classGridPosition ? _self.classGridPosition : classGridPosition // ignore: cast_nullable_to_non_nullable
as int?,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int?,classPosition: freezed == classPosition ? _self.classPosition : classPosition // ignore: cast_nullable_to_non_nullable
as int?,bestLapSeconds: freezed == bestLapSeconds ? _self.bestLapSeconds : bestLapSeconds // ignore: cast_nullable_to_non_nullable
as double?,finishElapsed: freezed == finishElapsed ? _self.finishElapsed : finishElapsed // ignore: cast_nullable_to_non_nullable
as double?,lapsCompleted: null == lapsCompleted ? _self.lapsCompleted : lapsCompleted // ignore: cast_nullable_to_non_nullable
as int,pitStops: null == pitStops ? _self.pitStops : pitStops // ignore: cast_nullable_to_non_nullable
as int,finishStatus: null == finishStatus ? _self.finishStatus : finishStatus // ignore: cast_nullable_to_non_nullable
as String,dnfReason: freezed == dnfReason ? _self.dnfReason : dnfReason // ignore: cast_nullable_to_non_nullable
as String?,swaps: null == swaps ? _self.swaps : swaps // ignore: cast_nullable_to_non_nullable
as List<ResultsStint>,aids: null == aids ? _self.aids : aids // ignore: cast_nullable_to_non_nullable
as List<ResultsStint>,laps: null == laps ? _self.laps : laps // ignore: cast_nullable_to_non_nullable
as List<ResultsLap>,
  ));
}

}


/// Adds pattern-matching-related methods to [ResultsDriver].
extension ResultsDriverPatterns on ResultsDriver {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ResultsDriver value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ResultsDriver() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ResultsDriver value)  $default,){
final _that = this;
switch (_that) {
case _ResultsDriver():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ResultsDriver value)?  $default,){
final _that = this;
switch (_that) {
case _ResultsDriver() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int index,  String name,  bool isPlayer,  String vehicleFile,  String vehicleName,  String carType,  String carClass,  String category,  String teamName,  String carNumber,  int? gridPosition,  int? classGridPosition,  int? position,  int? classPosition,  double? bestLapSeconds,  double? finishElapsed,  int lapsCompleted,  int pitStops,  String finishStatus,  String? dnfReason,  List<ResultsStint> swaps,  List<ResultsStint> aids,  List<ResultsLap> laps)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ResultsDriver() when $default != null:
return $default(_that.index,_that.name,_that.isPlayer,_that.vehicleFile,_that.vehicleName,_that.carType,_that.carClass,_that.category,_that.teamName,_that.carNumber,_that.gridPosition,_that.classGridPosition,_that.position,_that.classPosition,_that.bestLapSeconds,_that.finishElapsed,_that.lapsCompleted,_that.pitStops,_that.finishStatus,_that.dnfReason,_that.swaps,_that.aids,_that.laps);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int index,  String name,  bool isPlayer,  String vehicleFile,  String vehicleName,  String carType,  String carClass,  String category,  String teamName,  String carNumber,  int? gridPosition,  int? classGridPosition,  int? position,  int? classPosition,  double? bestLapSeconds,  double? finishElapsed,  int lapsCompleted,  int pitStops,  String finishStatus,  String? dnfReason,  List<ResultsStint> swaps,  List<ResultsStint> aids,  List<ResultsLap> laps)  $default,) {final _that = this;
switch (_that) {
case _ResultsDriver():
return $default(_that.index,_that.name,_that.isPlayer,_that.vehicleFile,_that.vehicleName,_that.carType,_that.carClass,_that.category,_that.teamName,_that.carNumber,_that.gridPosition,_that.classGridPosition,_that.position,_that.classPosition,_that.bestLapSeconds,_that.finishElapsed,_that.lapsCompleted,_that.pitStops,_that.finishStatus,_that.dnfReason,_that.swaps,_that.aids,_that.laps);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int index,  String name,  bool isPlayer,  String vehicleFile,  String vehicleName,  String carType,  String carClass,  String category,  String teamName,  String carNumber,  int? gridPosition,  int? classGridPosition,  int? position,  int? classPosition,  double? bestLapSeconds,  double? finishElapsed,  int lapsCompleted,  int pitStops,  String finishStatus,  String? dnfReason,  List<ResultsStint> swaps,  List<ResultsStint> aids,  List<ResultsLap> laps)?  $default,) {final _that = this;
switch (_that) {
case _ResultsDriver() when $default != null:
return $default(_that.index,_that.name,_that.isPlayer,_that.vehicleFile,_that.vehicleName,_that.carType,_that.carClass,_that.category,_that.teamName,_that.carNumber,_that.gridPosition,_that.classGridPosition,_that.position,_that.classPosition,_that.bestLapSeconds,_that.finishElapsed,_that.lapsCompleted,_that.pitStops,_that.finishStatus,_that.dnfReason,_that.swaps,_that.aids,_that.laps);case _:
  return null;

}
}

}

/// @nodoc


class _ResultsDriver extends ResultsDriver {
  const _ResultsDriver({required this.index, required this.name, required this.isPlayer, required this.vehicleFile, required this.vehicleName, required this.carType, required this.carClass, required this.category, required this.teamName, required this.carNumber, this.gridPosition, this.classGridPosition, this.position, this.classPosition, this.bestLapSeconds, this.finishElapsed, required this.lapsCompleted, required this.pitStops, required this.finishStatus, this.dnfReason,  List<ResultsStint> swaps = const <ResultsStint>[],  List<ResultsStint> aids = const <ResultsStint>[],  List<ResultsLap> laps = const <ResultsLap>[]}): _swaps = swaps,_aids = aids,_laps = laps,super._();
  

/// 0-based order in the file. The slot numbers in the event log
/// (`Name(10)`, `ID="21"`) are the server's and are not this.
@override final  int index;
/// The car's driver when the file was written. For a shared car, every
/// driver is in [swaps].
@override final  String name;
@override final  bool isPlayer;
@override final  String vehicleFile;
/// `= metadata.CarName` of a recording in this car.
@override final  String vehicleName;
/// The model, `Ferrari 499P`.
@override final  String carType;
/// `= metadata.CarClass` (`Hyper`, `GT3`, `LMP2_ELMS`).
@override final  String carClass;
/// `WEC 2026, Hypercar, Ferrari 499P`.
@override final  String category;
@override final  String teamName;
@override final  String carNumber;
@override final  int? gridPosition;
@override final  int? classGridPosition;
@override final  int? position;
@override final  int? classPosition;
@override final  double? bestLapSeconds;
@override final  double? finishElapsed;
@override final  int lapsCompleted;
@override final  int pitStops;
@override final  String finishStatus;
@override final  String? dnfReason;
 final  List<ResultsStint> _swaps;
@override@JsonKey() List<ResultsStint> get swaps {
  if (_swaps is EqualUnmodifiableListView) return _swaps;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_swaps);
}

 final  List<ResultsStint> _aids;
@override@JsonKey() List<ResultsStint> get aids {
  if (_aids is EqualUnmodifiableListView) return _aids;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_aids);
}

 final  List<ResultsLap> _laps;
@override@JsonKey() List<ResultsLap> get laps {
  if (_laps is EqualUnmodifiableListView) return _laps;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_laps);
}


/// Create a copy of ResultsDriver
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ResultsDriverCopyWith<_ResultsDriver> get copyWith => __$ResultsDriverCopyWithImpl<_ResultsDriver>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ResultsDriver&&(identical(other.index, index) || other.index == index)&&(identical(other.name, name) || other.name == name)&&(identical(other.isPlayer, isPlayer) || other.isPlayer == isPlayer)&&(identical(other.vehicleFile, vehicleFile) || other.vehicleFile == vehicleFile)&&(identical(other.vehicleName, vehicleName) || other.vehicleName == vehicleName)&&(identical(other.carType, carType) || other.carType == carType)&&(identical(other.carClass, carClass) || other.carClass == carClass)&&(identical(other.category, category) || other.category == category)&&(identical(other.teamName, teamName) || other.teamName == teamName)&&(identical(other.carNumber, carNumber) || other.carNumber == carNumber)&&(identical(other.gridPosition, gridPosition) || other.gridPosition == gridPosition)&&(identical(other.classGridPosition, classGridPosition) || other.classGridPosition == classGridPosition)&&(identical(other.position, position) || other.position == position)&&(identical(other.classPosition, classPosition) || other.classPosition == classPosition)&&(identical(other.bestLapSeconds, bestLapSeconds) || other.bestLapSeconds == bestLapSeconds)&&(identical(other.finishElapsed, finishElapsed) || other.finishElapsed == finishElapsed)&&(identical(other.lapsCompleted, lapsCompleted) || other.lapsCompleted == lapsCompleted)&&(identical(other.pitStops, pitStops) || other.pitStops == pitStops)&&(identical(other.finishStatus, finishStatus) || other.finishStatus == finishStatus)&&(identical(other.dnfReason, dnfReason) || other.dnfReason == dnfReason)&&const DeepCollectionEquality().equals(other.swaps, _swaps)&&const DeepCollectionEquality().equals(other.aids, _aids)&&const DeepCollectionEquality().equals(other.laps, _laps));
}


@override
int get hashCode {
    return Object.hashAll([runtimeType,index,name,isPlayer,vehicleFile,vehicleName,carType,carClass,category,teamName,carNumber,gridPosition,classGridPosition,position,classPosition,bestLapSeconds,finishElapsed,lapsCompleted,pitStops,finishStatus,dnfReason,const DeepCollectionEquality().hash(_swaps),const DeepCollectionEquality().hash(_aids),const DeepCollectionEquality().hash(_laps)]);
}

@override
String toString() {
    return 'ResultsDriver(index: $index, name: $name, isPlayer: $isPlayer, vehicleFile: $vehicleFile, vehicleName: $vehicleName, carType: $carType, carClass: $carClass, category: $category, teamName: $teamName, carNumber: $carNumber, gridPosition: $gridPosition, classGridPosition: $classGridPosition, position: $position, classPosition: $classPosition, bestLapSeconds: $bestLapSeconds, finishElapsed: $finishElapsed, lapsCompleted: $lapsCompleted, pitStops: $pitStops, finishStatus: $finishStatus, dnfReason: $dnfReason, swaps: $swaps, aids: $aids, laps: $laps)';
}


}

/// @nodoc
abstract mixin class _$ResultsDriverCopyWith<$Res> implements $ResultsDriverCopyWith<$Res> {
  factory _$ResultsDriverCopyWith(_ResultsDriver value, $Res Function(_ResultsDriver) _then) = __$ResultsDriverCopyWithImpl;
@override @useResult
$Res call({
 int index, String name, bool isPlayer, String vehicleFile, String vehicleName, String carType, String carClass, String category, String teamName, String carNumber, int? gridPosition, int? classGridPosition, int? position, int? classPosition, double? bestLapSeconds, double? finishElapsed, int lapsCompleted, int pitStops, String finishStatus, String? dnfReason, List<ResultsStint> swaps, List<ResultsStint> aids, List<ResultsLap> laps
});




}
/// @nodoc
class __$ResultsDriverCopyWithImpl<$Res>
    implements _$ResultsDriverCopyWith<$Res> {
  __$ResultsDriverCopyWithImpl(this._self, this._then);

  final _ResultsDriver _self;
  final $Res Function(_ResultsDriver) _then;

/// Create a copy of ResultsDriver
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? index = null,Object? name = null,Object? isPlayer = null,Object? vehicleFile = null,Object? vehicleName = null,Object? carType = null,Object? carClass = null,Object? category = null,Object? teamName = null,Object? carNumber = null,Object? gridPosition = freezed,Object? classGridPosition = freezed,Object? position = freezed,Object? classPosition = freezed,Object? bestLapSeconds = freezed,Object? finishElapsed = freezed,Object? lapsCompleted = null,Object? pitStops = null,Object? finishStatus = null,Object? dnfReason = freezed,Object? swaps = null,Object? aids = null,Object? laps = null,}) {
  return _then(_ResultsDriver(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isPlayer: null == isPlayer ? _self.isPlayer : isPlayer // ignore: cast_nullable_to_non_nullable
as bool,vehicleFile: null == vehicleFile ? _self.vehicleFile : vehicleFile // ignore: cast_nullable_to_non_nullable
as String,vehicleName: null == vehicleName ? _self.vehicleName : vehicleName // ignore: cast_nullable_to_non_nullable
as String,carType: null == carType ? _self.carType : carType // ignore: cast_nullable_to_non_nullable
as String,carClass: null == carClass ? _self.carClass : carClass // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,teamName: null == teamName ? _self.teamName : teamName // ignore: cast_nullable_to_non_nullable
as String,carNumber: null == carNumber ? _self.carNumber : carNumber // ignore: cast_nullable_to_non_nullable
as String,gridPosition: freezed == gridPosition ? _self.gridPosition : gridPosition // ignore: cast_nullable_to_non_nullable
as int?,classGridPosition: freezed == classGridPosition ? _self.classGridPosition : classGridPosition // ignore: cast_nullable_to_non_nullable
as int?,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int?,classPosition: freezed == classPosition ? _self.classPosition : classPosition // ignore: cast_nullable_to_non_nullable
as int?,bestLapSeconds: freezed == bestLapSeconds ? _self.bestLapSeconds : bestLapSeconds // ignore: cast_nullable_to_non_nullable
as double?,finishElapsed: freezed == finishElapsed ? _self.finishElapsed : finishElapsed // ignore: cast_nullable_to_non_nullable
as double?,lapsCompleted: null == lapsCompleted ? _self.lapsCompleted : lapsCompleted // ignore: cast_nullable_to_non_nullable
as int,pitStops: null == pitStops ? _self.pitStops : pitStops // ignore: cast_nullable_to_non_nullable
as int,finishStatus: null == finishStatus ? _self.finishStatus : finishStatus // ignore: cast_nullable_to_non_nullable
as String,dnfReason: freezed == dnfReason ? _self.dnfReason : dnfReason // ignore: cast_nullable_to_non_nullable
as String?,swaps: null == swaps ? _self._swaps : swaps // ignore: cast_nullable_to_non_nullable
as List<ResultsStint>,aids: null == aids ? _self._aids : aids // ignore: cast_nullable_to_non_nullable
as List<ResultsStint>,laps: null == laps ? _self._laps : laps // ignore: cast_nullable_to_non_nullable
as List<ResultsLap>,
  ));
}


}

/// @nodoc
mixin _$ResultsStint {

 int get startLap; int get endLap; String get value;
/// Create a copy of ResultsStint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResultsStintCopyWith<ResultsStint> get copyWith => _$ResultsStintCopyWithImpl<ResultsStint>(this as ResultsStint, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ResultsStint;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResultsStint&&(identical(other.startLap, _this.startLap) || other.startLap == _this.startLap)&&(identical(other.endLap, _this.endLap) || other.endLap == _this.endLap)&&(identical(other.value, _this.value) || other.value == _this.value));
}


@override
int get hashCode {
  final _this = this as ResultsStint;
  return Object.hash(runtimeType,_this.startLap,_this.endLap,_this.value);
}

@override
String toString() {
  final _this = this as ResultsStint;
  return 'ResultsStint(startLap: ${_this.startLap}, endLap: ${_this.endLap}, value: ${_this.value})';
}


}

/// @nodoc
abstract mixin class $ResultsStintCopyWith<$Res>  {
  factory $ResultsStintCopyWith(ResultsStint value, $Res Function(ResultsStint) _then) = _$ResultsStintCopyWithImpl;
@useResult
$Res call({
 int startLap, int endLap, String value
});




}
/// @nodoc
class _$ResultsStintCopyWithImpl<$Res>
    implements $ResultsStintCopyWith<$Res> {
  _$ResultsStintCopyWithImpl(this._self, this._then);

  final ResultsStint _self;
  final $Res Function(ResultsStint) _then;

/// Create a copy of ResultsStint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? startLap = null,Object? endLap = null,Object? value = null,}) {
  return _then(ResultsStint(
startLap: null == startLap ? _self.startLap : startLap // ignore: cast_nullable_to_non_nullable
as int,endLap: null == endLap ? _self.endLap : endLap // ignore: cast_nullable_to_non_nullable
as int,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ResultsStint].
extension ResultsStintPatterns on ResultsStint {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ResultsStint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ResultsStint() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ResultsStint value)  $default,){
final _that = this;
switch (_that) {
case _ResultsStint():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ResultsStint value)?  $default,){
final _that = this;
switch (_that) {
case _ResultsStint() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int startLap,  int endLap,  String value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ResultsStint() when $default != null:
return $default(_that.startLap,_that.endLap,_that.value);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int startLap,  int endLap,  String value)  $default,) {final _that = this;
switch (_that) {
case _ResultsStint():
return $default(_that.startLap,_that.endLap,_that.value);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int startLap,  int endLap,  String value)?  $default,) {final _that = this;
switch (_that) {
case _ResultsStint() when $default != null:
return $default(_that.startLap,_that.endLap,_that.value);case _:
  return null;

}
}

}

/// @nodoc


class _ResultsStint implements ResultsStint {
  const _ResultsStint({required this.startLap, required this.endLap, required this.value});
  

@override final  int startLap;
@override final  int endLap;
@override final  String value;

/// Create a copy of ResultsStint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ResultsStintCopyWith<_ResultsStint> get copyWith => __$ResultsStintCopyWithImpl<_ResultsStint>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ResultsStint&&(identical(other.startLap, startLap) || other.startLap == startLap)&&(identical(other.endLap, endLap) || other.endLap == endLap)&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode {
    return Object.hash(runtimeType,startLap,endLap,value);
}

@override
String toString() {
    return 'ResultsStint(startLap: $startLap, endLap: $endLap, value: $value)';
}


}

/// @nodoc
abstract mixin class _$ResultsStintCopyWith<$Res> implements $ResultsStintCopyWith<$Res> {
  factory _$ResultsStintCopyWith(_ResultsStint value, $Res Function(_ResultsStint) _then) = __$ResultsStintCopyWithImpl;
@override @useResult
$Res call({
 int startLap, int endLap, String value
});




}
/// @nodoc
class __$ResultsStintCopyWithImpl<$Res>
    implements _$ResultsStintCopyWith<$Res> {
  __$ResultsStintCopyWithImpl(this._self, this._then);

  final _ResultsStint _self;
  final $Res Function(_ResultsStint) _then;

/// Create a copy of ResultsStint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? startLap = null,Object? endLap = null,Object? value = null,}) {
  return _then(_ResultsStint(
startLap: null == startLap ? _self.startLap : startLap // ignore: cast_nullable_to_non_nullable
as int,endLap: null == endLap ? _self.endLap : endLap // ignore: cast_nullable_to_non_nullable
as int,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$ResultsLap {

/// 1-based, as the file writes it. A recording's 0-based `Lap` value is
/// `number - 1`.
 int get number;/// Overall position at the lap's end.
 int? get position;/// `et`: session time at the lap's **start**, on the recording's clock
/// (Bahrain lap 3 starts at 311.2858; the recording's lap 2 ends at
/// 311.30). Null on a first lap, where the file writes `--.---`.
 double? get startElapsed;/// Null where the file writes `--.----`: the laps the recording also
/// leaves untimed.
 double? get lapSeconds;/// Per sector, **not** cumulative (unlike the recording's sector events,
/// SPEC §8.3.1). An invalidated lap keeps its time and loses its sectors.
 double? get sector1Seconds; double? get sector2Seconds; double? get sector3Seconds;/// km/h. `0.00` on laps nobody measured (spectated ones) reads as null.
 double? get topSpeedKmh;/// Fractions of the tank, after the lap.
 double? get fuelFraction; double? get fuelUsedFraction;/// Fractions of the energy allowance. Only some sessions carry them
/// (4,400 of 21,519 laps in one 24-hour race; none in the Le Mans race),
/// so null means "not in the file", never zero.
 double? get energyFraction; double? get energyUsedFraction;/// Tread left per corner, 1.0 when new. Not yet checked against the
/// recording's wear channel (proposal §4).
 double? get wearFrontLeft; double? get wearFrontRight; double? get wearRearLeft; double? get wearRearRight;/// `1,Medium` per axle, verbatim.
 String? get compoundFront; String? get compoundRear;/// `pit="1"`: the lap includes a stop.
 bool get pit;
/// Create a copy of ResultsLap
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResultsLapCopyWith<ResultsLap> get copyWith => _$ResultsLapCopyWithImpl<ResultsLap>(this as ResultsLap, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ResultsLap;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResultsLap&&(identical(other.number, _this.number) || other.number == _this.number)&&(identical(other.position, _this.position) || other.position == _this.position)&&(identical(other.startElapsed, _this.startElapsed) || other.startElapsed == _this.startElapsed)&&(identical(other.lapSeconds, _this.lapSeconds) || other.lapSeconds == _this.lapSeconds)&&(identical(other.sector1Seconds, _this.sector1Seconds) || other.sector1Seconds == _this.sector1Seconds)&&(identical(other.sector2Seconds, _this.sector2Seconds) || other.sector2Seconds == _this.sector2Seconds)&&(identical(other.sector3Seconds, _this.sector3Seconds) || other.sector3Seconds == _this.sector3Seconds)&&(identical(other.topSpeedKmh, _this.topSpeedKmh) || other.topSpeedKmh == _this.topSpeedKmh)&&(identical(other.fuelFraction, _this.fuelFraction) || other.fuelFraction == _this.fuelFraction)&&(identical(other.fuelUsedFraction, _this.fuelUsedFraction) || other.fuelUsedFraction == _this.fuelUsedFraction)&&(identical(other.energyFraction, _this.energyFraction) || other.energyFraction == _this.energyFraction)&&(identical(other.energyUsedFraction, _this.energyUsedFraction) || other.energyUsedFraction == _this.energyUsedFraction)&&(identical(other.wearFrontLeft, _this.wearFrontLeft) || other.wearFrontLeft == _this.wearFrontLeft)&&(identical(other.wearFrontRight, _this.wearFrontRight) || other.wearFrontRight == _this.wearFrontRight)&&(identical(other.wearRearLeft, _this.wearRearLeft) || other.wearRearLeft == _this.wearRearLeft)&&(identical(other.wearRearRight, _this.wearRearRight) || other.wearRearRight == _this.wearRearRight)&&(identical(other.compoundFront, _this.compoundFront) || other.compoundFront == _this.compoundFront)&&(identical(other.compoundRear, _this.compoundRear) || other.compoundRear == _this.compoundRear)&&(identical(other.pit, _this.pit) || other.pit == _this.pit));
}


@override
int get hashCode {
  final _this = this as ResultsLap;
  return Object.hashAll([runtimeType,_this.number,_this.position,_this.startElapsed,_this.lapSeconds,_this.sector1Seconds,_this.sector2Seconds,_this.sector3Seconds,_this.topSpeedKmh,_this.fuelFraction,_this.fuelUsedFraction,_this.energyFraction,_this.energyUsedFraction,_this.wearFrontLeft,_this.wearFrontRight,_this.wearRearLeft,_this.wearRearRight,_this.compoundFront,_this.compoundRear,_this.pit]);
}

@override
String toString() {
  final _this = this as ResultsLap;
  return 'ResultsLap(number: ${_this.number}, position: ${_this.position}, startElapsed: ${_this.startElapsed}, lapSeconds: ${_this.lapSeconds}, sector1Seconds: ${_this.sector1Seconds}, sector2Seconds: ${_this.sector2Seconds}, sector3Seconds: ${_this.sector3Seconds}, topSpeedKmh: ${_this.topSpeedKmh}, fuelFraction: ${_this.fuelFraction}, fuelUsedFraction: ${_this.fuelUsedFraction}, energyFraction: ${_this.energyFraction}, energyUsedFraction: ${_this.energyUsedFraction}, wearFrontLeft: ${_this.wearFrontLeft}, wearFrontRight: ${_this.wearFrontRight}, wearRearLeft: ${_this.wearRearLeft}, wearRearRight: ${_this.wearRearRight}, compoundFront: ${_this.compoundFront}, compoundRear: ${_this.compoundRear}, pit: ${_this.pit})';
}


}

/// @nodoc
abstract mixin class $ResultsLapCopyWith<$Res>  {
  factory $ResultsLapCopyWith(ResultsLap value, $Res Function(ResultsLap) _then) = _$ResultsLapCopyWithImpl;
@useResult
$Res call({
 int number, int? position, double? startElapsed, double? lapSeconds, double? sector1Seconds, double? sector2Seconds, double? sector3Seconds, double? topSpeedKmh, double? fuelFraction, double? fuelUsedFraction, double? energyFraction, double? energyUsedFraction, double? wearFrontLeft, double? wearFrontRight, double? wearRearLeft, double? wearRearRight, String? compoundFront, String? compoundRear, bool pit
});




}
/// @nodoc
class _$ResultsLapCopyWithImpl<$Res>
    implements $ResultsLapCopyWith<$Res> {
  _$ResultsLapCopyWithImpl(this._self, this._then);

  final ResultsLap _self;
  final $Res Function(ResultsLap) _then;

/// Create a copy of ResultsLap
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? number = null,Object? position = freezed,Object? startElapsed = freezed,Object? lapSeconds = freezed,Object? sector1Seconds = freezed,Object? sector2Seconds = freezed,Object? sector3Seconds = freezed,Object? topSpeedKmh = freezed,Object? fuelFraction = freezed,Object? fuelUsedFraction = freezed,Object? energyFraction = freezed,Object? energyUsedFraction = freezed,Object? wearFrontLeft = freezed,Object? wearFrontRight = freezed,Object? wearRearLeft = freezed,Object? wearRearRight = freezed,Object? compoundFront = freezed,Object? compoundRear = freezed,Object? pit = null,}) {
  return _then(ResultsLap(
number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int?,startElapsed: freezed == startElapsed ? _self.startElapsed : startElapsed // ignore: cast_nullable_to_non_nullable
as double?,lapSeconds: freezed == lapSeconds ? _self.lapSeconds : lapSeconds // ignore: cast_nullable_to_non_nullable
as double?,sector1Seconds: freezed == sector1Seconds ? _self.sector1Seconds : sector1Seconds // ignore: cast_nullable_to_non_nullable
as double?,sector2Seconds: freezed == sector2Seconds ? _self.sector2Seconds : sector2Seconds // ignore: cast_nullable_to_non_nullable
as double?,sector3Seconds: freezed == sector3Seconds ? _self.sector3Seconds : sector3Seconds // ignore: cast_nullable_to_non_nullable
as double?,topSpeedKmh: freezed == topSpeedKmh ? _self.topSpeedKmh : topSpeedKmh // ignore: cast_nullable_to_non_nullable
as double?,fuelFraction: freezed == fuelFraction ? _self.fuelFraction : fuelFraction // ignore: cast_nullable_to_non_nullable
as double?,fuelUsedFraction: freezed == fuelUsedFraction ? _self.fuelUsedFraction : fuelUsedFraction // ignore: cast_nullable_to_non_nullable
as double?,energyFraction: freezed == energyFraction ? _self.energyFraction : energyFraction // ignore: cast_nullable_to_non_nullable
as double?,energyUsedFraction: freezed == energyUsedFraction ? _self.energyUsedFraction : energyUsedFraction // ignore: cast_nullable_to_non_nullable
as double?,wearFrontLeft: freezed == wearFrontLeft ? _self.wearFrontLeft : wearFrontLeft // ignore: cast_nullable_to_non_nullable
as double?,wearFrontRight: freezed == wearFrontRight ? _self.wearFrontRight : wearFrontRight // ignore: cast_nullable_to_non_nullable
as double?,wearRearLeft: freezed == wearRearLeft ? _self.wearRearLeft : wearRearLeft // ignore: cast_nullable_to_non_nullable
as double?,wearRearRight: freezed == wearRearRight ? _self.wearRearRight : wearRearRight // ignore: cast_nullable_to_non_nullable
as double?,compoundFront: freezed == compoundFront ? _self.compoundFront : compoundFront // ignore: cast_nullable_to_non_nullable
as String?,compoundRear: freezed == compoundRear ? _self.compoundRear : compoundRear // ignore: cast_nullable_to_non_nullable
as String?,pit: null == pit ? _self.pit : pit // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ResultsLap].
extension ResultsLapPatterns on ResultsLap {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ResultsLap value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ResultsLap() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ResultsLap value)  $default,){
final _that = this;
switch (_that) {
case _ResultsLap():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ResultsLap value)?  $default,){
final _that = this;
switch (_that) {
case _ResultsLap() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int number,  int? position,  double? startElapsed,  double? lapSeconds,  double? sector1Seconds,  double? sector2Seconds,  double? sector3Seconds,  double? topSpeedKmh,  double? fuelFraction,  double? fuelUsedFraction,  double? energyFraction,  double? energyUsedFraction,  double? wearFrontLeft,  double? wearFrontRight,  double? wearRearLeft,  double? wearRearRight,  String? compoundFront,  String? compoundRear,  bool pit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ResultsLap() when $default != null:
return $default(_that.number,_that.position,_that.startElapsed,_that.lapSeconds,_that.sector1Seconds,_that.sector2Seconds,_that.sector3Seconds,_that.topSpeedKmh,_that.fuelFraction,_that.fuelUsedFraction,_that.energyFraction,_that.energyUsedFraction,_that.wearFrontLeft,_that.wearFrontRight,_that.wearRearLeft,_that.wearRearRight,_that.compoundFront,_that.compoundRear,_that.pit);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int number,  int? position,  double? startElapsed,  double? lapSeconds,  double? sector1Seconds,  double? sector2Seconds,  double? sector3Seconds,  double? topSpeedKmh,  double? fuelFraction,  double? fuelUsedFraction,  double? energyFraction,  double? energyUsedFraction,  double? wearFrontLeft,  double? wearFrontRight,  double? wearRearLeft,  double? wearRearRight,  String? compoundFront,  String? compoundRear,  bool pit)  $default,) {final _that = this;
switch (_that) {
case _ResultsLap():
return $default(_that.number,_that.position,_that.startElapsed,_that.lapSeconds,_that.sector1Seconds,_that.sector2Seconds,_that.sector3Seconds,_that.topSpeedKmh,_that.fuelFraction,_that.fuelUsedFraction,_that.energyFraction,_that.energyUsedFraction,_that.wearFrontLeft,_that.wearFrontRight,_that.wearRearLeft,_that.wearRearRight,_that.compoundFront,_that.compoundRear,_that.pit);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int number,  int? position,  double? startElapsed,  double? lapSeconds,  double? sector1Seconds,  double? sector2Seconds,  double? sector3Seconds,  double? topSpeedKmh,  double? fuelFraction,  double? fuelUsedFraction,  double? energyFraction,  double? energyUsedFraction,  double? wearFrontLeft,  double? wearFrontRight,  double? wearRearLeft,  double? wearRearRight,  String? compoundFront,  String? compoundRear,  bool pit)?  $default,) {final _that = this;
switch (_that) {
case _ResultsLap() when $default != null:
return $default(_that.number,_that.position,_that.startElapsed,_that.lapSeconds,_that.sector1Seconds,_that.sector2Seconds,_that.sector3Seconds,_that.topSpeedKmh,_that.fuelFraction,_that.fuelUsedFraction,_that.energyFraction,_that.energyUsedFraction,_that.wearFrontLeft,_that.wearFrontRight,_that.wearRearLeft,_that.wearRearRight,_that.compoundFront,_that.compoundRear,_that.pit);case _:
  return null;

}
}

}

/// @nodoc


class _ResultsLap extends ResultsLap {
  const _ResultsLap({required this.number, this.position, this.startElapsed, this.lapSeconds, this.sector1Seconds, this.sector2Seconds, this.sector3Seconds, this.topSpeedKmh, this.fuelFraction, this.fuelUsedFraction, this.energyFraction, this.energyUsedFraction, this.wearFrontLeft, this.wearFrontRight, this.wearRearLeft, this.wearRearRight, this.compoundFront, this.compoundRear, this.pit = false}): super._();
  

/// 1-based, as the file writes it. A recording's 0-based `Lap` value is
/// `number - 1`.
@override final  int number;
/// Overall position at the lap's end.
@override final  int? position;
/// `et`: session time at the lap's **start**, on the recording's clock
/// (Bahrain lap 3 starts at 311.2858; the recording's lap 2 ends at
/// 311.30). Null on a first lap, where the file writes `--.---`.
@override final  double? startElapsed;
/// Null where the file writes `--.----`: the laps the recording also
/// leaves untimed.
@override final  double? lapSeconds;
/// Per sector, **not** cumulative (unlike the recording's sector events,
/// SPEC §8.3.1). An invalidated lap keeps its time and loses its sectors.
@override final  double? sector1Seconds;
@override final  double? sector2Seconds;
@override final  double? sector3Seconds;
/// km/h. `0.00` on laps nobody measured (spectated ones) reads as null.
@override final  double? topSpeedKmh;
/// Fractions of the tank, after the lap.
@override final  double? fuelFraction;
@override final  double? fuelUsedFraction;
/// Fractions of the energy allowance. Only some sessions carry them
/// (4,400 of 21,519 laps in one 24-hour race; none in the Le Mans race),
/// so null means "not in the file", never zero.
@override final  double? energyFraction;
@override final  double? energyUsedFraction;
/// Tread left per corner, 1.0 when new. Not yet checked against the
/// recording's wear channel (proposal §4).
@override final  double? wearFrontLeft;
@override final  double? wearFrontRight;
@override final  double? wearRearLeft;
@override final  double? wearRearRight;
/// `1,Medium` per axle, verbatim.
@override final  String? compoundFront;
@override final  String? compoundRear;
/// `pit="1"`: the lap includes a stop.
@override@JsonKey() final  bool pit;

/// Create a copy of ResultsLap
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ResultsLapCopyWith<_ResultsLap> get copyWith => __$ResultsLapCopyWithImpl<_ResultsLap>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ResultsLap&&(identical(other.number, number) || other.number == number)&&(identical(other.position, position) || other.position == position)&&(identical(other.startElapsed, startElapsed) || other.startElapsed == startElapsed)&&(identical(other.lapSeconds, lapSeconds) || other.lapSeconds == lapSeconds)&&(identical(other.sector1Seconds, sector1Seconds) || other.sector1Seconds == sector1Seconds)&&(identical(other.sector2Seconds, sector2Seconds) || other.sector2Seconds == sector2Seconds)&&(identical(other.sector3Seconds, sector3Seconds) || other.sector3Seconds == sector3Seconds)&&(identical(other.topSpeedKmh, topSpeedKmh) || other.topSpeedKmh == topSpeedKmh)&&(identical(other.fuelFraction, fuelFraction) || other.fuelFraction == fuelFraction)&&(identical(other.fuelUsedFraction, fuelUsedFraction) || other.fuelUsedFraction == fuelUsedFraction)&&(identical(other.energyFraction, energyFraction) || other.energyFraction == energyFraction)&&(identical(other.energyUsedFraction, energyUsedFraction) || other.energyUsedFraction == energyUsedFraction)&&(identical(other.wearFrontLeft, wearFrontLeft) || other.wearFrontLeft == wearFrontLeft)&&(identical(other.wearFrontRight, wearFrontRight) || other.wearFrontRight == wearFrontRight)&&(identical(other.wearRearLeft, wearRearLeft) || other.wearRearLeft == wearRearLeft)&&(identical(other.wearRearRight, wearRearRight) || other.wearRearRight == wearRearRight)&&(identical(other.compoundFront, compoundFront) || other.compoundFront == compoundFront)&&(identical(other.compoundRear, compoundRear) || other.compoundRear == compoundRear)&&(identical(other.pit, pit) || other.pit == pit));
}


@override
int get hashCode {
    return Object.hashAll([runtimeType,number,position,startElapsed,lapSeconds,sector1Seconds,sector2Seconds,sector3Seconds,topSpeedKmh,fuelFraction,fuelUsedFraction,energyFraction,energyUsedFraction,wearFrontLeft,wearFrontRight,wearRearLeft,wearRearRight,compoundFront,compoundRear,pit]);
}

@override
String toString() {
    return 'ResultsLap(number: $number, position: $position, startElapsed: $startElapsed, lapSeconds: $lapSeconds, sector1Seconds: $sector1Seconds, sector2Seconds: $sector2Seconds, sector3Seconds: $sector3Seconds, topSpeedKmh: $topSpeedKmh, fuelFraction: $fuelFraction, fuelUsedFraction: $fuelUsedFraction, energyFraction: $energyFraction, energyUsedFraction: $energyUsedFraction, wearFrontLeft: $wearFrontLeft, wearFrontRight: $wearFrontRight, wearRearLeft: $wearRearLeft, wearRearRight: $wearRearRight, compoundFront: $compoundFront, compoundRear: $compoundRear, pit: $pit)';
}


}

/// @nodoc
abstract mixin class _$ResultsLapCopyWith<$Res> implements $ResultsLapCopyWith<$Res> {
  factory _$ResultsLapCopyWith(_ResultsLap value, $Res Function(_ResultsLap) _then) = __$ResultsLapCopyWithImpl;
@override @useResult
$Res call({
 int number, int? position, double? startElapsed, double? lapSeconds, double? sector1Seconds, double? sector2Seconds, double? sector3Seconds, double? topSpeedKmh, double? fuelFraction, double? fuelUsedFraction, double? energyFraction, double? energyUsedFraction, double? wearFrontLeft, double? wearFrontRight, double? wearRearLeft, double? wearRearRight, String? compoundFront, String? compoundRear, bool pit
});




}
/// @nodoc
class __$ResultsLapCopyWithImpl<$Res>
    implements _$ResultsLapCopyWith<$Res> {
  __$ResultsLapCopyWithImpl(this._self, this._then);

  final _ResultsLap _self;
  final $Res Function(_ResultsLap) _then;

/// Create a copy of ResultsLap
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? number = null,Object? position = freezed,Object? startElapsed = freezed,Object? lapSeconds = freezed,Object? sector1Seconds = freezed,Object? sector2Seconds = freezed,Object? sector3Seconds = freezed,Object? topSpeedKmh = freezed,Object? fuelFraction = freezed,Object? fuelUsedFraction = freezed,Object? energyFraction = freezed,Object? energyUsedFraction = freezed,Object? wearFrontLeft = freezed,Object? wearFrontRight = freezed,Object? wearRearLeft = freezed,Object? wearRearRight = freezed,Object? compoundFront = freezed,Object? compoundRear = freezed,Object? pit = null,}) {
  return _then(_ResultsLap(
number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int?,startElapsed: freezed == startElapsed ? _self.startElapsed : startElapsed // ignore: cast_nullable_to_non_nullable
as double?,lapSeconds: freezed == lapSeconds ? _self.lapSeconds : lapSeconds // ignore: cast_nullable_to_non_nullable
as double?,sector1Seconds: freezed == sector1Seconds ? _self.sector1Seconds : sector1Seconds // ignore: cast_nullable_to_non_nullable
as double?,sector2Seconds: freezed == sector2Seconds ? _self.sector2Seconds : sector2Seconds // ignore: cast_nullable_to_non_nullable
as double?,sector3Seconds: freezed == sector3Seconds ? _self.sector3Seconds : sector3Seconds // ignore: cast_nullable_to_non_nullable
as double?,topSpeedKmh: freezed == topSpeedKmh ? _self.topSpeedKmh : topSpeedKmh // ignore: cast_nullable_to_non_nullable
as double?,fuelFraction: freezed == fuelFraction ? _self.fuelFraction : fuelFraction // ignore: cast_nullable_to_non_nullable
as double?,fuelUsedFraction: freezed == fuelUsedFraction ? _self.fuelUsedFraction : fuelUsedFraction // ignore: cast_nullable_to_non_nullable
as double?,energyFraction: freezed == energyFraction ? _self.energyFraction : energyFraction // ignore: cast_nullable_to_non_nullable
as double?,energyUsedFraction: freezed == energyUsedFraction ? _self.energyUsedFraction : energyUsedFraction // ignore: cast_nullable_to_non_nullable
as double?,wearFrontLeft: freezed == wearFrontLeft ? _self.wearFrontLeft : wearFrontLeft // ignore: cast_nullable_to_non_nullable
as double?,wearFrontRight: freezed == wearFrontRight ? _self.wearFrontRight : wearFrontRight // ignore: cast_nullable_to_non_nullable
as double?,wearRearLeft: freezed == wearRearLeft ? _self.wearRearLeft : wearRearLeft // ignore: cast_nullable_to_non_nullable
as double?,wearRearRight: freezed == wearRearRight ? _self.wearRearRight : wearRearRight // ignore: cast_nullable_to_non_nullable
as double?,compoundFront: freezed == compoundFront ? _self.compoundFront : compoundFront // ignore: cast_nullable_to_non_nullable
as String?,compoundRear: freezed == compoundRear ? _self.compoundRear : compoundRear // ignore: cast_nullable_to_non_nullable
as String?,pit: null == pit ? _self.pit : pit // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$ResultsEvent {

 ResultsEventKind get kind;/// `et`, on the same clock as the laps.
 double get elapsed;/// The line's text, verbatim (`No Further Action`, `… reported contact
/// (1081.22) with Immovable`).
 String get text;/// From the attributes where the line has them (`TrackLimits`, a given
/// `Penalty`), else parsed from the text's leading `Name(slot)`.
 String? get driverName; int? get slot;/// `TrackLimits Lap`: **0-based**, the recording's own lap index.
 int? get lap;/// `TrackLimits Resolution` code; [text] holds its words.
 int? get resolution; double? get warningPoints; double? get currentPoints;/// A given penalty's kind and reason (`Drive Thru`, `Track Limits`).
 String? get penalty; String? get reason;
/// Create a copy of ResultsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResultsEventCopyWith<ResultsEvent> get copyWith => _$ResultsEventCopyWithImpl<ResultsEvent>(this as ResultsEvent, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ResultsEvent;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResultsEvent&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.elapsed, _this.elapsed) || other.elapsed == _this.elapsed)&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.driverName, _this.driverName) || other.driverName == _this.driverName)&&(identical(other.slot, _this.slot) || other.slot == _this.slot)&&(identical(other.lap, _this.lap) || other.lap == _this.lap)&&(identical(other.resolution, _this.resolution) || other.resolution == _this.resolution)&&(identical(other.warningPoints, _this.warningPoints) || other.warningPoints == _this.warningPoints)&&(identical(other.currentPoints, _this.currentPoints) || other.currentPoints == _this.currentPoints)&&(identical(other.penalty, _this.penalty) || other.penalty == _this.penalty)&&(identical(other.reason, _this.reason) || other.reason == _this.reason));
}


@override
int get hashCode {
  final _this = this as ResultsEvent;
  return Object.hash(runtimeType,_this.kind,_this.elapsed,_this.text,_this.driverName,_this.slot,_this.lap,_this.resolution,_this.warningPoints,_this.currentPoints,_this.penalty,_this.reason);
}

@override
String toString() {
  final _this = this as ResultsEvent;
  return 'ResultsEvent(kind: ${_this.kind}, elapsed: ${_this.elapsed}, text: ${_this.text}, driverName: ${_this.driverName}, slot: ${_this.slot}, lap: ${_this.lap}, resolution: ${_this.resolution}, warningPoints: ${_this.warningPoints}, currentPoints: ${_this.currentPoints}, penalty: ${_this.penalty}, reason: ${_this.reason})';
}


}

/// @nodoc
abstract mixin class $ResultsEventCopyWith<$Res>  {
  factory $ResultsEventCopyWith(ResultsEvent value, $Res Function(ResultsEvent) _then) = _$ResultsEventCopyWithImpl;
@useResult
$Res call({
 ResultsEventKind kind, double elapsed, String text, String? driverName, int? slot, int? lap, int? resolution, double? warningPoints, double? currentPoints, String? penalty, String? reason
});




}
/// @nodoc
class _$ResultsEventCopyWithImpl<$Res>
    implements $ResultsEventCopyWith<$Res> {
  _$ResultsEventCopyWithImpl(this._self, this._then);

  final ResultsEvent _self;
  final $Res Function(ResultsEvent) _then;

/// Create a copy of ResultsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? elapsed = null,Object? text = null,Object? driverName = freezed,Object? slot = freezed,Object? lap = freezed,Object? resolution = freezed,Object? warningPoints = freezed,Object? currentPoints = freezed,Object? penalty = freezed,Object? reason = freezed,}) {
  return _then(ResultsEvent(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ResultsEventKind,elapsed: null == elapsed ? _self.elapsed : elapsed // ignore: cast_nullable_to_non_nullable
as double,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,driverName: freezed == driverName ? _self.driverName : driverName // ignore: cast_nullable_to_non_nullable
as String?,slot: freezed == slot ? _self.slot : slot // ignore: cast_nullable_to_non_nullable
as int?,lap: freezed == lap ? _self.lap : lap // ignore: cast_nullable_to_non_nullable
as int?,resolution: freezed == resolution ? _self.resolution : resolution // ignore: cast_nullable_to_non_nullable
as int?,warningPoints: freezed == warningPoints ? _self.warningPoints : warningPoints // ignore: cast_nullable_to_non_nullable
as double?,currentPoints: freezed == currentPoints ? _self.currentPoints : currentPoints // ignore: cast_nullable_to_non_nullable
as double?,penalty: freezed == penalty ? _self.penalty : penalty // ignore: cast_nullable_to_non_nullable
as String?,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ResultsEvent].
extension ResultsEventPatterns on ResultsEvent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ResultsEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ResultsEvent() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ResultsEvent value)  $default,){
final _that = this;
switch (_that) {
case _ResultsEvent():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ResultsEvent value)?  $default,){
final _that = this;
switch (_that) {
case _ResultsEvent() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ResultsEventKind kind,  double elapsed,  String text,  String? driverName,  int? slot,  int? lap,  int? resolution,  double? warningPoints,  double? currentPoints,  String? penalty,  String? reason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ResultsEvent() when $default != null:
return $default(_that.kind,_that.elapsed,_that.text,_that.driverName,_that.slot,_that.lap,_that.resolution,_that.warningPoints,_that.currentPoints,_that.penalty,_that.reason);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ResultsEventKind kind,  double elapsed,  String text,  String? driverName,  int? slot,  int? lap,  int? resolution,  double? warningPoints,  double? currentPoints,  String? penalty,  String? reason)  $default,) {final _that = this;
switch (_that) {
case _ResultsEvent():
return $default(_that.kind,_that.elapsed,_that.text,_that.driverName,_that.slot,_that.lap,_that.resolution,_that.warningPoints,_that.currentPoints,_that.penalty,_that.reason);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ResultsEventKind kind,  double elapsed,  String text,  String? driverName,  int? slot,  int? lap,  int? resolution,  double? warningPoints,  double? currentPoints,  String? penalty,  String? reason)?  $default,) {final _that = this;
switch (_that) {
case _ResultsEvent() when $default != null:
return $default(_that.kind,_that.elapsed,_that.text,_that.driverName,_that.slot,_that.lap,_that.resolution,_that.warningPoints,_that.currentPoints,_that.penalty,_that.reason);case _:
  return null;

}
}

}

/// @nodoc


class _ResultsEvent implements ResultsEvent {
  const _ResultsEvent({required this.kind, required this.elapsed, required this.text, this.driverName, this.slot, this.lap, this.resolution, this.warningPoints, this.currentPoints, this.penalty, this.reason});
  

@override final  ResultsEventKind kind;
/// `et`, on the same clock as the laps.
@override final  double elapsed;
/// The line's text, verbatim (`No Further Action`, `… reported contact
/// (1081.22) with Immovable`).
@override final  String text;
/// From the attributes where the line has them (`TrackLimits`, a given
/// `Penalty`), else parsed from the text's leading `Name(slot)`.
@override final  String? driverName;
@override final  int? slot;
/// `TrackLimits Lap`: **0-based**, the recording's own lap index.
@override final  int? lap;
/// `TrackLimits Resolution` code; [text] holds its words.
@override final  int? resolution;
@override final  double? warningPoints;
@override final  double? currentPoints;
/// A given penalty's kind and reason (`Drive Thru`, `Track Limits`).
@override final  String? penalty;
@override final  String? reason;

/// Create a copy of ResultsEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ResultsEventCopyWith<_ResultsEvent> get copyWith => __$ResultsEventCopyWithImpl<_ResultsEvent>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ResultsEvent&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.elapsed, elapsed) || other.elapsed == elapsed)&&(identical(other.text, text) || other.text == text)&&(identical(other.driverName, driverName) || other.driverName == driverName)&&(identical(other.slot, slot) || other.slot == slot)&&(identical(other.lap, lap) || other.lap == lap)&&(identical(other.resolution, resolution) || other.resolution == resolution)&&(identical(other.warningPoints, warningPoints) || other.warningPoints == warningPoints)&&(identical(other.currentPoints, currentPoints) || other.currentPoints == currentPoints)&&(identical(other.penalty, penalty) || other.penalty == penalty)&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kind,elapsed,text,driverName,slot,lap,resolution,warningPoints,currentPoints,penalty,reason);
}

@override
String toString() {
    return 'ResultsEvent(kind: $kind, elapsed: $elapsed, text: $text, driverName: $driverName, slot: $slot, lap: $lap, resolution: $resolution, warningPoints: $warningPoints, currentPoints: $currentPoints, penalty: $penalty, reason: $reason)';
}


}

/// @nodoc
abstract mixin class _$ResultsEventCopyWith<$Res> implements $ResultsEventCopyWith<$Res> {
  factory _$ResultsEventCopyWith(_ResultsEvent value, $Res Function(_ResultsEvent) _then) = __$ResultsEventCopyWithImpl;
@override @useResult
$Res call({
 ResultsEventKind kind, double elapsed, String text, String? driverName, int? slot, int? lap, int? resolution, double? warningPoints, double? currentPoints, String? penalty, String? reason
});




}
/// @nodoc
class __$ResultsEventCopyWithImpl<$Res>
    implements _$ResultsEventCopyWith<$Res> {
  __$ResultsEventCopyWithImpl(this._self, this._then);

  final _ResultsEvent _self;
  final $Res Function(_ResultsEvent) _then;

/// Create a copy of ResultsEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? elapsed = null,Object? text = null,Object? driverName = freezed,Object? slot = freezed,Object? lap = freezed,Object? resolution = freezed,Object? warningPoints = freezed,Object? currentPoints = freezed,Object? penalty = freezed,Object? reason = freezed,}) {
  return _then(_ResultsEvent(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ResultsEventKind,elapsed: null == elapsed ? _self.elapsed : elapsed // ignore: cast_nullable_to_non_nullable
as double,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,driverName: freezed == driverName ? _self.driverName : driverName // ignore: cast_nullable_to_non_nullable
as String?,slot: freezed == slot ? _self.slot : slot // ignore: cast_nullable_to_non_nullable
as int?,lap: freezed == lap ? _self.lap : lap // ignore: cast_nullable_to_non_nullable
as int?,resolution: freezed == resolution ? _self.resolution : resolution // ignore: cast_nullable_to_non_nullable
as int?,warningPoints: freezed == warningPoints ? _self.warningPoints : warningPoints // ignore: cast_nullable_to_non_nullable
as double?,currentPoints: freezed == currentPoints ? _self.currentPoints : currentPoints // ignore: cast_nullable_to_non_nullable
as double?,penalty: freezed == penalty ? _self.penalty : penalty // ignore: cast_nullable_to_non_nullable
as String?,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
