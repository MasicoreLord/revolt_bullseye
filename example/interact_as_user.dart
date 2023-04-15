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
  if(loginAttempt['result'] == 'MFA') {
    print('Just one more step to complete login!');
    print(' ');
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
        responseField: mfaResponse // was supposed to be password according to docs, but totp_code which the official client(s) use is the only one accepted
      },
      friendlyName: 'Test Session (MFA)'
      ));
      if(mfaLoginAttempt['result'] == 'Success') {
        print('Welcome!');
      }
  } else if(loginAttempt['result'] == 'Success') {
    print('Welcome!');
  }
}