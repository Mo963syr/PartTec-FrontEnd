import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/app_settings.dart';

class Comment {
  final String id;
  final String userId;
  final String userName;
  final String content;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] is Map) ? Map<String, dynamic>.from(json['user']) : <String, dynamic>{};
    final c = (json['content'] ?? json['comment'] ?? '').toString();
    return Comment(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      userId: (user['_id'] ?? json['userId'] ?? '').toString(),
      userName: (user['name'] ?? json['userName'] ?? 'مستخدم').toString(),
      content: c,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class ReviewsProvider extends ChangeNotifier {
  bool isLoading = false;
  List<Comment> comments = [];

  Future<void> fetchPartComments(String partId) async {
    isLoading = true;
    notifyListeners();
    try {
      final uri = Uri.parse('${AppSettings.serverurl}/comment/comments/$partId');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final raw = jsonDecode(res.body);
        final Map<String, dynamic> data = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        final list = (data['comments'] as List?) ?? <dynamic>[];
        comments = list
            .whereType<Map>()
            .map((e) => Comment.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } else {
        comments = [];
      }
    } catch (_) {
      comments = [];
    }
    isLoading = false;
    notifyListeners();
  }

  Future<bool> addComment({
    required String partId,
    required String userId,
    required String content,
  }) async {
    try {
      final uri = Uri.parse('${AppSettings.serverurl}/comment/comments');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'partId': partId,
          'userId': userId,
          'content': content,
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        try {
          final raw = jsonDecode(res.body);
          final Map<String, dynamic> data = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
          final cJson = (data['comment'] is Map) ? Map<String, dynamic>.from(data['comment']) : null;
          if (cJson != null) {
            comments = [Comment.fromJson(cJson), ...comments];
            notifyListeners();
            return true;
          }
        } catch (_) {}
        await fetchPartComments(partId);
        return true;
      }
    } catch (_) {}
    return false;
  }
}
