import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:revolt_bullseye/models.dart';
import 'package:http/http.dart' as http;

class RevoltRest {
  final String? botToken;
  final String? sessionToken;
  final Uri baseUrl;

  // -1 used as placeholder and also represents indefinite
  final Map<String, Map> buckets = {
    '/users': {
      'limit': -1,
      'remaining': -1,
      'reset-after': -1
    },
    '/bots': {
      'limit': -1,
      'remaining': -1,
      'reset-after': -1
    },
    '/channels': {
      'limit': -1,
      'remaining': -1,
      'reset-after': -1
    },
    '/channels/:id/messages <POST>': {
      'limit': -1,
      'remaining': -1,
      'reset-after': -1
    },
    '/servers': {
      'limit': -1,
      'remaining': -1,
      'reset-after': -1
    },
    '/auth': {
      'limit': -1,
      'remaining': -1,
      'reset-after': -1
    },
    '/auth <DELETE>': {
      'limit': -1,
      'remaining': -1,
      'reset-after': -1
    },
    '/swagger': {
      'limit': -1,
      'remaining': -1,
      'reset-after': -1
    },
    'default': {
      'limit': -1,
      'remaining': -1,
      'reset-after': -1
    }
  };
  /* final Map<String, List> queues = {
    '/users': [],
    '/bots': [],
    '/channels': [],
    '/channels/:id/messages <POST>': [],
    '/servers': [],
    '/auth': [],
    '/auth <DELETE>': [],
    '/swagger': [],
    'global': [],
    'default': []
  }; */
  String getBucketName(String method, Uri url) {
    var path = url.path;
    String result = '';

    if (path.startsWith('/users')) {
      result = '/users';
    } else if (path.startsWith('/bots')) {
      result = '/bots';
    } else if (path.startsWith('/channels') && method != 'POST') {
      result = '/channels';
    } else if (path.startsWith('/channels') && path.endsWith('/messages') && method == 'POST') {
      result = '/channels/:id/messages <POST>';
    } else if (path.startsWith('/servers')) {
      result = '/servers';
    } else if (path.startsWith('/auth') && method != 'DELETE') {
      result = '/auth';
    } else if (path.startsWith('/auth') && method == 'DELETE') {
      result = '/auth <DELETE>';
    } else if (path.startsWith('/swagger')) {
      result = '/swagger';
    } else {
      result = 'default';
    }

    return result;
  }
  bool rateLimited(String method, Uri url) {
    String bucketName = getBucketName(method, url);

    var remaining = buckets[bucketName]!['remaining'];

    print('limit remaining: $remaining');

    return !(remaining == -1 || remaining > 0);
  }


  RevoltRest({required this.baseUrl, this.botToken, this.sessionToken});

  /// Fetch raw JSON content.
  /// Can return [null], [List<dynamic>] or [Map<String, dynamic>]
  Future<dynamic> fetchRaw(
    String method,
    String path, {
    Map<String, dynamic> body = const {},
    Map<String, String> query = const {},
  }) async {

    final c = HttpClient();
    Future<HttpClientRequest> throttledRequest(String method, Uri url) async {
      String bucketName = getBucketName(method, url);

      Function? updateBucket(value) {
        buckets[bucketName] = {
          'limit': int.parse(value.headers['x-ratelimit-limit']?[0]),
          'remaining': int.parse(value.headers['x-ratelimit-remaining']?[0]),
          'reset-after': int.parse(value.headers['x-ratelimit-reset-after']?[0])
        };
        return null;
      }

      /* Function? addToQueue(method, url) {
        String bucketName = getBucketName(method, url);

        queues[bucketName]!.add({'$method': '$url'});
        return null;
      } */

      if(!rateLimited(method, url)) {
        final doRequest = await c.openUrl(method, url);
        doRequest.done.then((value) {
          updateBucket(value);
        });
        return doRequest;
      } else {
        return await Future<HttpClientRequest>.delayed(Duration(milliseconds: buckets[bucketName]!['remaining']), () async {
          final doRequest = await c.openUrl(method, url);
          doRequest.done.then((value) {
            updateBucket(value);
          });
          return doRequest;
        });
      }
    }
    
    final req = await throttledRequest(
      method,
      Uri(
        scheme: baseUrl.scheme,
        host: baseUrl.host,
        port: baseUrl.port,
        path: baseUrl.path + path,
        queryParameters: query.isEmpty ? null : query,
      ),
    );

    req.headers.contentType =
        ContentType('application', 'json', charset: 'utf-8');

    if (sessionToken != null) {
      req.headers.set('x-session-token', sessionToken!);
    } else if (botToken != null) {
      req.headers.set('x-bot-token', botToken!);
    }

    req.headers.contentLength = utf8.encode(jsonEncode(body)).length;
    req.add(utf8.encode(jsonEncode(body)));

    final res = await req.close();
    final data = await utf8.decodeStream(res);
    c.close();

    if (res.statusCode == 429) {
      var jsonData = json.decode(data);
      var timeout = jsonData['retry_after'];

      print('\x1B[31mToo many requests for: $path using $method\x1B[0m');
      
      return Future.delayed(Duration(milliseconds: timeout), () async {
        return await fetchRaw(method, path);
      });
    } else if (!(res.statusCode >= 200 && res.statusCode <= 299)) {
      throw res.statusCode;
    }

    if (data.isNotEmpty) return json.decode(data);
  }

