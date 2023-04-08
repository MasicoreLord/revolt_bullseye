import 'package:revolt_bullseye/src/utils/flags_utils.dart';

class ChannelPermissions {
  final bool viewChannel;
  final bool sendMessages;
  final bool manageMessages;
  final bool manageChannel;
  final bool voiceConnect;
  final bool inviteOthers;
  final bool embedLinks;
  final bool uploadFiles;
  final bool masquerade;

  ChannelPermissions({
    required this.viewChannel,
    required this.sendMessages,
    required this.manageMessages,
    required this.manageChannel,
    required this.voiceConnect,
    required this.inviteOthers,
    required this.embedLinks,
    required this.uploadFiles,
    required this.masquerade,
  });

  ChannelPermissions.fromRaw(int raw)
      : viewChannel = FlagsUtils.isApplied(raw, 1 << 20),
        sendMessages = FlagsUtils.isApplied(raw, 1 << 22),
        manageMessages = FlagsUtils.isApplied(raw, 1 << 23),
        manageChannel = FlagsUtils.isApplied(raw, 1 << 0),
        voiceConnect = FlagsUtils.isApplied(raw, 1 << 30),
        inviteOthers = FlagsUtils.isApplied(raw, 1 << 25),
        embedLinks = FlagsUtils.isApplied(raw, 1 << 26),
        uploadFiles = FlagsUtils.isApplied(raw, 1 << 27),
        masquerade = FlagsUtils.isApplied(raw, 1 << 28);
}

class ServerPermissions {
  final bool manageRoles;
  final bool manageChannels;
  final bool manageServer;
  final bool kickMembers;
  final bool banMembers;
  final bool changeNickname;
  final bool manageNicknames;
  final bool changeAvatar;
  final bool removeAvatars;

  ServerPermissions({
    required this.manageRoles,
    required this.manageChannels,
    required this.manageServer,
    required this.kickMembers,
    required this.banMembers,
    required this.changeNickname,
    required this.manageNicknames,
    required this.changeAvatar,
    required this.removeAvatars,
  });

  ServerPermissions.fromRaw(int raw)
      : manageRoles = FlagsUtils.isApplied(raw, 1 << 3),
        manageChannels = FlagsUtils.isApplied(raw, 1 << 0),
        manageServer = FlagsUtils.isApplied(raw, 1 << 1),
        kickMembers = FlagsUtils.isApplied(raw, 1 << 6),
        banMembers = FlagsUtils.isApplied(raw, 1 << 7),
        changeNickname = FlagsUtils.isApplied(raw, 1 << 10),
        manageNicknames = FlagsUtils.isApplied(raw, 1 << 11),
        changeAvatar = FlagsUtils.isApplied(raw, 1 << 12),
        removeAvatars = FlagsUtils.isApplied(raw, 1 << 13);
}
