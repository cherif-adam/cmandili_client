// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'food_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

FoodItem _$FoodItemFromJson(Map<String, dynamic> json) {
  return _FoodItem.fromJson(json);
}

/// @nodoc
mixin _$FoodItem {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'restaurant_id')
  String get restaurantId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  @JsonKey(name: 'image_url')
  String get imageUrl => throw _privateConstructorUsedError;
  double get price => throw _privateConstructorUsedError;
  String get category => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_available')
  bool get isAvailable => throw _privateConstructorUsedError;
  List<String> get tags => throw _privateConstructorUsedError;
  @JsonKey(name: 'preparation_time')
  int get preparationTime => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_vegetarian')
  bool get isVegetarian => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_spicy')
  bool get isSpicy => throw _privateConstructorUsedError;
  @JsonKey(name: 'discount_price')
  double? get discountPrice => throw _privateConstructorUsedError;
  @JsonKey(name: 'discount_end_time')
  DateTime? get discountEndTime => throw _privateConstructorUsedError;
  @JsonKey(name: 'discount_quantity')
  int? get discountQuantity => throw _privateConstructorUsedError;

  /// Serializes this FoodItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FoodItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FoodItemCopyWith<FoodItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FoodItemCopyWith<$Res> {
  factory $FoodItemCopyWith(FoodItem value, $Res Function(FoodItem) then) =
      _$FoodItemCopyWithImpl<$Res, FoodItem>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'restaurant_id') String restaurantId,
      String name,
      String description,
      @JsonKey(name: 'image_url') String imageUrl,
      double price,
      String category,
      @JsonKey(name: 'is_available') bool isAvailable,
      List<String> tags,
      @JsonKey(name: 'preparation_time') int preparationTime,
      @JsonKey(name: 'is_vegetarian') bool isVegetarian,
      @JsonKey(name: 'is_spicy') bool isSpicy,
      @JsonKey(name: 'discount_price') double? discountPrice,
      @JsonKey(name: 'discount_end_time') DateTime? discountEndTime,
      @JsonKey(name: 'discount_quantity') int? discountQuantity});
}

/// @nodoc
class _$FoodItemCopyWithImpl<$Res, $Val extends FoodItem>
    implements $FoodItemCopyWith<$Res> {
  _$FoodItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FoodItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? restaurantId = null,
    Object? name = null,
    Object? description = null,
    Object? imageUrl = null,
    Object? price = null,
    Object? category = null,
    Object? isAvailable = null,
    Object? tags = null,
    Object? preparationTime = null,
    Object? isVegetarian = null,
    Object? isSpicy = null,
    Object? discountPrice = freezed,
    Object? discountEndTime = freezed,
    Object? discountQuantity = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      restaurantId: null == restaurantId
          ? _value.restaurantId
          : restaurantId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      imageUrl: null == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String,
      price: null == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as double,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      isAvailable: null == isAvailable
          ? _value.isAvailable
          : isAvailable // ignore: cast_nullable_to_non_nullable
              as bool,
      tags: null == tags
          ? _value.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      preparationTime: null == preparationTime
          ? _value.preparationTime
          : preparationTime // ignore: cast_nullable_to_non_nullable
              as int,
      isVegetarian: null == isVegetarian
          ? _value.isVegetarian
          : isVegetarian // ignore: cast_nullable_to_non_nullable
              as bool,
      isSpicy: null == isSpicy
          ? _value.isSpicy
          : isSpicy // ignore: cast_nullable_to_non_nullable
              as bool,
      discountPrice: freezed == discountPrice
          ? _value.discountPrice
          : discountPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      discountEndTime: freezed == discountEndTime
          ? _value.discountEndTime
          : discountEndTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      discountQuantity: freezed == discountQuantity
          ? _value.discountQuantity
          : discountQuantity // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FoodItemImplCopyWith<$Res>
    implements $FoodItemCopyWith<$Res> {
  factory _$$FoodItemImplCopyWith(
          _$FoodItemImpl value, $Res Function(_$FoodItemImpl) then) =
      __$$FoodItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'restaurant_id') String restaurantId,
      String name,
      String description,
      @JsonKey(name: 'image_url') String imageUrl,
      double price,
      String category,
      @JsonKey(name: 'is_available') bool isAvailable,
      List<String> tags,
      @JsonKey(name: 'preparation_time') int preparationTime,
      @JsonKey(name: 'is_vegetarian') bool isVegetarian,
      @JsonKey(name: 'is_spicy') bool isSpicy,
      @JsonKey(name: 'discount_price') double? discountPrice,
      @JsonKey(name: 'discount_end_time') DateTime? discountEndTime,
      @JsonKey(name: 'discount_quantity') int? discountQuantity});
}

