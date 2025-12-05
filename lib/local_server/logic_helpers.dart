import 'dart:convert';
import 'package:shelf/shelf.dart';

Response jsonOk(Map<String, dynamic> map) => Response.ok(
  jsonEncode(map),
  headers: {'Content-Type': 'application/json; charset=utf-8'},
);

Response jsonErr(String error, {int status = 400}) => Response(
  status,
  body: jsonEncode({'error': error}),
  headers: {'Content-Type': 'application/json; charset=utf-8'},
);

Future<Map<String, dynamic>> readJson(Request req) async {
  final raw = await req.readAsString();
  try {
    return jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
}
