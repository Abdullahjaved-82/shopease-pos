import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

class SyncServer {
  SyncServer({
    required this.handlerStatus,
    required this.handlerPush,
    required this.handlerPull,
    this.port = 7788,
  });

  final Future<Map<String, dynamic>> Function() handlerStatus;
  final Future<void> Function(List<Map<String, dynamic>> changes) handlerPush;
  final Future<List<Map<String, dynamic>>> Function(DateTime? since) handlerPull;
  final int port;

  HttpServer? _server;

  bool get isRunning => _server != null;

  Future<void> start() async {
    if (_server != null) return;
    final pipeline = const Pipeline().addMiddleware(logRequests());
    _server = await shelf_io.serve(
      pipeline.addHandler(_handleRequest),
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<Response> _handleRequest(Request request) async {
    final path = request.url.path;
    if (request.method == 'GET' && path == 'sync/status') {
      final status = await handlerStatus();
      return _json(status);
    }

    if (request.method == 'POST' && path == 'sync/push') {
      final body = await request.readAsString();
      final decoded = jsonDecode(body);
      final list = decoded is List ? decoded : (decoded['changes'] as List? ?? <dynamic>[]);
      final payload = list.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
      await handlerPush(payload);
      return _json({'ok': true});
    }

    if (request.method == 'GET' && path == 'sync/pull') {
      final sinceParam = request.url.queryParameters['since'];
      final since = sinceParam == null || sinceParam.isEmpty ? null : DateTime.tryParse(sinceParam)?.toUtc();
      final changes = await handlerPull(since);
      return _json({'changes': changes});
    }

    return Response.notFound('Not found');
  }

  Response _json(Map<String, dynamic> body) {
    return Response.ok(
      jsonEncode(body),
      headers: {'content-type': 'application/json'},
    );
  }
}