  // --- Core ---

  /// Fetch information about which features are enabled on the remote node.
  Future<NodeInfo> queryNode() async {
    return NodeInfo.fromJson(await fetchRaw('GET', '/'));
  }

  // --- Onboarding ---

  /// This will tell you whether the current account requires onboarding or whether you can continue to send requests as usual.
  /// You may skip calling this if you're restoring an existing session.
  Future<OnboardingInformation> checkOnboardingStatus() async {
    return OnboardingInformation.fromJson(
      await fetchRaw('GET', '/onboard/hello'),
    );
  }

  /// Set a new username, complete onboarding and allow a user to start using Revolt.
  Future<void> completeOnboarding(
    CompleteOnboardingPayload completeOnboardingBuilder,
  ) async {
    await fetchRaw(
      'POST',
      '/onboard/complete',
      body: completeOnboardingBuilder.build(),
    );
  }

  // --- Account ---

  /// Fetch account information.
  Future<AccountInfo> fetchAccount() async {
    return AccountInfo.fromJson(
      await fetchRaw(
        'GET',
        '/auth/account',
      ),
    );
  }

  /// Create a new account.
  Future<void> createAccount({
    required CreateAccountPayload payload,
  }) async {
    await fetchRaw(
      'POST',
      '/auth/account/create',
      body: payload.build(),
    );
  }

  /// Resend account creation verification email.
  Future<void> resendVerfication({
    required ResendVerificationPayload payload,
  }) async {
    await fetchRaw(
      'POST',
      '/auth/account/reverify',
      body: payload.build(),
    );
  }

  /// Verify email with verification code.
  Future<void> verifyEmail({
    required String code,
  }) async {
    await fetchRaw(
      'POST',
      '/auth/account/verify/$code',
    );
  }

  /// Send password reset email.
  Future<void> sendPasswordReset({
    required SendPasswordResetPayload payload,
  }) async {
    await fetchRaw(
      'POST',
      '/auth/account/reset_password',
      body: payload.build(),
    );
  }

  /// Conirm password reset.
  Future<void> passwordReset({
    required PasswordResetPayload payload,
  }) async {
    await fetchRaw(
      'PATCH',
      '/auth/account/reset_password',
      body: payload.build(),
    );
  }

  /// Change account password.
  Future<void> changePassword({
    required ChangePasswordPayload payload,
  }) async {
    await fetchRaw(
      'PATCH',
      '/auth/account/change/password',
      body: payload.build(),
    );
  }

  /// Change account email.
  Future<void> changeEmail({
    required ChangeEmailPayload payload,
  }) async {
    await fetchRaw(
      'PATCH',
      '/auth/account/change/email',
      body: payload.build(),
    );
  }

  // --- Session ---

  /// Login to an account.
  Future login({
    required payload,
  }) async {
    final Map<String, dynamic> data = await fetchRaw(
      'POST',
      '/auth/session/login',
      body: payload.build(),
    );
    return data;
  }

  /// Close current session.
  Future<void> logout() async {
    await fetchRaw(
      'POST',
      '/auth/session/logout',
    );
  }

  /// Edit session information.
  Future<void> editSession({
    required Ulid sessionId,
    required EditSessionPayload payload,
  }) async {
    await fetchRaw(
      'PATCH',
      '/auth/session/$sessionId',
      body: payload.build(),
    );
  }

  /// Delete a specific session.
  Future<void> deleteSession({
    required Ulid sessionId,
  }) async {
    await fetchRaw(
      'DELETE',
      '/auth/session/$sessionId',
    );
  }

  /// Fetch all sessions.
  Future<List<PartialSession>> fetchSessions() async {
    return [
      for (final e in await fetchRaw(
        'GET',
        '/auth/session/all',
      ))
        PartialSession.fromJson(e)
    ];
  }

