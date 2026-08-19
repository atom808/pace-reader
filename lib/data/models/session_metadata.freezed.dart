// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_metadata.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionMetadata {

 String get driverName; String get steamId; String get recordingTime;/// Session **start time-of-day** (e.g. `"13:00:21"`), not a duration —
/// the name invites exactly the wrong reading (§5.1).
 String get sessionTimeOfDay; SessionType get sessionType; String get trackName;/// Load-bearing, not a display detail (§8.1): the Sebring Race sample is
/// the 3.08 km "Sebring School Circuit", roughly half the full course.
/// Index and compare on `(trackName, trackLayout)` or bests silently
/// span different circuits.
 String get trackLayout; String get weatherConditions; String get carName; String get carClass;/// The full embedded car setup as raw JSON (§5.1) — parsed on demand by
/// the Setup Viewer (§8.10), not eagerly here: it's a large blob with
/// 172 top-level keys and nothing else needs it.
 String get carSetupJson;/// The file's own format-version stamp. Gated at open time (§5.1).
 String get version;
/// Create a copy of SessionMetadata
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionMetadataCopyWith<SessionMetadata> get copyWith => _$SessionMetadataCopyWithImpl<SessionMetadata>(this as SessionMetadata, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionMetadata&&(identical(other.driverName, driverName) || other.driverName == driverName)&&(identical(other.steamId, steamId) || other.steamId == steamId)&&(identical(other.recordingTime, recordingTime) || other.recordingTime == recordingTime)&&(identical(other.sessionTimeOfDay, sessionTimeOfDay) || other.sessionTimeOfDay == sessionTimeOfDay)&&(identical(other.sessionType, sessionType) || other.sessionType == sessionType)&&(identical(other.trackName, trackName) || other.trackName == trackName)&&(identical(other.trackLayout, trackLayout) || other.trackLayout == trackLayout)&&(identical(other.weatherConditions, weatherConditions) || other.weatherConditions == weatherConditions)&&(identical(other.carName, carName) || other.carName == carName)&&(identical(other.carClass, carClass) || other.carClass == carClass)&&(identical(other.carSetupJson, carSetupJson) || other.carSetupJson == carSetupJson)&&(identical(other.version, version) || other.version == version));
}


@override
int get hashCode => Object.hash(runtimeType,driverName,steamId,recordingTime,sessionTimeOfDay,sessionType,trackName,trackLayout,weatherConditions,carName,carClass,carSetupJson,version);

@override
String toString() {
  return 'SessionMetadata(driverName: $driverName, steamId: $steamId, recordingTime: $recordingTime, sessionTimeOfDay: $sessionTimeOfDay, sessionType: $sessionType, trackName: $trackName, trackLayout: $trackLayout, weatherConditions: $weatherConditions, carName: $carName, carClass: $carClass, carSetupJson: $carSetupJson, version: $version)';
}


}

