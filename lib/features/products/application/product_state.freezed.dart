// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ProductListState {
  List<Product> get products => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  String get search => throw _privateConstructorUsedError;
  int? get categoryId => throw _privateConstructorUsedError;
  ProductSort get sort => throw _privateConstructorUsedError;
  int get offset => throw _privateConstructorUsedError;
  int get limit => throw _privateConstructorUsedError;
  bool get hasMore => throw _privateConstructorUsedError;

  /// Create a copy of ProductListState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProductListStateCopyWith<ProductListState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProductListStateCopyWith<$Res> {
  factory $ProductListStateCopyWith(
    ProductListState value,
    $Res Function(ProductListState) then,
  ) = _$ProductListStateCopyWithImpl<$Res, ProductListState>;
  @useResult
  $Res call({
    List<Product> products,
    bool isLoading,
    String search,
    int? categoryId,
    ProductSort sort,
    int offset,
    int limit,
    bool hasMore,
  });
}

/// @nodoc
class _$ProductListStateCopyWithImpl<$Res, $Val extends ProductListState>
    implements $ProductListStateCopyWith<$Res> {
  _$ProductListStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProductListState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? products = null,
    Object? isLoading = null,
    Object? search = null,
    Object? categoryId = freezed,
    Object? sort = null,
    Object? offset = null,
    Object? limit = null,
    Object? hasMore = null,
  }) {
    return _then(
      _value.copyWith(
            products: null == products
                ? _value.products
                : products // ignore: cast_nullable_to_non_nullable
                      as List<Product>,
            isLoading: null == isLoading
                ? _value.isLoading
                : isLoading // ignore: cast_nullable_to_non_nullable
                      as bool,
            search: null == search
                ? _value.search
                : search // ignore: cast_nullable_to_non_nullable
                      as String,
            categoryId: freezed == categoryId
                ? _value.categoryId
                : categoryId // ignore: cast_nullable_to_non_nullable
                      as int?,
            sort: null == sort
                ? _value.sort
                : sort // ignore: cast_nullable_to_non_nullable
                      as ProductSort,
            offset: null == offset
                ? _value.offset
                : offset // ignore: cast_nullable_to_non_nullable
                      as int,
            limit: null == limit
                ? _value.limit
                : limit // ignore: cast_nullable_to_non_nullable
                      as int,
            hasMore: null == hasMore
                ? _value.hasMore
                : hasMore // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProductListStateImplCopyWith<$Res>
    implements $ProductListStateCopyWith<$Res> {
  factory _$$ProductListStateImplCopyWith(
    _$ProductListStateImpl value,
    $Res Function(_$ProductListStateImpl) then,
  ) = __$$ProductListStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<Product> products,
    bool isLoading,
    String search,
    int? categoryId,
    ProductSort sort,
    int offset,
    int limit,
    bool hasMore,
  });
}

/// @nodoc
class __$$ProductListStateImplCopyWithImpl<$Res>
    extends _$ProductListStateCopyWithImpl<$Res, _$ProductListStateImpl>
    implements _$$ProductListStateImplCopyWith<$Res> {
  __$$ProductListStateImplCopyWithImpl(
    _$ProductListStateImpl _value,
    $Res Function(_$ProductListStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProductListState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? products = null,
    Object? isLoading = null,
    Object? search = null,
    Object? categoryId = freezed,
    Object? sort = null,
    Object? offset = null,
    Object? limit = null,
    Object? hasMore = null,
  }) {
    return _then(
      _$ProductListStateImpl(
        products: null == products
            ? _value._products
            : products // ignore: cast_nullable_to_non_nullable
                  as List<Product>,
        isLoading: null == isLoading
            ? _value.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        search: null == search
            ? _value.search
            : search // ignore: cast_nullable_to_non_nullable
                  as String,
        categoryId: freezed == categoryId
            ? _value.categoryId
            : categoryId // ignore: cast_nullable_to_non_nullable
                  as int?,
        sort: null == sort
            ? _value.sort
            : sort // ignore: cast_nullable_to_non_nullable
                  as ProductSort,
        offset: null == offset
            ? _value.offset
            : offset // ignore: cast_nullable_to_non_nullable
                  as int,
        limit: null == limit
            ? _value.limit
            : limit // ignore: cast_nullable_to_non_nullable
                  as int,
        hasMore: null == hasMore
            ? _value.hasMore
            : hasMore // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$ProductListStateImpl implements _ProductListState {
  const _$ProductListStateImpl({
    final List<Product> products = const [],
    this.isLoading = false,
    this.search = '',
    this.categoryId,
    this.sort = ProductSort.nameAsc,
    this.offset = 0,
    this.limit = 20,
    this.hasMore = false,
  }) : _products = products;

  final List<Product> _products;
  @override
  @JsonKey()
  List<Product> get products {
    if (_products is EqualUnmodifiableListView) return _products;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_products);
  }

  @override
  @JsonKey()
  final bool isLoading;
  @override
  @JsonKey()
  final String search;
  @override
  final int? categoryId;
  @override
  @JsonKey()
  final ProductSort sort;
  @override
  @JsonKey()
  final int offset;
  @override
  @JsonKey()
  final int limit;
  @override
  @JsonKey()
  final bool hasMore;

  @override
  String toString() {
    return 'ProductListState(products: $products, isLoading: $isLoading, search: $search, categoryId: $categoryId, sort: $sort, offset: $offset, limit: $limit, hasMore: $hasMore)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProductListStateImpl &&
            const DeepCollectionEquality().equals(other._products, _products) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.search, search) || other.search == search) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.sort, sort) || other.sort == sort) &&
            (identical(other.offset, offset) || other.offset == offset) &&
            (identical(other.limit, limit) || other.limit == limit) &&
            (identical(other.hasMore, hasMore) || other.hasMore == hasMore));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_products),
    isLoading,
    search,
    categoryId,
    sort,
    offset,
    limit,
    hasMore,
  );

  /// Create a copy of ProductListState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProductListStateImplCopyWith<_$ProductListStateImpl> get copyWith =>
      __$$ProductListStateImplCopyWithImpl<_$ProductListStateImpl>(
        this,
        _$identity,
      );
}

abstract class _ProductListState implements ProductListState {
  const factory _ProductListState({
    final List<Product> products,
    final bool isLoading,
    final String search,
    final int? categoryId,
    final ProductSort sort,
    final int offset,
    final int limit,
    final bool hasMore,
  }) = _$ProductListStateImpl;

  @override
  List<Product> get products;
  @override
  bool get isLoading;
  @override
  String get search;
  @override
  int? get categoryId;
  @override
  ProductSort get sort;
  @override
  int get offset;
  @override
  int get limit;
  @override
  bool get hasMore;

  /// Create a copy of ProductListState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProductListStateImplCopyWith<_$ProductListStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
