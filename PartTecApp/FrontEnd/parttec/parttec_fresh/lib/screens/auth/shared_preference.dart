import 'package:shared_preferences/shared_preferences.dart';

Future<String?> getSavedUserId() async {
  final sp = await SharedPreferences.getInstance();
  return sp.getString('userId');
}

Future<String?> getSavedRole() async {
  final sp = await SharedPreferences.getInstance();
  return sp.getString('role');
}
