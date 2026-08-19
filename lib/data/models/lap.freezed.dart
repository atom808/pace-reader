// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'lap.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SectorTimes {

/// `Last Sector1` — already a duration.
 double? get sector1Seconds;/// S2's *duration*: `Last Sector2 - Last Sector1`.
 double? get sector2Seconds;/// S3's *duration*: `Lap Time - Last Sector2`. No Sector3 value exists
/// in the catalog, so this is the only route to it.
 double? get sector3Seconds;
/// Create a copy of SectorTimes
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SectorTimesCopyWith<SectorTimes> get copyWith => _$SectorTimesCopyWithImpl<SectorTimes>(this as SectorTimes, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SectorTimes&&(identical(other.sector1Seconds, sector1Seconds) || other.sector1Seconds == sector1Seconds)&&(identical(other.sector2Seconds, sector2Seconds) || other.sector2Seconds == sector2Seconds)&&(identical(other.sector3Seconds, sector3Seconds) || other.sector3Seconds == sector3Seconds));
}


@override
int get hashCode => Object.hash(runtimeType,sector1Seconds,sector2Seconds,sector3Seconds);

@override
String toString() {
  return 'SectorTimes(sector1Seconds: $sector1Seconds, sector2Seconds: $sector2Seconds, sector3Seconds: $sector3Seconds)';
}


}

