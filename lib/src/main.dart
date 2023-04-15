import 'package:revolt_bullseye/api.dart';

/// A wrapper around WS and REST api which takes care on management
class RevoltBullseye {
  /// Base REST API URL
  final Uri baseUrl;

  /// Token of the bot
  final String? botToken;

  /// Session token of the user
  final String? sessionToken;

  /// Revolt WebSocket API
  final RevoltWebsocket ws;
  final RevoltRest rest;

  RevoltBullseye({
    required this.baseUrl,
    this.botToken,
    this.sessionToken,
  })  : ws = RevoltWebsocket(),
        rest = RevoltRest(
          baseUrl: baseUrl,
          botToken: botToken,
          sessionToken: sessionToken,
        );

  Future login({
    required payload,
  }) async {
    final node = await rest.queryNode();
    final data = await rest.login(payload: payload);
    if (data['result'] == 'MFA') {
      print('MFA required');
      print(data);
      return data;
    } else if (data['result'] == 'Disabled') {
      print('Account is disabled!');
      print(data);
      throw 'Login Failed (Disabled Account)';
    } else if (data['result'] == 'Success') {
      print('Login successful!');
      print(data);
      return Session.fromJson(data);
    } else {
      print('Unknown status has occured!');
      print(data);
      throw 'Login Failed (Unknown Login Status)';
    }
  }

  Future<void> connect() async {
    if (!ws.isOpen) {
      final node = await rest.queryNode();
      await ws.connect(
        token: botToken ?? sessionToken ?? '',
        baseUrl: node.ws,
      );
    }
  }

  Future<void> disconnect() async {
    await ws.disconnect();
  }

  Future<void> reconnect() async {
    await disconnect();
    await connect();
  }
}
