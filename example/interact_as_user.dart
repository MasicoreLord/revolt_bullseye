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
  final client = RevoltBullseye(baseUrl: Uri.parse('https://api.revolt.chat'));
  var loginAttempt = await client.login(payload: LoginPayload(
            email: '$email',
            password: '$password',
            friendlyName: 'Test Session'
            ));
  void newSession (token) => {
    RevoltBullseye(baseUrl: Uri.parse('https://api.revolt.chat'), sessionToken: token).connect()
  };
  if(loginAttempt['result'] == 'MFA') {
    print("Choose MFA Option (Avaliable Methods: '${loginAttempt['allowed_methods']}'):");
    String? mfaOption = stdin.readLineSync();

    String responseField;
    String? mfaResponse;

    switch (mfaOption) {
      case 'Password':
        print('Write your MFA Password:');
        responseField = 'password';
        mfaResponse = stdin.readLineSync();
        break;
      case 'Totp':
        print('Write your MFA Token:');
        responseField = 'totp_code';
        mfaResponse = stdin.readLineSync();
        break;
      case 'Recovery':
        print('Write your Recovery Code:');
        responseField = 'recovery_code';
        mfaResponse = stdin.readLineSync();
        break;
      default:
        throw 'MFA option was required, login aborted';
    }

    print('Attempting Login...');
    var mfaLoginAttempt = await client.login(payload: MFAPayload(
      mfaTicket: '${loginAttempt['ticket']}',
      mfaResponse: {
        responseField: mfaResponse
      },
      friendlyName: 'Test Session (MFA)'
      ));
      if(mfaLoginAttempt['result'] == 'Success') {
        newSession(mfaLoginAttempt['token']);
        print('Welcome!');
      }
  } else if(loginAttempt['result'] == 'Success') {
    newSession(loginAttempt['token']);
    print('Welcome!');
  }
}