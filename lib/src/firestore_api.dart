import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// TODO: Add documentation
// TODO: Add Transaction support
class FirestoreAPIClient {
  FirestoreAPIClient._();

  static final _instance = FirestoreAPIClient._();
  static FirestoreAPIClient get instance => _instance;

  FirebaseFirestore db = FirebaseFirestore.instance;

  //
  // List methods
  //

  /// Create multiple documents in a single batch.
  Future<void> create({
    required String collectionPath,
    required List<Map<String, dynamic>> data,
  }) async {
    final batch = db.batch();

    for (final item in data) {
      final docRef = db.collection(collectionPath).doc();
      batch.set(docRef, item);
    }

    batch
        .commit()
        .onError((e, _) => debugPrint("Error creating documents: $e"));
  }

  /// Get documents from a collection. Apply filters if needed.
  Future<List<Map<String, dynamic>>> read({
    required String collectionPath,
    List<QueryBuilder> queryBuilders = const [],
  }) async {
    Query<Map<String, dynamic>> query =
        _createQueryAndApplyFilters(collectionPath, queryBuilders);

    final QuerySnapshot<Map<String, dynamic>> querySnapshot = await query.get();

    final List<Map<String, dynamic>> documents = querySnapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> documentSnapshot) =>
            documentSnapshot.data())
        .toList();

    return documents;
  }

  /// Update multiple documents in a single batch.
  Future<void> update({
    required String collectionPath,
    List<QueryBuilder> queryBuilders = const [],
    Map<String, dynamic> data = const {},
  }) async {
    Query<Map<String, dynamic>> query =
        _createQueryAndApplyFilters(collectionPath, queryBuilders);

    final batch = db.batch();

    final QuerySnapshot<Map<String, dynamic>> querySnapshot = await query.get();

    for (final doc in querySnapshot.docs) {
      batch.update(
        doc.reference,
        data,
      );
    }

    batch
        .commit()
        .onError((e, _) => debugPrint("Error updating documents: $e"));
  }

  /// Delete multiple documents in a single batch.
  //
  // TODO: Currently, this is using Batched Writes, so this is all or nothing.
  //  Maybe we should consider partial success.
  Future<void> delete({
    required String collectionPath,
    List<QueryBuilder> queryBuilders = const [],
  }) async {
    Query<Map<String, dynamic>> query =
        _createQueryAndApplyFilters(collectionPath, queryBuilders);

    final batch = db.batch();

    final QuerySnapshot<Map<String, dynamic>> querySnapshot = await query.get();

    for (final doc in querySnapshot.docs) {
      batch.delete(doc.reference);
    }

    batch
        .commit()
        .onError((e, _) => debugPrint("Error deleting documents: $e"));
  }

  /// Stream multiple documents.
  Stream<List<Map<String, dynamic>>> stream({
    required String collectionPath,
    List<QueryBuilder> queryBuilders = const [],
  }) {
    Query<Map<String, dynamic>> query =
        _createQueryAndApplyFilters(collectionPath, queryBuilders);

    return query.snapshots().map((QuerySnapshot<Map<String, dynamic>> event) =>
        event.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>>
                    documentSnapshot) =>
                documentSnapshot.data())
            .toList());
  }

  /// Create or overwrite a single document. If the document does not exist yet,
  /// it will be created. If a document already exists, it will be overwritten.
  ///
  /// e.g.:
  /// ```dart
  /// db.collection("cities").doc("new-city-id").set({"name": "Chicago"});
  /// ```
  Future<void> setData({
    required String collectionPath,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    db
        .collection(collectionPath)
        .doc(documentId)
        .set(data)
        .onError((e, _) => print("Error writing document: $e"));
  }

  /// Create document only if not exists.
  ///
  /// This is slower than [setData] because it first checks if the document exists.
  Future<void> createData({
    required String collectionPath,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    final DocumentReference docRef =
        db.collection(collectionPath).doc(documentId);

    DocumentSnapshot snapshot = await docRef.get();

    // Create only if not exists
    if (!snapshot.exists) {
      docRef.set(data).onError(
            (e, _) => print(
              "Error writing document: $e",
            ),
          );
    } else {
      throw Exception("Document creation failed. Document already exists");
    }
  }

  /// Update fields in a document.
  ///
  /// If no document exists yet, the update will fail.
  ///
  /// e.g.:
  /// ```dart
  /// final washingtonRef = db.collection("cites").doc("DC");
  /// washingtonRef.update({"capital": true}).then(
  ///     (value) => print("DocumentSnapshot successfully updated!"),
  ///     onError: (e) => print("Error updating document $e"));
  /// ```
  Future<void> updateData({
    required String collectionPath,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    db
        .collection(collectionPath)
        .doc(documentId)
        .update(data)
        .onError((e, _) => print("Error updating document: $e"));
  }

  /// Delete a document.
  ///
  /// e.g.:
  /// ```dart
  /// db.collection("cities").doc("DC").delete().then(
  ///       (doc) => print("Document deleted"),
  ///       onError: (e) => print("Error updating document $e"),
  ///     );
  /// ```
  Future<void> deleteData({
    required String collectionPath,
    required String documentId,
  }) async {
    db
        .collection(collectionPath)
        .doc(documentId)
        .delete()
        .onError((e, _) => print("Error deleting document: $e"));
  }

  /// Delete fields in a document.
  ///
  /// e.g.:
  /// ```dart
  /// final docRef = db.collection("cities").doc("BJ");
  /// final updates = <String, dynamic>{
  ///   "capital": FieldValue.delete(),
  /// };
  ///
  /// docRef.update(updates);
  /// ```
  Future<void> deleteFields({
    required String collectionPath,
    required String documentId,
    required List<String> fields,
  }) async {
    final docRef = db.collection(collectionPath).doc(documentId);

    final updates = <String, dynamic>{};

    for (final field in fields) {
      updates[field] = FieldValue.delete();
    }
    docRef
        .update(updates)
        .onError((e, _) => print("Error deleting fields: $e"));
  }

  /// Read a document. If the document does not exist, it returns an empty
  /// [Map<String, dynamic>].
  ///
  /// Returns a [Map<String, dynamic>] with the document data.
  ///
  /// e.g.:
  /// ```dart
  /// final docRef = db.collection("cities").doc("SF");
  /// docRef.get().then(
  ///   (DocumentSnapshot doc) {
  ///     final data = doc.data() as Map<String, d  ynamic>;
  ///     // ...
  ///   },
  ///   onError: (e) => print("Error getting document: $e"),
  /// );
  /// ```
  Future<Map<String, dynamic>> readData({
    required String collectionPath,
    required String documentPath,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> documentSnapshot =
        await db.collection(collectionPath).doc(documentPath).get();

    // If the document does not exist, it returns null in the snapshot's data
    // property.
    return documentSnapshot.data() ?? {};
  }

  /// Creates a new query based on the provided [collectionPath] and [queryBuilders].
  ///
  /// The [collectionPath] parameter specifies the path of the collection to query.
  /// The [queryBuilders] parameter is a list of query builders used to add filters to the query.
  ///
  /// Returns a [Query] object representing the new query.
  Query<Map<String, dynamic>> _createQueryAndApplyFilters(
    String collectionPath,
    List<QueryBuilder> queryBuilders,
  ) {
    // Initialize the query with the collection path.
    //
    // This queries the entire collection by default unless filters are applied.
    Query<Map<String, dynamic>> query = db.collection(collectionPath);

    // Apply filters to the query.
    if (queryBuilders.isNotEmpty) {
      for (final queryBuilder in queryBuilders) {
        query = queryBuilder.addFilterToQuery(query);
      }
    }

    // Return the updated query.
    return query;
  }
}

enum QueryOperators {
  lessThan,
  lessThanOrEqualTo,
  equalTo,
  greaterThan,
  greaterThanOrEqualTo,
  notEqualTo,
  arrayContains,
  arrayContainsAny,
  inList,
  notInList,
}

/// Helper class to build a query based on filters.
class QueryBuilder {
  QueryBuilder({
    required this.field,
    required this.value,
    this.operator = QueryOperators.equalTo,
    this.limit,
    this.orderBy,
  });

  final String field;
  final dynamic value;
  final QueryOperators operator;
  final int? limit;

  /// The field to order by. Must be a valid [fieldPath] string.
  final String? orderBy;

  /// Adds a filter to a [Query]. Returns the [Query] with the filter added.
  Query<Map<String, dynamic>> addFilterToQuery(
    Query<Map<String, dynamic>> query,
  ) {
    switch (operator) {
      case QueryOperators.lessThan:
        query = query.where(field, isLessThan: value);
        break;
      case QueryOperators.lessThanOrEqualTo:
        query = query.where(field, isLessThanOrEqualTo: value);
        break;
      case QueryOperators.equalTo:
        query = query.where(field, isEqualTo: value);
        break;
      case QueryOperators.greaterThan:
        query = query.where(field, isGreaterThan: value);
        break;
      case QueryOperators.greaterThanOrEqualTo:
        query = query.where(field, isGreaterThanOrEqualTo: value);
        break;
      case QueryOperators.notEqualTo:
        query = query.where(field, isNotEqualTo: value);
        break;
      case QueryOperators.arrayContains:
        query = query.where(field, arrayContains: value);
        break;
      case QueryOperators.arrayContainsAny:
        query = query.where(field, arrayContainsAny: value);
        break;
      case QueryOperators.inList:
        query = query.where(field, whereIn: value);
        break;
      case QueryOperators.notInList:
        query = query.where(field, whereNotIn: value);
        break;
    }

    if (orderBy != null) {
      query = query.orderBy(orderBy!);
    }

    if (limit != null) {
      query = query.limit(limit!);
    }

    return query;
  }
}
