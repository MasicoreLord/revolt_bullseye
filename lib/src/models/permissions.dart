import 'package:revolt_bullseye/src/utils/flags_utils.dart';

class ChannelPermissions {
  final bool manageChannel;
  final bool viewChannel;
  final bool sendMessages;
  final bool manageMessages;
  final bool inviteOthers;
  final bool embedLinks;
  final bool uploadFiles;
  final bool masquerade;
  final bool voiceConnect;

  ChannelPermissions({
    required this.manageChannel,
    required this.viewChannel,
    required this.sendMessages,
    required this.manageMessages,
    required this.inviteOthers,
    required this.embedLinks,
    required this.uploadFiles,
    required this.masquerade,
    required this.voiceConnect,
  });

  ChannelPermissions.fromRaw(int raw)
      : manageChannel = FlagsUtils.isApplied(raw, 1 << 0),
        viewChannel = FlagsUtils.isApplied(raw, 1 << 20),
        sendMessages = FlagsUtils.isApplied(raw, 1 << 22),
        manageMessages = FlagsUtils.isApplied(raw, 1 << 23),
        inviteOthers = FlagsUtils.isApplied(raw, 1 << 25),
        embedLinks = FlagsUtils.isApplied(raw, 1 << 26),
        uploadFiles = FlagsUtils.isApplied(raw, 1 << 27),
        masquerade = FlagsUtils.isApplied(raw, 1 << 28),
        voiceConnect = FlagsUtils.isApplied(raw, 1 << 30);
}

class ServerPermissions {
  final bool manageChannels;
  final bool manageServer;
  final bool manageRoles;
  final bool kickMembers;
  final bool banMembers;
  final bool changeNickname;
  final bool manageNicknames;
  final bool changeAvatar;
  final bool removeAvatars;

  ServerPermissions({
    required this.manageChannels,
    required this.manageServer,
    required this.manageRoles,
    required this.kickMembers,
    required this.banMembers,
    required this.changeNickname,
    required this.manageNicknames,
    required this.changeAvatar,
    required this.removeAvatars,
  });

  ServerPermissions.fromRaw(int raw)
      : manageChannels = FlagsUtils.isApplied(raw, 1 << 0),
        manageServer = FlagsUtils.isApplied(raw, 1 << 1),
        manageRoles = FlagsUtils.isApplied(raw, 1 << 3),
        kickMembers = FlagsUtils.isApplied(raw, 1 << 6),
        banMembers = FlagsUtils.isApplied(raw, 1 << 7),
        changeNickname = FlagsUtils.isApplied(raw, 1 << 10),
        manageNicknames = FlagsUtils.isApplied(raw, 1 << 11),
        changeAvatar = FlagsUtils.isApplied(raw, 1 << 12),
        removeAvatars = FlagsUtils.isApplied(raw, 1 << 13);
}
