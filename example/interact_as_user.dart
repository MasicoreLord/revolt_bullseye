import 'dart:io';
import 'package:revolt_bullseye/revolt_bullseye.dart';

void main() async {
  print('Temporary Account Login');
  print(' ');

  print('Write your email');
  String? email = stdin.readLineSync();
  
  print('Write your password');
  String? password = stdin.readLineSync();

  print('Attempting Login...');
  var rest = RevoltRest(baseUrl: Uri.parse('https://api.revolt.chat'));
  try {
    var data = await rest.login(payload: LoginPayload(email: '{$email}', password: '{$password}', friendlyName: 'Test Session'));
    print(data);
  } catch (err) {
    print(err);
  }
}