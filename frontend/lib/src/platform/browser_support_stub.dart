import 'package:http/http.dart' as http;

http.Client createClient() => http.Client();
Future<T> withAuthLock<T>(String name, Future<T> Function() action) => action();
String? readPreference(String key, bool shared) => null;
void writePreference(String key, String? value, bool shared) {}
