import 'dart:convert';

import 'package:dio/dio.dart';

/// What the server said, without throwing about it.
///
/// `Dio` throws on a 4xx by default, which turns "the server disagreed" into an
/// exception the caller has to catch to read — and the outbox's whole job is
/// deciding what a status *means*. A refusal is data here, not control flow.
class Answer {
  const Answer({required this.status, required this.body});

  /// 0 when the request never reached anybody: no signal, DNS, a timeout.
  ///
  /// Not an error code the server chose, and deliberately not mapped onto one:
  /// `settle` treats it as worth retrying, and a phone with no signal is the
  /// ordinary case rather than a fault.
  final int status;

  final Map<String, dynamic> body;

  bool get reached => status != 0;
}

/// The seam between the app and the server.
///
/// A narrow one, on purpose: eight calls, all of them things that need a second
/// person. Nothing here computes a window, a price or a diagnosis — those are
/// the phone's and stay the phone's, which is what makes the app work on the
/// fourth day of no signal.
class Api {
  Api({required this.http, required this.baseUrl});

  final Dio http;
  final String baseUrl;

  /// The access token, held in memory only.
  ///
  /// Written to the platform's secure store by the caller — never to
  /// `shared_preferences`, which is a plain file on Android and is read by
  /// anything that can read the app's data directory.
  String? bearer;

  Future<Answer> post(String path, Map<String, dynamic> body) =>
      _send('POST', path, body: body);

  Future<Answer> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<Answer> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await http.request<dynamic>(
        '$baseUrl$path',
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          // Every status is an answer. See [Answer].
          validateStatus: (_) => true,
          headers: bearer == null ? null : {'authorization': 'Bearer $bearer'},
        ),
      );
      return Answer(
        status: response.statusCode ?? 0,
        body: _asMap(response.data),
      );
    } on DioException catch (error) {
      /*
        A phone with no signal is not an error, it is Tuesday.

        Logging this as a failure — or worse, showing it — would put a red
        message in front of somebody four days from a network for whom
        everything that matters is still working. It comes back as `reached:
        false` and the outbox tries again later.
      */
      return Answer(status: 0, body: {'why': error.type.name});
    }
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String && data.isNotEmpty) {
      try {
        final parsed = jsonDecode(data);
        if (parsed is Map<String, dynamic>) return parsed;
      } catch (_) {
        // A body that is not JSON is a body this app has nothing to say about.
      }
    }
    return const {};
  }
}