/// @nodoc
abstract mixin class $SectorTimesCopyWith<$Res>  {
  factory $SectorTimesCopyWith(SectorTimes value, $Res Function(SectorTimes) _then) = _$SectorTimesCopyWithImpl;
@useResult
$Res call({
 double? sector1Seconds, double? sector2Seconds, double? sector3Seconds
});




}
/// @nodoc
class _$SectorTimesCopyWithImpl<$Res>
    implements $SectorTimesCopyWith<$Res> {
  _$SectorTimesCopyWithImpl(this._self, this._then);

  final SectorTimes _self;
  final $Res Function(SectorTimes) _then;

/// Create a copy of SectorTimes
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sector1Seconds = freezed,Object? sector2Seconds = freezed,Object? sector3Seconds = freezed,}) {
  return _then(SectorTimes(
sector1Seconds: freezed == sector1Seconds ? _self.sector1Seconds : sector1Seconds // ignore: cast_nullable_to_non_nullable
as double?,sector2Seconds: freezed == sector2Seconds ? _self.sector2Seconds : sector2Seconds // ignore: cast_nullable_to_non_nullable
as double?,sector3Seconds: freezed == sector3Seconds ? _self.sector3Seconds : sector3Seconds // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [SectorTimes].
extension SectorTimesPatterns on SectorTimes {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SectorTimes value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SectorTimes() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SectorTimes value)  $default,){
final _that = this;
switch (_that) {
case _SectorTimes():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SectorTimes value)?  $default,){
final _that = this;
switch (_that) {
case _SectorTimes() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double? sector1Seconds,  double? sector2Seconds,  double? sector3Seconds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SectorTimes() when $default != null:
return $default(_that.sector1Seconds,_that.sector2Seconds,_that.sector3Seconds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double? sector1Seconds,  double? sector2Seconds,  double? sector3Seconds)  $default,) {final _that = this;
switch (_that) {
case _SectorTimes():
return $default(_that.sector1Seconds,_that.sector2Seconds,_that.sector3Seconds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double? sector1Seconds,  double? sector2Seconds,  double? sector3Seconds)?  $default,) {final _that = this;
switch (_that) {
case _SectorTimes() when $default != null:
return $default(_that.sector1Seconds,_that.sector2Seconds,_that.sector3Seconds);case _:
  return null;

}
}

}

/// @nodoc


class _SectorTimes extends SectorTimes {
  const _SectorTimes({this.sector1Seconds, this.sector2Seconds, this.sector3Seconds}): super._();
  

/// `Last Sector1` — already a duration.
@override final  double? sector1Seconds;
/// S2's *duration*: `Last Sector2 - Last Sector1`.
@override final  double? sector2Seconds;
/// S3's *duration*: `Lap Time - Last Sector2`. No Sector3 value exists
/// in the catalog, so this is the only route to it.
@override final  double? sector3Seconds;

/// Create a copy of SectorTimes
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SectorTimesCopyWith<_SectorTimes> get copyWith => __$SectorTimesCopyWithImpl<_SectorTimes>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SectorTimes&&(identical(other.sector1Seconds, sector1Seconds) || other.sector1Seconds == sector1Seconds)&&(identical(other.sector2Seconds, sector2Seconds) || other.sector2Seconds == sector2Seconds)&&(identical(other.sector3Seconds, sector3Seconds) || other.sector3Seconds == sector3Seconds));
}


@override
int get hashCode => Object.hash(runtimeType,sector1Seconds,sector2Seconds,sector3Seconds);

@override
String toString() {
  return 'SectorTimes(sector1Seconds: $sector1Seconds, sector2Seconds: $sector2Seconds, sector3Seconds: $sector3Seconds)';
}


}

/// @nodoc
abstract mixin class _$SectorTimesCopyWith<$Res> implements $SectorTimesCopyWith<$Res> {
  factory _$SectorTimesCopyWith(_SectorTimes value, $Res Function(_SectorTimes) _then) = __$SectorTimesCopyWithImpl;
@override @useResult
$Res call({
 double? sector1Seconds, double? sector2Seconds, double? sector3Seconds
});




}
/// @nodoc
class __$SectorTimesCopyWithImpl<$Res>
    implements _$SectorTimesCopyWith<$Res> {
  __$SectorTimesCopyWithImpl(this._self, this._then);

  final _SectorTimes _self;
  final $Res Function(_SectorTimes) _then;

/// Create a copy of SectorTimes
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sector1Seconds = freezed,Object? sector2Seconds = freezed,Object? sector3Seconds = freezed,}) {
  return _then(_SectorTimes(
sector1Seconds: freezed == sector1Seconds ? _self.sector1Seconds : sector1Seconds // ignore: cast_nullable_to_non_nullable
as double?,sector2Seconds: freezed == sector2Seconds ? _self.sector2Seconds : sector2Seconds // ignore: cast_nullable_to_non_nullable
as double?,sector3Seconds: freezed == sector3Seconds ? _self.sector3Seconds : sector3Seconds // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

/// @nodoc
mixin _$Lap {

/// The raw 0-based value from the `Lap` event table.
 int get index;/// `ts` of this lap's `Lap` event, in elapsed seconds.
 double get startSeconds;/// `ts` of the next `Lap` event. Null on the final row, which opens a lap
/// the file has no closing boundary for (§5.2).
 double? get endSeconds;/// The game's own `Lap Time`, read at this lap's *end* boundary.
///
/// Null when the file recorded no time (an untimed out-lap) or wrote 0.0
/// (an invalidated lap — 2 of 19 Race laps, 1 of 4 Qualify laps). Never
/// derived from `endSeconds - startSeconds`: on the Race sample lap 0
/// those disagree by 101 s, because the wall-clock span includes garage
/// and grid time while the game times only from the start.
 double? get lapTimeSeconds; SectorTimes get sectors;
/// Create a copy of Lap
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LapCopyWith<Lap> get copyWith => _$LapCopyWithImpl<Lap>(this as Lap, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Lap&&(identical(other.index, index) || other.index == index)&&(identical(other.startSeconds, startSeconds) || other.startSeconds == startSeconds)&&(identical(other.endSeconds, endSeconds) || other.endSeconds == endSeconds)&&(identical(other.lapTimeSeconds, lapTimeSeconds) || other.lapTimeSeconds == lapTimeSeconds)&&(identical(other.sectors, sectors) || other.sectors == sectors));
}


@override
int get hashCode => Object.hash(runtimeType,index,startSeconds,endSeconds,lapTimeSeconds,sectors);

@override
String toString() {
  return 'Lap(index: $index, startSeconds: $startSeconds, endSeconds: $endSeconds, lapTimeSeconds: $lapTimeSeconds, sectors: $sectors)';
}


}

/// @nodoc
abstract mixin class $LapCopyWith<$Res>  {
  factory $LapCopyWith(Lap value, $Res Function(Lap) _then) = _$LapCopyWithImpl;
@useResult
$Res call({
 int index, double startSeconds, double? endSeconds, double? lapTimeSeconds, SectorTimes sectors
});


$SectorTimesCopyWith<$Res> get sectors;

}
/// @nodoc
class _$LapCopyWithImpl<$Res>
    implements $LapCopyWith<$Res> {
  _$LapCopyWithImpl(this._self, this._then);

  final Lap _self;
  final $Res Function(Lap) _then;

/// Create a copy of Lap
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? index = null,Object? startSeconds = null,Object? endSeconds = freezed,Object? lapTimeSeconds = freezed,Object? sectors = null,}) {
  return _then(Lap(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,startSeconds: null == startSeconds ? _self.startSeconds : startSeconds // ignore: cast_nullable_to_non_nullable
as double,endSeconds: freezed == endSeconds ? _self.endSeconds : endSeconds // ignore: cast_nullable_to_non_nullable
as double?,lapTimeSeconds: freezed == lapTimeSeconds ? _self.lapTimeSeconds : lapTimeSeconds // ignore: cast_nullable_to_non_nullable
as double?,sectors: null == sectors ? _self.sectors : sectors // ignore: cast_nullable_to_non_nullable
as SectorTimes,
  ));
}
/// Create a copy of Lap
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SectorTimesCopyWith<$Res> get sectors {
  
  return $SectorTimesCopyWith<$Res>(_self.sectors, (value) {
    return _then(_self.copyWith(sectors: value));
  });
}
}


