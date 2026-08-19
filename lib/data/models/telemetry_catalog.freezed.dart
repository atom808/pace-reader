// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'telemetry_catalog.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChannelDescriptor {

 String get name;/// The **declared** rate from the catalog. Nominal, not exact: two
/// channels declare 7 Hz and sample at ~7.0171 Hz (§5.2), so this is
/// safe for display/labelling and unsafe for timing. Use
/// [ridesMasterGrid] to decide which.
 int get frequencyHz; String get unit;/// 1 for a single-value channel, 4 for a per-corner one (`value1`..
/// `value4`). Read from the table, not guessed from the name.
 int get valueColumnCount;/// Row count in this file — needed to derive timestamps, and to detect a
/// channel whose declared frequency doesn't reproduce it.
 int get rowCount;
/// Create a copy of ChannelDescriptor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChannelDescriptorCopyWith<ChannelDescriptor> get copyWith => _$ChannelDescriptorCopyWithImpl<ChannelDescriptor>(this as ChannelDescriptor, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChannelDescriptor&&(identical(other.name, name) || other.name == name)&&(identical(other.frequencyHz, frequencyHz) || other.frequencyHz == frequencyHz)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.valueColumnCount, valueColumnCount) || other.valueColumnCount == valueColumnCount)&&(identical(other.rowCount, rowCount) || other.rowCount == rowCount));
}


@override
int get hashCode => Object.hash(runtimeType,name,frequencyHz,unit,valueColumnCount,rowCount);

@override
String toString() {
  return 'ChannelDescriptor(name: $name, frequencyHz: $frequencyHz, unit: $unit, valueColumnCount: $valueColumnCount, rowCount: $rowCount)';
}


}

/// @nodoc
abstract mixin class $ChannelDescriptorCopyWith<$Res>  {
  factory $ChannelDescriptorCopyWith(ChannelDescriptor value, $Res Function(ChannelDescriptor) _then) = _$ChannelDescriptorCopyWithImpl;
@useResult
$Res call({
 String name, int frequencyHz, String unit, int valueColumnCount, int rowCount
});




}
/// @nodoc
class _$ChannelDescriptorCopyWithImpl<$Res>
    implements $ChannelDescriptorCopyWith<$Res> {
  _$ChannelDescriptorCopyWithImpl(this._self, this._then);

  final ChannelDescriptor _self;
  final $Res Function(ChannelDescriptor) _then;

/// Create a copy of ChannelDescriptor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? frequencyHz = null,Object? unit = null,Object? valueColumnCount = null,Object? rowCount = null,}) {
  return _then(ChannelDescriptor(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,frequencyHz: null == frequencyHz ? _self.frequencyHz : frequencyHz // ignore: cast_nullable_to_non_nullable
as int,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,valueColumnCount: null == valueColumnCount ? _self.valueColumnCount : valueColumnCount // ignore: cast_nullable_to_non_nullable
as int,rowCount: null == rowCount ? _self.rowCount : rowCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ChannelDescriptor].
extension ChannelDescriptorPatterns on ChannelDescriptor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChannelDescriptor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChannelDescriptor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChannelDescriptor value)  $default,){
final _that = this;
switch (_that) {
case _ChannelDescriptor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChannelDescriptor value)?  $default,){
final _that = this;
switch (_that) {
case _ChannelDescriptor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  int frequencyHz,  String unit,  int valueColumnCount,  int rowCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChannelDescriptor() when $default != null:
return $default(_that.name,_that.frequencyHz,_that.unit,_that.valueColumnCount,_that.rowCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  int frequencyHz,  String unit,  int valueColumnCount,  int rowCount)  $default,) {final _that = this;
switch (_that) {
case _ChannelDescriptor():
return $default(_that.name,_that.frequencyHz,_that.unit,_that.valueColumnCount,_that.rowCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  int frequencyHz,  String unit,  int valueColumnCount,  int rowCount)?  $default,) {final _that = this;
switch (_that) {
case _ChannelDescriptor() when $default != null:
return $default(_that.name,_that.frequencyHz,_that.unit,_that.valueColumnCount,_that.rowCount);case _:
  return null;

}
}

}

/// @nodoc


class _ChannelDescriptor extends ChannelDescriptor {
  const _ChannelDescriptor({required this.name, required this.frequencyHz, required this.unit, required this.valueColumnCount, required this.rowCount}): super._();
  

@override final  String name;
/// The **declared** rate from the catalog. Nominal, not exact: two
/// channels declare 7 Hz and sample at ~7.0171 Hz (§5.2), so this is
/// safe for display/labelling and unsafe for timing. Use
/// [ridesMasterGrid] to decide which.
@override final  int frequencyHz;
@override final  String unit;
/// 1 for a single-value channel, 4 for a per-corner one (`value1`..
/// `value4`). Read from the table, not guessed from the name.
@override final  int valueColumnCount;
/// Row count in this file — needed to derive timestamps, and to detect a
/// channel whose declared frequency doesn't reproduce it.
@override final  int rowCount;

/// Create a copy of ChannelDescriptor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChannelDescriptorCopyWith<_ChannelDescriptor> get copyWith => __$ChannelDescriptorCopyWithImpl<_ChannelDescriptor>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChannelDescriptor&&(identical(other.name, name) || other.name == name)&&(identical(other.frequencyHz, frequencyHz) || other.frequencyHz == frequencyHz)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.valueColumnCount, valueColumnCount) || other.valueColumnCount == valueColumnCount)&&(identical(other.rowCount, rowCount) || other.rowCount == rowCount));
}


@override
int get hashCode => Object.hash(runtimeType,name,frequencyHz,unit,valueColumnCount,rowCount);

@override
String toString() {
  return 'ChannelDescriptor(name: $name, frequencyHz: $frequencyHz, unit: $unit, valueColumnCount: $valueColumnCount, rowCount: $rowCount)';
}


}