  /// Delete all active sessions.
  Future<void> deleteAllSessions({
    required DeleteAllSessionsPayload payload,
  }) async {
    await fetchRaw(
      'DELETE',
      '/auth/session/all',
      query: payload.build(),
    );
  }

  // --- User Information ---

  /// Retreive a user's information.
  Future<User> fetchUser({
    required Ulid userId,
  }) async {
    return User.fromJson(
      await fetchRaw(
        'GET',
        '/users/$userId',
      ),
    );
  }

  /// Edit your user object.
  Future<void> editUser({
    required EditUserPayload payload,
  }) async {
    await fetchRaw(
      'PATCH',
      '/users/@me',
      body: payload.build(),
    );
  }

  /// Retrieve your user information.
  Future<User> fetchSelf() async {
    return User.fromJson(
      await fetchRaw(
        'GET',
        '/users/@me',
      ),
    );
  }

  /// Change your username.
  Future<void> changeUsername({
    required ChangeUsernamePayload payload,
  }) async {
    await fetchRaw(
      'PATCH',
      '/users/@me/username',
      body: payload.build(),
    );
  }

  /// Retreive a user's profile data.
  Future<UserProfile> fetchUserProfile({
    required Ulid userId,
  }) async {
    return UserProfile.fromJson(
      await fetchRaw(
        'GET',
        '/users/$userId/profile',
      ),
    );
  }

  /// This returns a default avatar based on the given id.
  // FIXME
  // Future<String> fetchDefaultAvatar({
  //   required Ulid userId,
  // }) async {
  //   return await fetchRaw(
  //     'GET',
  //     '/users/$userId/default_avatar',
  //   ) as String;
  // }

  Future<MutualFriendsAndServers> fetchMutualFriendsAndServers({
    required Ulid userId,
  }) async {
    return MutualFriendsAndServers.fromJson(
      await fetchRaw(
        'GET',
        '/users/$userId/mutual',
      ),
    );
  }

  // --- Direct Messaging ---

  /// Fetch direct messages, including any DM and group DM conversations.
  Future<List<Channel>> fetchDirectMessageChannels() async {
    return [
      for (final e in await fetchRaw(
        'GET',
        '/users/dms',
      ))
        Channel.define(e),
    ];
  }

  /// Open a DM with another user.
  Future<DirectMessageChannel> openDiectMessage({
    required Ulid userId,
  }) async {
    return DirectMessageChannel.fromJson(
      await fetchRaw(
        'GET',
        '/users/$userId/dm',
      ),
    );
  }

  // --- Relationships ---

  /// Fetch all relationships with other users.
  Future<List<Relationship>> fetchRelationships() async {
    return [
      for (final e in await fetchRaw(
        'GET',
        '/users/relationships',
      ))
        Relationship.fromJson(e),
    ];
  }

  /// Fetch relationship with another other user.
  Future<RelationshipStatus> fetchRelationship({
    required Ulid userId,
  }) async {
    return RelationshipStatus.from(
      await fetchRaw(
        'GET',
        '/users/$userId/relationship',
      ),
    );
  }

  /// Send a friend request to another user or accept another user's friend request.
  Future<RelationshipStatus> sendFriendRequest({
    required Ulid userId,
  }) async {
    return RelationshipStatus.from(
      await fetchRaw(
        'PUT',
        '/users/$userId/friend',
      ),
    );
  }

  /// Deny another user's friend request or remove an existing friend.
  Future<RelationshipStatus> removeFriendRequest({
    required Ulid userId,
  }) async {
    return RelationshipStatus.from(
      await fetchRaw(
        'DELETE',
        '/users/$userId/friend',
      ),
    );
  }

  /// Block another user.
  Future<RelationshipStatus> blockUser({
    required Ulid userId,
  }) async {
    return RelationshipStatus.from(
      await fetchRaw(
        'PUT',
        '/users/$userId/block',
      ),
    );
  }

  /// Unblock another user.
  Future<RelationshipStatus> unblockUser({
    required Ulid userId,
  }) async {
    return RelationshipStatus.from(
      await fetchRaw(
        'DELETE',
        '/users/$userId/block',
      ),
    );
  }

  // --- Channel Information ---

  /// Retreive a channel.
  Future<T> fetchChannel<T extends Channel>({
    required Ulid channelId,
  }) async {
    return Channel.define(
      await fetchRaw(
        'GET',
        '/channels/$channelId',
      ),
    ) as T;
  }

  /// Edit a channel object.
  Future<void> editChannel({
    required Ulid channelId,
    required EditChannelPayload payload,
  }) async {
    await fetchRaw(
      'PATCH',
      '/channels/$channelId',
      body: payload.build(),
    );
  }