/// @nodoc
abstract mixin class $SessionMetadataCopyWith<$Res>  {
  factory $SessionMetadataCopyWith(SessionMetadata value, $Res Function(SessionMetadata) _then) = _$SessionMetadataCopyWithImpl;
@useResult
$Res call({
 String driverName, String steamId, String recordingTime, String sessionTimeOfDay, SessionType sessionType, String trackName, String trackLayout, String weatherConditions, String carName, String carClass, String carSetupJson, String version
});




}
/// @nodoc
class _$SessionMetadataCopyWithImpl<$Res>
    implements $SessionMetadataCopyWith<$Res> {
  _$SessionMetadataCopyWithImpl(this._self, this._then);

  final SessionMetadata _self;
  final $Res Function(SessionMetadata) _then;

/// Create a copy of SessionMetadata
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? driverName = null,Object? steamId = null,Object? recordingTime = null,Object? sessionTimeOfDay = null,Object? sessionType = null,Object? trackName = null,Object? trackLayout = null,Object? weatherConditions = null,Object? carName = null,Object? carClass = null,Object? carSetupJson = null,Object? version = null,}) {
  return _then(_self.copyWith(
driverName: null == driverName ? _self.driverName : driverName // ignore: cast_nullable_to_non_nullable
as String,steamId: null == steamId ? _self.steamId : steamId // ignore: cast_nullable_to_non_nullable
as String,recordingTime: null == recordingTime ? _self.recordingTime : recordingTime // ignore: cast_nullable_to_non_nullable
as String,sessionTimeOfDay: null == sessionTimeOfDay ? _self.sessionTimeOfDay : sessionTimeOfDay // ignore: cast_nullable_to_non_nullable
as String,sessionType: null == sessionType ? _self.sessionType : sessionType // ignore: cast_nullable_to_non_nullable
as SessionType,trackName: null == trackName ? _self.trackName : trackName // ignore: cast_nullable_to_non_nullable
as String,trackLayout: null == trackLayout ? _self.trackLayout : trackLayout // ignore: cast_nullable_to_non_nullable
as String,weatherConditions: null == weatherConditions ? _self.weatherConditions : weatherConditions // ignore: cast_nullable_to_non_nullable
as String,carName: null == carName ? _self.carName : carName // ignore: cast_nullable_to_non_nullable
as String,carClass: null == carClass ? _self.carClass : carClass // ignore: cast_nullable_to_non_nullable
as String,carSetupJson: null == carSetupJson ? _self.carSetupJson : carSetupJson // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionMetadata].
extension SessionMetadataPatterns on SessionMetadata {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionMetadata value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionMetadata() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionMetadata value)  $default,){
final _that = this;
switch (_that) {
case _SessionMetadata():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionMetadata value)?  $default,){
final _that = this;
switch (_that) {
case _SessionMetadata() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String driverName,  String steamId,  String recordingTime,  String sessionTimeOfDay,  SessionType sessionType,  String trackName,  String trackLayout,  String weatherConditions,  String carName,  String carClass,  String carSetupJson,  String version)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionMetadata() when $default != null:
return $default(_that.driverName,_that.steamId,_that.recordingTime,_that.sessionTimeOfDay,_that.sessionType,_that.trackName,_that.trackLayout,_that.weatherConditions,_that.carName,_that.carClass,_that.carSetupJson,_that.version);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String driverName,  String steamId,  String recordingTime,  String sessionTimeOfDay,  SessionType sessionType,  String trackName,  String trackLayout,  String weatherConditions,  String carName,  String carClass,  String carSetupJson,  String version)  $default,) {final _that = this;
switch (_that) {
case _SessionMetadata():
return $default(_that.driverName,_that.steamId,_that.recordingTime,_that.sessionTimeOfDay,_that.sessionType,_that.trackName,_that.trackLayout,_that.weatherConditions,_that.carName,_that.carClass,_that.carSetupJson,_that.version);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String driverName,  String steamId,  String recordingTime,  String sessionTimeOfDay,  SessionType sessionType,  String trackName,  String trackLayout,  String weatherConditions,  String carName,  String carClass,  String carSetupJson,  String version)?  $default,) {final _that = this;
switch (_that) {
case _SessionMetadata() when $default != null:
return $default(_that.driverName,_that.steamId,_that.recordingTime,_that.sessionTimeOfDay,_that.sessionType,_that.trackName,_that.trackLayout,_that.weatherConditions,_that.carName,_that.carClass,_that.carSetupJson,_that.version);case _:
  return null;

}
}

}

/// @nodoc


class _SessionMetadata extends SessionMetadata {
  const _SessionMetadata({required this.driverName, required this.steamId, required this.recordingTime, required this.sessionTimeOfDay, required this.sessionType, required this.trackName, required this.trackLayout, required this.weatherConditions, required this.carName, required this.carClass, required this.carSetupJson, required this.version}): super._();
  

@override final  String driverName;
@override final  String steamId;
@override final  String recordingTime;
/// Session **start time-of-day** (e.g. `"13:00:21"`), not a duration —
/// the name invites exactly the wrong reading (§5.1).
@override final  String sessionTimeOfDay;
@override final  SessionType sessionType;
@override final  String trackName;
/// Load-bearing, not a display detail (§8.1): the Sebring Race sample is
/// the 3.08 km "Sebring School Circuit", roughly half the full course.
/// Index and compare on `(trackName, trackLayout)` or bests silently
/// span different circuits.
@override final  String trackLayout;
@override final  String weatherConditions;
@override final  String carName;
@override final  String carClass;
/// The full embedded car setup as raw JSON (§5.1) — parsed on demand by
/// the Setup Viewer (§8.10), not eagerly here: it's a large blob with
/// 172 top-level keys and nothing else needs it.
@override final  String carSetupJson;
/// The file's own format-version stamp. Gated at open time (§5.1).
@override final  String version;

/// Create a copy of SessionMetadata
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionMetadataCopyWith<_SessionMetadata> get copyWith => __$SessionMetadataCopyWithImpl<_SessionMetadata>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionMetadata&&(identical(other.driverName, driverName) || other.driverName == driverName)&&(identical(other.steamId, steamId) || other.steamId == steamId)&&(identical(other.recordingTime, recordingTime) || other.recordingTime == recordingTime)&&(identical(other.sessionTimeOfDay, sessionTimeOfDay) || other.sessionTimeOfDay == sessionTimeOfDay)&&(identical(other.sessionType, sessionType) || other.sessionType == sessionType)&&(identical(other.trackName, trackName) || other.trackName == trackName)&&(identical(other.trackLayout, trackLayout) || other.trackLayout == trackLayout)&&(identical(other.weatherConditions, weatherConditions) || other.weatherConditions == weatherConditions)&&(identical(other.carName, carName) || other.carName == carName)&&(identical(other.carClass, carClass) || other.carClass == carClass)&&(identical(other.carSetupJson, carSetupJson) || other.carSetupJson == carSetupJson)&&(identical(other.version, version) || other.version == version));
}


