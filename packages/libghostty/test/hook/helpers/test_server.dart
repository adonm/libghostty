import 'dart:io';

import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

class TestServer {
  final Uri baseUrl;
  final HttpServer _server;
  final List<void> _requests;
  Future<void>? _closeFuture;

  TestServer._(this._server, this.baseUrl, this._requests);

  int get requestCount => _requests.length;

  Future<void> close() => _closeFuture ??= _server.close();

  static Future<TestServer> start(Directory directory) async {
    final staticHandler = createStaticHandler(directory.path);
    final requests = <void>[];
    final server = await io.serve(
      (request) {
        requests.add(null);
        return staticHandler(request);
      },
      'localhost',
      0,
    );
    final baseUrl = Uri.parse('http://localhost:${server.port}');
    return TestServer._(server, baseUrl, requests);
  }
}
