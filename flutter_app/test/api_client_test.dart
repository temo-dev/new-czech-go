import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/api/api_client.dart';

void main() {
  test('submitInterview sends Czech transcript JSON as UTF-8', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final receivedSubmit = Completer<Map<String, dynamic>>();
    final subscription = server.listen((request) async {
      final bodyText = await utf8.decoder.bind(request).join();

      if (request.uri.path == '/v1/auth/login') {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'data': {'access_token': 'test-token'},
              'meta': {},
            }),
          );
        await request.response.close();
        return;
      }

      if (request.uri.path == '/v1/attempts/attempt-1/submit-interview') {
        receivedSubmit.complete({
          'authorization': request.headers.value(
            HttpHeaders.authorizationHeader,
          ),
          'content_type': request.headers.contentType.toString(),
          'body': jsonDecode(bodyText) as Map<String, dynamic>,
        });
        request.response
          ..statusCode = HttpStatus.accepted
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'data': {'attempt_id': 'attempt-1', 'status': 'scoring'},
              'meta': {},
            }),
          );
        await request.response.close();
        return;
      }

      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
    });

    final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
    await client.login(email: 'learner@example.com', password: 'secret');

    const czechText = 'Dobrý den! Jsem Jana Nováková, váš zkušební komisař.';
    await client.submitInterview(
      'attempt-1',
      turns: [
        {'speaker': 'examiner', 'text': czechText, 'at_sec': 3},
      ],
      durationSec: 10,
    );

    final submit = await receivedSubmit.future.timeout(
      const Duration(seconds: 2),
    );
    final body = submit['body'] as Map<String, dynamic>;
    final transcript = body['transcript'] as List<dynamic>;
    final firstTurn = transcript.first as Map<String, dynamic>;

    expect(submit['authorization'], equals('Bearer test-token'));
    expect(submit['content_type'], contains('charset=utf-8'));
    expect(firstTurn['text'], equals(czechText));
    expect(body['duration_sec'], equals(10));
  });
}
