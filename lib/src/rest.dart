import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:executor/executor.dart';

import 'package:revolt_bullseye/models.dart';

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
    '/users/:id/default_avatar': {
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
    '/safety/report': {
      'limit': -1,
      'remaining': -1,
      'reset-after': -1
    },
    '/safety': {
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
  final Map<String, Executor> executors = {
    '/users': Executor(concurrency: 10),
    '/body': Executor(concurrency: 10),
    '/channels': Executor(concurrency: 10),
    '/channels/:id/messages <POST>': Executor(concurrency: 10),
    '/servers': Executor(concurrency: 10),
    '/users/:id/default_avatar': Executor(concurrency: 10),
    '/auth': Executor(concurrency: 10),
    '/auth <DELETE>': Executor(concurrency: 10),
    '/swagger': Executor(concurrency: 10),
    '/safety/report': Executor(concurrency: 10),
    '/safety': Executor(concurrency: 10),
    'default': Executor(concurrency: 10)
  };
  String getBucketName(String method, String path) {
    String result = 'default';

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
    } else if (path.startsWith('/users') && path.endsWith('/default_avatar')) {
      result = '/users/:id/default_avatar';
    } else if (path.startsWith('/auth') && method != 'DELETE') {
      result = '/auth';
    } else if (path.startsWith('/auth') && method == 'DELETE') {
      result = '/auth <DELETE>';
    } else if (path.startsWith('/swagger')) {
      result = '/swagger';
    } else if (path.startsWith('/safety/report')) {
      result = '/safety/report';
    } else if (path.startsWith('/safety')) {
      result = '/safety';
    } else {
      result = 'default';
    }

    return result;
  }
  bool rateLimited(String method, String path) {
    String bucketName = getBucketName(method, path);
    var remaining = buckets[bucketName]!['remaining'];

    return !(remaining == -1 || remaining > 0);
  }


  RevoltRest({required this.baseUrl, this.botToken, this.sessionToken});

  /// Fetch raw JSON content.
  /// Can return [null], [List<dynamic>] or [Map<String, dynamic>]
  Future<dynamic> fetchRawInternal(
    String method,
    String path, {
    Map<String, dynamic> body = const {},
    Map<String, String> query = const {},
  }) async {
    final c = HttpClient();
    String bucketName = getBucketName(method, path);

    Future? updateBucket(response) async{
      int existingLimit = buckets[bucketName]!['limit'];
      int limit = int.parse(response.headers['x-ratelimit-limit']?[0]);
      int remaining = int.parse(response.headers['x-ratelimit-remaining']?[0]);
      int resetAfter = int.parse(response.headers['x-ratelimit-reset-after']?[0]);
      
      buckets[bucketName] = {
        'limit': limit,
        'remaining': remaining,
        'reset-after': resetAfter
      };

      Future? updateQueue() async {
        await executors[bucketName]?.join(withWaiting: true);
        await executors[bucketName]?.close();
        executors[bucketName] = Executor(concurrency: 10, rate: Rate(limit ~/ 10, Duration(milliseconds: resetAfter)));
      }


      if(existingLimit == -1) {
        await updateQueue();
      } else if(limit != existingLimit) {
        await updateQueue();
      }
      return null;
    }
    
    final req = await c.openUrl(
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

    updateBucket(res);

    if (!(res.statusCode >= 200 && res.statusCode <= 299)) {
      Map<String, dynamic> error = {
        'status': res.statusCode,
        'info': json.decode(data)
      };
      throw error;
    }

    if (data.isNotEmpty) return json.decode(data);
  }

  Future<dynamic> fetchRaw(
    String method,
    String path, {
    Map<String, dynamic> body = const {},
    Map<String, String> query = const {},
  }) async {
    String bucketName = getBucketName(method, path);
    Future queueFetch(timeout) async {
      if (timeout == -1) timeout = 0; // ensures timeout isn't using the placeholder
      return await Future.delayed(Duration(milliseconds: timeout), () async {
        return await executors[bucketName]?.scheduleTask(() async {
          // TODO: Did return here so it doesn't immediately crash (does this actually delay the tasks?)
          return await fetchRawInternal(method, path, body: body, query: query);
        });
      });
    }

    if(rateLimited(method, path)) {
      int timeout = buckets[bucketName]!['reset-after'];
      return await queueFetch(timeout);
    } else {
      try {
        return await fetchRawInternal(method, path, body: body, query: query);
      } catch(e) {
        var error = e as Map<String, dynamic>;
        if(error['status'] == 429) {
          int timeout = error['info']['retry_after'];
          return await queueFetch(timeout);
        }
      }
    }
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

  /// Request account to be deleted.
  Future<void> deleteAccount() async {
    await fetchRaw(
    'POST',
    '/auth/account/delete'
    );
  }

  /// Confirm account deletion.
  Future<void> confirmAccountDeletion({
    required String token,
  }) async {
      await fetchRaw(
      'PUT',
      '/auth/account/delete',
      body: {
        'token': token
      }
    );
  }

  /// Disable account.
  Future<void> disableAccount() async {
    await fetchRaw(
    'POST',
    '/auth/account/disable'
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

  // TODO: Implement Fetch User Flags

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

  /// Fetch mutual friends and servers
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

  /// Accept another user's friend request.
  Future<RelationshipStatus> acceptFriendRequest({
    required Ulid userId,
  }) async {
    return RelationshipStatus.from(
      await fetchRaw(
        'PUT',
        '/users/$userId/friend',
      ),
    );
  }

  /// Send friend request.
  Future<RelationshipStatus> sendFriendRequest({
    required String username,
  }) async {
    return RelationshipStatus.from(
      await fetchRaw(
        'POST',
        '/users/friend',
        body: {
          'username': username
        }
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

  // TODO: Add payload for fetch messages, so it can actually be used
  Future<Messages> fetchMessages({
    required Ulid channelId,
    FetchMessagesPayload? payload
  }) async {
    return Messages.fromJson(
      await fetchRaw(
        'GET',
        '/channels/$channelId/messages',
      ),
    );
  }

  /// Acknowledges Message/Marks as Read
  Future<void> markMessageAsRead({
    required Ulid channelId,
    required Ulid messageId,
  }) async {
    await fetchRaw(
      'PUT',
      '/channels/$channelId/ack/$messageId'
    );
  }

  /// Edit message in specified channel.
  Future<Message> editMessage({
    required Ulid channelId,
    required Ulid messageId,
    required EditMessagePayload payload,
  }) async {
    return Message.fromJson(
      await fetchRaw(
        'PATCH',
        '/channels/$channelId/messages/$messageId',
        body: payload.build(),
      ),
    );
  }

  /// Delete Message
  Future<void> deleteMessage({
    required Ulid channelId,
    required Ulid messageId,
  }) async {
    await fetchRaw(
      'DELETE',
      '/channels/$channelId/messages/$messageId',
    );
  }

  /// Bulk Delete Messages
  Future<void> buckDeleteMessages({
    required Ulid channelId,
    required List<Ulid> messageIds,
  }) async {
    await fetchRaw(
      'DELETE',
      '/channels/$channelId/messages/bulk',
      body: {
        'ids': messageIds
      }
    );
  }

  // TODO: Search for Messages and Poll Message Changes

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

  /// Delete/Leave Server
  Future<void> deleteOrLeaveServer({
    required Ulid serverId,
    bool silent = false
  }) async {
    await fetchRaw(
      'DELETE',
      '/servers/$serverId',
      query: {
        'leave_silently': silent.toString()
      }
    );
  }

  /// Mark Server as Read
  Future<void> markServerAsRead({
    required Ulid serverId
  }) async {
    await fetchRaw(
      'PUT',
      '/servers/$serverId/ack'
    );
  }

  // TODO: Add Create Server, Edit Server, and Create Channel

  // --- Server Members ---

  /// Removes user from server.
  Future<void> kickUser({
    required Ulid serverId,
    required Ulid userId
  }) async {
    await fetchRaw(
      'DELETE',
      '/servers/$serverId/members/$userId'
    );
  }

  /// Unbans user from server.
  Future<void> unbanUser({
    required Ulid serverId,
    required Ulid userId
  }) async {
    await fetchRaw(
      'DELETE',
      '/servers/$serverId/bans/$userId'
    );
  }

  // TODO: Add Fetch Member, Fetch Members, Edit Member, Ban Member, Fetch Bans, and Fetch Invites

  // --- Server Permissions ---

  /// Removes server role.
  Future<void> deleteRole({
    required Ulid serverId,
    required Ulid roleId
  }) async {
    await fetchRaw(
      'DELETE',
      '/servers/$serverId/roles/$roleId'
    );
  }

  // TODO: Add Create Role, Edit Role, Set Role Permission, and Set Default Permission

  // --- Bots ---

  // Removes bot.
  Future<void> deleteBot({
    required Ulid botId
  }) async {
    await fetchRaw(
      'DELETE',
      '/servers/$botId'
    );
  }

  // TODO: Add Create Bot, Fetch Public Bot, Invite Bot, Fetch Bot. Edit Bot, and Fetch Owned Bots

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

  // TODO: Add Fetch Settings, Set Settings, and Fetch Unreads

  // --- Web Push ---

  /// Unsubscribes from current web push subscription.
  Future<void> webPushUnsubscribe() async {
    await fetchRaw(
      'POST',
      '/push/unsubscribe');
  }

  // TODO: Add Push Subscribe
}