/// @nodoc
class __$$FoodItemImplCopyWithImpl<$Res>
    extends _$FoodItemCopyWithImpl<$Res, _$FoodItemImpl>
    implements _$$FoodItemImplCopyWith<$Res> {
  __$$FoodItemImplCopyWithImpl(
      _$FoodItemImpl _value, $Res Function(_$FoodItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of FoodItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? restaurantId = null,
    Object? name = null,
    Object? description = null,
    Object? imageUrl = null,
    Object? price = null,
    Object? category = null,
    Object? isAvailable = null,
    Object? tags = null,
    Object? preparationTime = null,
    Object? isVegetarian = null,
    Object? isSpicy = null,
    Object? discountPrice = freezed,
    Object? discountEndTime = freezed,
    Object? discountQuantity = freezed,
  }) {
    return _then(_$FoodItemImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      restaurantId: null == restaurantId
          ? _value.restaurantId
          : restaurantId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      imageUrl: null == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String,
      price: null == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as double,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      isAvailable: null == isAvailable
          ? _value.isAvailable
          : isAvailable // ignore: cast_nullable_to_non_nullable
              as bool,
      tags: null == tags
          ? _value._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      preparationTime: null == preparationTime
          ? _value.preparationTime
          : preparationTime // ignore: cast_nullable_to_non_nullable
              as int,
      isVegetarian: null == isVegetarian
          ? _value.isVegetarian
          : isVegetarian // ignore: cast_nullable_to_non_nullable
              as bool,
      isSpicy: null == isSpicy
          ? _value.isSpicy
          : isSpicy // ignore: cast_nullable_to_non_nullable
              as bool,
      discountPrice: freezed == discountPrice
          ? _value.discountPrice
          : discountPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      discountEndTime: freezed == discountEndTime
          ? _value.discountEndTime
          : discountEndTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      discountQuantity: freezed == discountQuantity
          ? _value.discountQuantity
          : discountQuantity // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FoodItemImpl implements _FoodItem {
  const _$FoodItemImpl(
      {required this.id,
      @JsonKey(name: 'restaurant_id') required this.restaurantId,
      required this.name,
      required this.description,
      @JsonKey(name: 'image_url') required this.imageUrl,
      required this.price,
      required this.category,
      @JsonKey(name: 'is_available') this.isAvailable = true,
      final List<String> tags = const [],
      @JsonKey(name: 'preparation_time') this.preparationTime = 15,
      @JsonKey(name: 'is_vegetarian') this.isVegetarian = false,
      @JsonKey(name: 'is_spicy') this.isSpicy = false,
      @JsonKey(name: 'discount_price') this.discountPrice,
      @JsonKey(name: 'discount_end_time') this.discountEndTime,
      @JsonKey(name: 'discount_quantity') this.discountQuantity})
      : _tags = tags;

  factory _$FoodItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$FoodItemImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'restaurant_id')
  final String restaurantId;
  @override
  final String name;
  @override
  final String description;
  @override
  @JsonKey(name: 'image_url')
  final String imageUrl;
  @override
  final double price;
  @override
  final String category;
  @override
  @JsonKey(name: 'is_available')
  final bool isAvailable;
  final List<String> _tags;
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  @override
  @JsonKey(name: 'preparation_time')
  final int preparationTime;
  @override
  @JsonKey(name: 'is_vegetarian')
  final bool isVegetarian;
  @override
  @JsonKey(name: 'is_spicy')
  final bool isSpicy;
  @override
  @JsonKey(name: 'discount_price')
  final double? discountPrice;
  @override
  @JsonKey(name: 'discount_end_time')
  final DateTime? discountEndTime;
  @override
  @JsonKey(name: 'discount_quantity')
  final int? discountQuantity;

  @override
  String toString() {
    return 'FoodItem(id: $id, restaurantId: $restaurantId, name: $name, description: $description, imageUrl: $imageUrl, price: $price, category: $category, isAvailable: $isAvailable, tags: $tags, preparationTime: $preparationTime, isVegetarian: $isVegetarian, isSpicy: $isSpicy, discountPrice: $discountPrice, discountEndTime: $discountEndTime, discountQuantity: $discountQuantity)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FoodItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.restaurantId, restaurantId) ||
                other.restaurantId == restaurantId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.isAvailable, isAvailable) ||
                other.isAvailable == isAvailable) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.preparationTime, preparationTime) ||
                other.preparationTime == preparationTime) &&
            (identical(other.isVegetarian, isVegetarian) ||
                other.isVegetarian == isVegetarian) &&
            (identical(other.isSpicy, isSpicy) || other.isSpicy == isSpicy) &&
            (identical(other.discountPrice, discountPrice) ||
                other.discountPrice == discountPrice) &&
            (identical(other.discountEndTime, discountEndTime) ||
                other.discountEndTime == discountEndTime) &&
            (identical(other.discountQuantity, discountQuantity) ||
                other.discountQuantity == discountQuantity));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      restaurantId,
      name,
      description,
      imageUrl,
      price,
      category,
      isAvailable,
      const DeepCollectionEquality().hash(_tags),
      preparationTime,
      isVegetarian,
      isSpicy,
      discountPrice,
      discountEndTime,
      discountQuantity);

  /// Create a copy of FoodItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FoodItemImplCopyWith<_$FoodItemImpl> get copyWith =>
      __$$FoodItemImplCopyWithImpl<_$FoodItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FoodItemImplToJson(
      this,
    );
  }
}

