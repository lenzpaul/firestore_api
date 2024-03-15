import 'package:firestore_api/firestore_api.dart';
import 'package:repository/repository.dart';

/// {@template firestore_remote_data_handler}
/// A remote data handler implementation that provides CRUD operations for data
/// handling using Firestore.
/// {@endtemplate}
class FirestoreRemoteDataHandler<T> extends RemoteDataHandler<T> {
  /// {@macro firestore_remote_data_handler}
  FirestoreRemoteDataHandler({
    required this.collectionName,
    required this.serializer,
  });

  final FirestoreAPIClient _firestoreAPIClient = FirestoreAPIClient.instance;

  /// The name of the collection to be used in Firestore.
  final String collectionName;

  /// The serializer to be used to serialize and deserialize data.
  @override
  final Serializer<T> serializer;

  @override
  Future<void> create({required List<T> records}) {
    return _firestoreAPIClient.create(
      collectionPath: collectionName,
      data: records.map((e) => serializer.toJson(e)).toList(),
    );
  }

  @override
  Future<List<T>> read({List<Filter> filters = const []}) async {
    Future<List<Map<String, dynamic>>> data = _firestoreAPIClient.read(
      collectionPath: collectionName,
      queryBuilders: filters.map(_filtersToQueryBuilders).toList(),
    );

    return (await data).map((e) => serializer.fromJson(e)).toList();
  }

  @override
  Future<void> update({
    fieldsToUpdate = const {},
    List<Filter> filters = const [],
  }) {
    return _firestoreAPIClient.update(
      collectionPath: collectionName,
      queryBuilders: filters.map(_filtersToQueryBuilders).toList(),
      data: fieldsToUpdate,
    );
  }

  @override
  Future<void> delete({List<Filter> filters = const []}) {
    return _firestoreAPIClient.delete(
      collectionPath: collectionName,
      queryBuilders: filters.map(_filtersToQueryBuilders).toList(),
    );
  }

  @override
  Stream<List<T>> stream({List<Filter> filters = const []}) {
    return _firestoreAPIClient
        .stream(
          collectionPath: collectionName,
          queryBuilders: filters.map(_filtersToQueryBuilders).toList(),
        )
        .map((event) => event.map((e) => serializer.fromJson(e)).toList());
  }
}

/// Converts a list of Repository [Filter]s into a list of [QueryBuilder] that
/// can be used by the Firestore API client.
QueryBuilder _filtersToQueryBuilders(Filter filter) {
  return QueryBuilder(
    field: filter.field,
    value: filter.value,
    operator: switch (filter.operator) {
      FilterOperator.lessThan => QueryOperators.lessThan,
      FilterOperator.lessThanOrEqualTo => QueryOperators.lessThanOrEqualTo,
      FilterOperator.equalTo => QueryOperators.equalTo,
      FilterOperator.greaterThan => QueryOperators.greaterThan,
      FilterOperator.greaterThanOrEqualTo =>
        QueryOperators.greaterThanOrEqualTo,
      FilterOperator.notEqualTo => QueryOperators.notEqualTo,
      FilterOperator.arrayContains => QueryOperators.arrayContains,
      FilterOperator.arrayContainsAny => QueryOperators.arrayContainsAny,
      FilterOperator.inList => QueryOperators.inList,
      FilterOperator.notInList => QueryOperators.notInList,
    },
  );
}