/// Adds pattern-matching-related methods to [Lap].
extension LapPatterns on Lap {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Lap value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Lap() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Lap value)  $default,){
final _that = this;
switch (_that) {
case _Lap():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Lap value)?  $default,){
final _that = this;
switch (_that) {
case _Lap() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int index,  double startSeconds,  double? endSeconds,  double? lapTimeSeconds,  SectorTimes sectors)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Lap() when $default != null:
return $default(_that.index,_that.startSeconds,_that.endSeconds,_that.lapTimeSeconds,_that.sectors);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int index,  double startSeconds,  double? endSeconds,  double? lapTimeSeconds,  SectorTimes sectors)  $default,) {final _that = this;
switch (_that) {
case _Lap():
return $default(_that.index,_that.startSeconds,_that.endSeconds,_that.lapTimeSeconds,_that.sectors);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int index,  double startSeconds,  double? endSeconds,  double? lapTimeSeconds,  SectorTimes sectors)?  $default,) {final _that = this;
switch (_that) {
case _Lap() when $default != null:
return $default(_that.index,_that.startSeconds,_that.endSeconds,_that.lapTimeSeconds,_that.sectors);case _:
  return null;

}
}

}

/// @nodoc


class _Lap extends Lap {
  const _Lap({required this.index, required this.startSeconds, this.endSeconds, this.lapTimeSeconds, required this.sectors}): super._();
  

/// The raw 0-based value from the `Lap` event table.
@override final  int index;
/// `ts` of this lap's `Lap` event, in elapsed seconds.
@override final  double startSeconds;
/// `ts` of the next `Lap` event. Null on the final row, which opens a lap
/// the file has no closing boundary for (§5.2).
@override final  double? endSeconds;
/// The game's own `Lap Time`, read at this lap's *end* boundary.
///
/// Null when the file recorded no time (an untimed out-lap) or wrote 0.0
/// (an invalidated lap — 2 of 19 Race laps, 1 of 4 Qualify laps). Never
/// derived from `endSeconds - startSeconds`: on the Race sample lap 0
/// those disagree by 101 s, because the wall-clock span includes garage
/// and grid time while the game times only from the start.
@override final  double? lapTimeSeconds;
@override final  SectorTimes sectors;

/// Create a copy of Lap
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LapCopyWith<_Lap> get copyWith => __$LapCopyWithImpl<_Lap>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Lap&&(identical(other.index, index) || other.index == index)&&(identical(other.startSeconds, startSeconds) || other.startSeconds == startSeconds)&&(identical(other.endSeconds, endSeconds) || other.endSeconds == endSeconds)&&(identical(other.lapTimeSeconds, lapTimeSeconds) || other.lapTimeSeconds == lapTimeSeconds)&&(identical(other.sectors, sectors) || other.sectors == sectors));
}


@override
int get hashCode => Object.hash(runtimeType,index,startSeconds,endSeconds,lapTimeSeconds,sectors);

@override
String toString() {
  return 'Lap(index: $index, startSeconds: $startSeconds, endSeconds: $endSeconds, lapTimeSeconds: $lapTimeSeconds, sectors: $sectors)';
}


}

/// @nodoc
abstract mixin class _$LapCopyWith<$Res> implements $LapCopyWith<$Res> {
  factory _$LapCopyWith(_Lap value, $Res Function(_Lap) _then) = __$LapCopyWithImpl;
@override @useResult
$Res call({
 int index, double startSeconds, double? endSeconds, double? lapTimeSeconds, SectorTimes sectors
});


@override $SectorTimesCopyWith<$Res> get sectors;

}
/// @nodoc
class __$LapCopyWithImpl<$Res>
    implements _$LapCopyWith<$Res> {
  __$LapCopyWithImpl(this._self, this._then);

  final _Lap _self;
  final $Res Function(_Lap) _then;

/// Create a copy of Lap
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? index = null,Object? startSeconds = null,Object? endSeconds = freezed,Object? lapTimeSeconds = freezed,Object? sectors = null,}) {
  return _then(_Lap(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,startSeconds: null == startSeconds ? _self.startSeconds : startSeconds // ignore: cast_nullable_to_non_nullable
as double,endSeconds: freezed == endSeconds ? _self.endSeconds : endSeconds // ignore: cast_nullable_to_non_nullable
as double?,lapTimeSeconds: freezed == lapTimeSeconds ? _self.lapTimeSeconds : lapTimeSeconds // ignore: cast_nullable_to_non_nullable
as double?,sectors: null == sectors ? _self.sectors : sectors // ignore: cast_nullable_to_non_nullable
as SectorTimes,
  ));
}

/// Create a copy of Lap
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SectorTimesCopyWith<$Res> get sectors {
  
  return $SectorTimesCopyWith<$Res>(_self.sectors, (value) {
    return _then(_self.copyWith(sectors: value));
  });
}
}

// dart format on