/// @nodoc
abstract mixin class _$ChannelDescriptorCopyWith<$Res> implements $ChannelDescriptorCopyWith<$Res> {
  factory _$ChannelDescriptorCopyWith(_ChannelDescriptor value, $Res Function(_ChannelDescriptor) _then) = __$ChannelDescriptorCopyWithImpl;
@override @useResult
$Res call({
 String name, int frequencyHz, String unit, int valueColumnCount, int rowCount
});




}
/// @nodoc
class __$ChannelDescriptorCopyWithImpl<$Res>
    implements _$ChannelDescriptorCopyWith<$Res> {
  __$ChannelDescriptorCopyWithImpl(this._self, this._then);

  final _ChannelDescriptor _self;
  final $Res Function(_ChannelDescriptor) _then;

/// Create a copy of ChannelDescriptor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? frequencyHz = null,Object? unit = null,Object? valueColumnCount = null,Object? rowCount = null,}) {
  return _then(_ChannelDescriptor(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,frequencyHz: null == frequencyHz ? _self.frequencyHz : frequencyHz // ignore: cast_nullable_to_non_nullable
as int,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,valueColumnCount: null == valueColumnCount ? _self.valueColumnCount : valueColumnCount // ignore: cast_nullable_to_non_nullable
as int,rowCount: null == rowCount ? _self.rowCount : rowCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$EventDescriptor {

 String get name; String get unit; int get valueColumnCount; int get rowCount;
/// Create a copy of EventDescriptor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EventDescriptorCopyWith<EventDescriptor> get copyWith => _$EventDescriptorCopyWithImpl<EventDescriptor>(this as EventDescriptor, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EventDescriptor&&(identical(other.name, name) || other.name == name)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.valueColumnCount, valueColumnCount) || other.valueColumnCount == valueColumnCount)&&(identical(other.rowCount, rowCount) || other.rowCount == rowCount));
}


@override
int get hashCode => Object.hash(runtimeType,name,unit,valueColumnCount,rowCount);

@override
String toString() {
  return 'EventDescriptor(name: $name, unit: $unit, valueColumnCount: $valueColumnCount, rowCount: $rowCount)';
}


}

/// @nodoc
abstract mixin class $EventDescriptorCopyWith<$Res>  {
  factory $EventDescriptorCopyWith(EventDescriptor value, $Res Function(EventDescriptor) _then) = _$EventDescriptorCopyWithImpl;
@useResult
$Res call({
 String name, String unit, int valueColumnCount, int rowCount
});




}
/// @nodoc
class _$EventDescriptorCopyWithImpl<$Res>
    implements $EventDescriptorCopyWith<$Res> {
  _$EventDescriptorCopyWithImpl(this._self, this._then);

  final EventDescriptor _self;
  final $Res Function(EventDescriptor) _then;

/// Create a copy of EventDescriptor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? unit = null,Object? valueColumnCount = null,Object? rowCount = null,}) {
  return _then(EventDescriptor(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,valueColumnCount: null == valueColumnCount ? _self.valueColumnCount : valueColumnCount // ignore: cast_nullable_to_non_nullable
as int,rowCount: null == rowCount ? _self.rowCount : rowCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [EventDescriptor].
extension EventDescriptorPatterns on EventDescriptor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EventDescriptor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EventDescriptor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EventDescriptor value)  $default,){
final _that = this;
switch (_that) {
case _EventDescriptor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EventDescriptor value)?  $default,){
final _that = this;
switch (_that) {
case _EventDescriptor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String unit,  int valueColumnCount,  int rowCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EventDescriptor() when $default != null:
return $default(_that.name,_that.unit,_that.valueColumnCount,_that.rowCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String unit,  int valueColumnCount,  int rowCount)  $default,) {final _that = this;
switch (_that) {
case _EventDescriptor():
return $default(_that.name,_that.unit,_that.valueColumnCount,_that.rowCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String unit,  int valueColumnCount,  int rowCount)?  $default,) {final _that = this;
switch (_that) {
case _EventDescriptor() when $default != null:
return $default(_that.name,_that.unit,_that.valueColumnCount,_that.rowCount);case _:
  return null;

}
}

}

/// @nodoc


class _EventDescriptor extends EventDescriptor {
  const _EventDescriptor({required this.name, required this.unit, required this.valueColumnCount, required this.rowCount}): super._();
  

@override final  String name;
@override final  String unit;
@override final  int valueColumnCount;
@override final  int rowCount;

/// Create a copy of EventDescriptor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EventDescriptorCopyWith<_EventDescriptor> get copyWith => __$EventDescriptorCopyWithImpl<_EventDescriptor>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EventDescriptor&&(identical(other.name, name) || other.name == name)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.valueColumnCount, valueColumnCount) || other.valueColumnCount == valueColumnCount)&&(identical(other.rowCount, rowCount) || other.rowCount == rowCount));
}


@override
int get hashCode => Object.hash(runtimeType,name,unit,valueColumnCount,rowCount);

@override
String toString() {
  return 'EventDescriptor(name: $name, unit: $unit, valueColumnCount: $valueColumnCount, rowCount: $rowCount)';
}


}

/// @nodoc
abstract mixin class _$EventDescriptorCopyWith<$Res> implements $EventDescriptorCopyWith<$Res> {
  factory _$EventDescriptorCopyWith(_EventDescriptor value, $Res Function(_EventDescriptor) _then) = __$EventDescriptorCopyWithImpl;
@override @useResult
$Res call({
 String name, String unit, int valueColumnCount, int rowCount
});




}
/// @nodoc
class __$EventDescriptorCopyWithImpl<$Res>
    implements _$EventDescriptorCopyWith<$Res> {
  __$EventDescriptorCopyWithImpl(this._self, this._then);

  final _EventDescriptor _self;
  final $Res Function(_EventDescriptor) _then;

/// Create a copy of EventDescriptor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? unit = null,Object? valueColumnCount = null,Object? rowCount = null,}) {
  return _then(_EventDescriptor(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,valueColumnCount: null == valueColumnCount ? _self.valueColumnCount : valueColumnCount // ignore: cast_nullable_to_non_nullable
as int,rowCount: null == rowCount ? _self.rowCount : rowCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$TelemetryCatalog {

 List<ChannelDescriptor> get channels; List<EventDescriptor> get events;/// `GPS Time`'s row count — the master grid's length, and the divisor in
/// every channel's timestamp derivation.
 int get masterRowCount;/// The file's own t=0: `GPS Time`'s first value, which §5.2 confirms
/// equals `MIN(ts)` of all 42 event tables to the bit. Per-file and
/// wildly variable (381.09 / 34.57 / 23.60 s across the samples), so it
/// is always read, never assumed.
 double get origin;/// `GPS Time`'s last value. Read rather than computed as
/// `origin + masterRowCount / 100`, because a recording containing a
/// discontinuity (§5.2) spans *longer* than its row count implies — the
/// two disagree by exactly the gap.
 double get endSeconds;
/// Create a copy of TelemetryCatalog
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TelemetryCatalogCopyWith<TelemetryCatalog> get copyWith => _$TelemetryCatalogCopyWithImpl<TelemetryCatalog>(this as TelemetryCatalog, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TelemetryCatalog&&const DeepCollectionEquality().equals(other.channels, channels)&&const DeepCollectionEquality().equals(other.events, events)&&(identical(other.masterRowCount, masterRowCount) || other.masterRowCount == masterRowCount)&&(identical(other.origin, origin) || other.origin == origin)&&(identical(other.endSeconds, endSeconds) || other.endSeconds == endSeconds));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(channels),const DeepCollectionEquality().hash(events),masterRowCount,origin,endSeconds);

@override
String toString() {
  return 'TelemetryCatalog(channels: $channels, events: $events, masterRowCount: $masterRowCount, origin: $origin, endSeconds: $endSeconds)';
}


}

/// @nodoc
abstract mixin class $TelemetryCatalogCopyWith<$Res>  {
  factory $TelemetryCatalogCopyWith(TelemetryCatalog value, $Res Function(TelemetryCatalog) _then) = _$TelemetryCatalogCopyWithImpl;
@useResult
$Res call({
 List<ChannelDescriptor> channels, List<EventDescriptor> events, int masterRowCount, double origin, double endSeconds
});




}
/// @nodoc
class _$TelemetryCatalogCopyWithImpl<$Res>
    implements $TelemetryCatalogCopyWith<$Res> {
  _$TelemetryCatalogCopyWithImpl(this._self, this._then);

  final TelemetryCatalog _self;
  final $Res Function(TelemetryCatalog) _then;

/// Create a copy of TelemetryCatalog
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? channels = null,Object? events = null,Object? masterRowCount = null,Object? origin = null,Object? endSeconds = null,}) {
  return _then(TelemetryCatalog(
channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as List<ChannelDescriptor>,events: null == events ? _self.events : events // ignore: cast_nullable_to_non_nullable
as List<EventDescriptor>,masterRowCount: null == masterRowCount ? _self.masterRowCount : masterRowCount // ignore: cast_nullable_to_non_nullable
as int,origin: null == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as double,endSeconds: null == endSeconds ? _self.endSeconds : endSeconds // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [TelemetryCatalog].
extension TelemetryCatalogPatterns on TelemetryCatalog {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TelemetryCatalog value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TelemetryCatalog() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TelemetryCatalog value)  $default,){
final _that = this;
switch (_that) {
case _TelemetryCatalog():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TelemetryCatalog value)?  $default,){
final _that = this;
switch (_that) {
case _TelemetryCatalog() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ChannelDescriptor> channels,  List<EventDescriptor> events,  int masterRowCount,  double origin,  double endSeconds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TelemetryCatalog() when $default != null:
return $default(_that.channels,_that.events,_that.masterRowCount,_that.origin,_that.endSeconds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ChannelDescriptor> channels,  List<EventDescriptor> events,  int masterRowCount,  double origin,  double endSeconds)  $default,) {final _that = this;
switch (_that) {
case _TelemetryCatalog():
return $default(_that.channels,_that.events,_that.masterRowCount,_that.origin,_that.endSeconds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ChannelDescriptor> channels,  List<EventDescriptor> events,  int masterRowCount,  double origin,  double endSeconds)?  $default,) {final _that = this;
switch (_that) {
case _TelemetryCatalog() when $default != null:
return $default(_that.channels,_that.events,_that.masterRowCount,_that.origin,_that.endSeconds);case _:
  return null;

}
}

}

/// @nodoc


class _TelemetryCatalog extends TelemetryCatalog {
  const _TelemetryCatalog({required  List<ChannelDescriptor> channels, required  List<EventDescriptor> events, required this.masterRowCount, required this.origin, required this.endSeconds}): _channels = channels,_events = events,super._();
  

 final  List<ChannelDescriptor> _channels;
@override List<ChannelDescriptor> get channels {
  if (_channels is EqualUnmodifiableListView) return _channels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_channels);
}

 final  List<EventDescriptor> _events;
@override List<EventDescriptor> get events {
  if (_events is EqualUnmodifiableListView) return _events;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_events);
}

/// `GPS Time`'s row count — the master grid's length, and the divisor in
/// every channel's timestamp derivation.
@override final  int masterRowCount;
/// The file's own t=0: `GPS Time`'s first value, which §5.2 confirms
/// equals `MIN(ts)` of all 42 event tables to the bit. Per-file and
/// wildly variable (381.09 / 34.57 / 23.60 s across the samples), so it
/// is always read, never assumed.
@override final  double origin;
/// `GPS Time`'s last value. Read rather than computed as
/// `origin + masterRowCount / 100`, because a recording containing a
/// discontinuity (§5.2) spans *longer* than its row count implies — the
/// two disagree by exactly the gap.
@override final  double endSeconds;

/// Create a copy of TelemetryCatalog
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TelemetryCatalogCopyWith<_TelemetryCatalog> get copyWith => __$TelemetryCatalogCopyWithImpl<_TelemetryCatalog>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TelemetryCatalog&&const DeepCollectionEquality().equals(other._channels, _channels)&&const DeepCollectionEquality().equals(other._events, _events)&&(identical(other.masterRowCount, masterRowCount) || other.masterRowCount == masterRowCount)&&(identical(other.origin, origin) || other.origin == origin)&&(identical(other.endSeconds, endSeconds) || other.endSeconds == endSeconds));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_channels),const DeepCollectionEquality().hash(_events),masterRowCount,origin,endSeconds);

@override
String toString() {
  return 'TelemetryCatalog(channels: $channels, events: $events, masterRowCount: $masterRowCount, origin: $origin, endSeconds: $endSeconds)';
}


}

/// @nodoc
abstract mixin class _$TelemetryCatalogCopyWith<$Res> implements $TelemetryCatalogCopyWith<$Res> {
  factory _$TelemetryCatalogCopyWith(_TelemetryCatalog value, $Res Function(_TelemetryCatalog) _then) = __$TelemetryCatalogCopyWithImpl;
@override @useResult
$Res call({
 List<ChannelDescriptor> channels, List<EventDescriptor> events, int masterRowCount, double origin, double endSeconds
});




}
/// @nodoc
class __$TelemetryCatalogCopyWithImpl<$Res>
    implements _$TelemetryCatalogCopyWith<$Res> {
  __$TelemetryCatalogCopyWithImpl(this._self, this._then);

  final _TelemetryCatalog _self;
  final $Res Function(_TelemetryCatalog) _then;

/// Create a copy of TelemetryCatalog
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? channels = null,Object? events = null,Object? masterRowCount = null,Object? origin = null,Object? endSeconds = null,}) {
  return _then(_TelemetryCatalog(
channels: null == channels ? _self._channels : channels // ignore: cast_nullable_to_non_nullable
as List<ChannelDescriptor>,events: null == events ? _self._events : events // ignore: cast_nullable_to_non_nullable
as List<EventDescriptor>,masterRowCount: null == masterRowCount ? _self.masterRowCount : masterRowCount // ignore: cast_nullable_to_non_nullable
as int,origin: null == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as double,endSeconds: null == endSeconds ? _self.endSeconds : endSeconds // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