  /// Deletes a server channel, leaves a group or closes a DM.
  Future<void> closeChannel({
    required Ulid channelId,
  }) async {
    await fetchRaw(
      'DELETE',
      '/channels/$channelId',
    );
  }

  // --- Channel Invites ---

  /// Creates an invite to this channel
  /// Channel must be a [TextChannel]
  Future<ChannelInvite> createInvite({
    required Ulid channelId,
  }) async {
    return ChannelInvite.fromJson(
      await fetchRaw(
        'POST',
        '/channels/$channelId/invites',
      ),
    );
  }

  // --- Channel Permissions ---
  /// Sets permissions for the specified role in this channel
  /// Channel must be a [TextChannel] or [VoiceChannel]
  Future<void> setRolePermissions({
    required Ulid channelId,
    required Ulid roleId,
    required ChannelPermissionsPayload payload,
  }) async {
    await fetchRaw(
      'PUT',
      '/channels/$channelId/permissions/$roleId',
      body: payload.build(),
    );
  }

  /// Sets permissions for the default role in this channel
  /// Channel must be a [Group], [TextChannel] or [VoiceChannel]
  Future<void> setDefaultPermissions({
    required Ulid channelId,
    required ChannelPermissionsPayload payload,
  }) async {
    await fetchRaw(
      'PUT',
      '/channels/$channelId/permissions/default',
      body: payload.build(),
    );
  }

  // --- Messaging ---

  /// Send message to specified channel.
  Future<Message> sendMessage({
    required Ulid channelId,
    required MessagePayload payload,
  }) async {
    return Message.fromJson(
      await fetchRaw(
        'POST',
        '/channels/$channelId/messages',
        body: payload.build(),
      ),
    );
  }

  /// Retreive a message.
  Future<Message> fetchMessage({
    required Ulid channelId,
    required Ulid messageId,
  }) async {
    return Message.fromJson(
      await fetchRaw(
        'GET',
        '/channels/$channelId/messages/$messageId',
      ),
    );
  }

  // --- Groups ---

  /// Create a new group with friends.
  Future<Group> createGroup({
    required CreateGroupPayload payload,
  }) async {
    return Group.fromJson(
      await fetchRaw(
        'POST',
        '/channels/create',
        body: payload.build(),
      ),
    );
  }

  /// Retrieve users who are part of this group.
  Future<List<User>> fetchGroupMembers({
    required Ulid groupId,
  }) async {
    return [
      for (final e in await fetchRaw(
        'GET',
        '/channels/$groupId/members',
      ))
        User.fromJson(e)
    ];
  }

  /// Add another user to the group.
  Future<void> addGroupMember({
    required Ulid groupId,
    required Ulid userId,
  }) async {
    await fetchRaw(
      'PUT',
      '/channels/$groupId/recipients/$userId',
    );
  }

  /// Remove a user from the group.
  Future<void> removeGroupMember({
    required Ulid groupId,
    required Ulid userId,
  }) async {
    await fetchRaw(
      'DELETE',
      '/channels/$groupId/recipients/$userId',
    );
  }

  // --- Voice ---

  Future<VoiceJoinData> joinCall({
    required Ulid channelId,
  }) async {
    return VoiceJoinData.fromJson(
      await fetchRaw(
        'POST',
        '/channels/$channelId/join_call',
      ),
    );
  }

  // --- Server Information ---

  /// Retrieve a server.
  Future<Server> fetchServer({
    required Ulid serverId,
  }) async {
    return Server.fromJson(
      await fetchRaw(
        'GET',
        '/servers/$serverId',
      ),
    );
  }

  // --- Server Members ---

  // --- Server Permissions ---

  // --- Bots ---

  // --- Invites ---

  /// Fetch an invite by its code.
  Future<T> fetchInvite<T extends Invite>({
    required String inviteCode,
  }) async {
    return Invite.define(
      await fetchRaw(
        'GET',
        '/invites/$inviteCode',
      ),
    ) as T;
  }

  /// Join an invite by its code.
  Future<T> joinInvite<T extends JoinedInvite>({
    required String inviteCode,
  }) async {
    return JoinedInvite.define(
      await fetchRaw(
        'POST',
        '/invites/$inviteCode',
      ),
    ) as T;
  }

  /// Delete an invite by its code.
  Future<void> deleteInvite({
    required String inviteCode,
  }) async {
    await fetchRaw(
      'DELETE',
      '/invites/$inviteCode',
    );
  }

  // --- Sync ---

  // --- Web Push ---
}