@override
int get hashCode => Object.hash(runtimeType,driverName,steamId,recordingTime,sessionTimeOfDay,sessionType,trackName,trackLayout,weatherConditions,carName,carClass,carSetupJson,version);

@override
String toString() {
  return 'SessionMetadata(driverName: $driverName, steamId: $steamId, recordingTime: $recordingTime, sessionTimeOfDay: $sessionTimeOfDay, sessionType: $sessionType, trackName: $trackName, trackLayout: $trackLayout, weatherConditions: $weatherConditions, carName: $carName, carClass: $carClass, carSetupJson: $carSetupJson, version: $version)';
}


}

/// @nodoc
abstract mixin class _$SessionMetadataCopyWith<$Res> implements $SessionMetadataCopyWith<$Res> {
  factory _$SessionMetadataCopyWith(_SessionMetadata value, $Res Function(_SessionMetadata) _then) = __$SessionMetadataCopyWithImpl;
@override @useResult
$Res call({
 String driverName, String steamId, String recordingTime, String sessionTimeOfDay, SessionType sessionType, String trackName, String trackLayout, String weatherConditions, String carName, String carClass, String carSetupJson, String version
});




}
/// @nodoc
class __$SessionMetadataCopyWithImpl<$Res>
    implements _$SessionMetadataCopyWith<$Res> {
  __$SessionMetadataCopyWithImpl(this._self, this._then);

  final _SessionMetadata _self;
  final $Res Function(_SessionMetadata) _then;

/// Create a copy of SessionMetadata
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? driverName = null,Object? steamId = null,Object? recordingTime = null,Object? sessionTimeOfDay = null,Object? sessionType = null,Object? trackName = null,Object? trackLayout = null,Object? weatherConditions = null,Object? carName = null,Object? carClass = null,Object? carSetupJson = null,Object? version = null,}) {
  return _then(_SessionMetadata(
driverName: null == driverName ? _self.driverName : driverName // ignore: cast_nullable_to_non_nullable
as String,steamId: null == steamId ? _self.steamId : steamId // ignore: cast_nullable_to_non_nullable
as String,recordingTime: null == recordingTime ? _self.recordingTime : recordingTime // ignore: cast_nullable_to_non_nullable
as String,sessionTimeOfDay: null == sessionTimeOfDay ? _self.sessionTimeOfDay : sessionTimeOfDay // ignore: cast_nullable_to_non_nullable
as String,sessionType: null == sessionType ? _self.sessionType : sessionType // ignore: cast_nullable_to_non_nullable
as SessionType,trackName: null == trackName ? _self.trackName : trackName // ignore: cast_nullable_to_non_nullable
as String,trackLayout: null == trackLayout ? _self.trackLayout : trackLayout // ignore: cast_nullable_to_non_nullable
as String,weatherConditions: null == weatherConditions ? _self.weatherConditions : weatherConditions // ignore: cast_nullable_to_non_nullable
as String,carName: null == carName ? _self.carName : carName // ignore: cast_nullable_to_non_nullable
as String,carClass: null == carClass ? _self.carClass : carClass // ignore: cast_nullable_to_non_nullable
as String,carSetupJson: null == carSetupJson ? _self.carSetupJson : carSetupJson // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