abstract class _FoodItem implements FoodItem {
  const factory _FoodItem(
          {required final String id,
          @JsonKey(name: 'restaurant_id') required final String restaurantId,
          required final String name,
          required final String description,
          @JsonKey(name: 'image_url') required final String imageUrl,
          required final double price,
          required final String category,
          @JsonKey(name: 'is_available') final bool isAvailable,
          final List<String> tags,
          @JsonKey(name: 'preparation_time') final int preparationTime,
          @JsonKey(name: 'is_vegetarian') final bool isVegetarian,
          @JsonKey(name: 'is_spicy') final bool isSpicy,
          @JsonKey(name: 'discount_price') final double? discountPrice,
          @JsonKey(name: 'discount_end_time') final DateTime? discountEndTime,
          @JsonKey(name: 'discount_quantity') final int? discountQuantity}) =
      _$FoodItemImpl;

  factory _FoodItem.fromJson(Map<String, dynamic> json) =
      _$FoodItemImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'restaurant_id')
  String get restaurantId;
  @override
  String get name;
  @override
  String get description;
  @override
  @JsonKey(name: 'image_url')
  String get imageUrl;
  @override
  double get price;
  @override
  String get category;
  @override
  @JsonKey(name: 'is_available')
  bool get isAvailable;
  @override
  List<String> get tags;
  @override
  @JsonKey(name: 'preparation_time')
  int get preparationTime;
  @override
  @JsonKey(name: 'is_vegetarian')
  bool get isVegetarian;
  @override
  @JsonKey(name: 'is_spicy')
  bool get isSpicy;
  @override
  @JsonKey(name: 'discount_price')
  double? get discountPrice;
  @override
  @JsonKey(name: 'discount_end_time')
  DateTime? get discountEndTime;
  @override
  @JsonKey(name: 'discount_quantity')
  int? get discountQuantity;

  /// Create a copy of FoodItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FoodItemImplCopyWith<_$FoodItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
