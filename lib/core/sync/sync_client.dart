import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pos_system/core/sync/sync_change.dart';
import 'package:pos_system/core/sync/sync_peer.dart';

class SyncClient {
  SyncClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> status(SyncPeer peer) async {
    final uri = Uri.parse('http://${peer.ip}:${peer.port}/sync/status');
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Status request failed: ${response.statusCode}');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<void> push(SyncPeer peer, List<SyncChange> changes) async {
    if (changes.isEmpty) return;
    final uri = Uri.parse('http://${peer.ip}:${peer.port}/sync/push');
    final response = await _client.post(
      uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'changes': changes.map((e) => e.toJson()).toList(growable: false)}),
    );
    if (response.statusCode != 200) {
      throw Exception('Push failed: ${response.statusCode}');
    }
  }

  Future<List<SyncChange>> pull(SyncPeer peer, {DateTime? since}) async {
    final query = <String, String>{};
    if (since != null) {
      query['since'] = since.toUtc().toIso8601String();
    }
    final uri = Uri(
      scheme: 'http',
      host: peer.ip,
      port: peer.port,
      path: '/sync/pull',
      queryParameters: query.isEmpty ? null : query,
    );
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Pull failed: ${response.statusCode}');
    }
    final payload = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    final list = (payload['changes'] as List? ?? const <dynamic>[])
        .map((e) => SyncChange.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
    return list;
  }

  void dispose() {
    _client.close();
  }
}

