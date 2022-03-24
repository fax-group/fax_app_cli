import 'dart:io';
import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';

import 'models/message_info.dart';
import 'models/user_info.dart';
import 'models/room_info.dart';
import 'models/state_event_info.dart';
import 'models/event_info.dart';

import 'user.dart';

void main(List<String> args) async {
  var parser = ArgParser();
  parser.addFlag('help',
      abbr: 'h', negatable: false, help: 'show this message');
  parser.addOption('command', abbr: 'c', help: 'name of the command to use');
  parser.addOption('roomID', abbr: 'r', help: 'room ID');
  parser.addOption('room-name', help: 'room name');
  parser.addOption('message', abbr: 'm', help: 'message body');
  parser.addOption('preset',
      abbr: 'p', help: 'publicity preset for room creation');
  parser.addOption('topic', abbr: 't', help: 'room topic for room creation');
  parser.addOption('alias', abbr: 'a', help: 'room alias for room creation');
  parser.addOption('user', abbr: 'u', help: 'user to invite');
  parser.addOption('reason', help: 'reason for invite/knock');
  var parserResults = parser.parse(args);

  if (parserResults['help']) {
    print(parser.usage);
    exit(0);
  }

  http.Client client = http.Client();
  User user;

  Uri pathToScript = Platform.script;
  Directory baseDir = Directory.fromUri(pathToScript).parent;
  Directory dir =
      await Directory(baseDir.path + '/data').create(recursive: true);
  String filePath = dir.path;

  Hive
    ..init(filePath)
    ..registerAdapter(UserInfoAdapter())
    ..registerAdapter(StateEventInfoAdapter())
    ..registerAdapter(EventInfoAdapter())
    ..registerAdapter(RoomInfoAdapter())
    ..registerAdapter(MessageInfoAdapter());
  var db = await Hive.openBox('User');
  await db.compact();

  if (db.get('userInfo') == null) {
    print('Server: ');
    String server = stdin.readLineSync() as String;
    print('Username: ');
    String username = stdin.readLineSync() as String;
    UserInfo userInfo = UserInfo(username: username, server: server);
    user = User(userInfo);
    print("Password: ");
    db.put('userInfo', userInfo);
    await user.login(client, stdin.readLineSync());
  } else {
    user = User(db.get('userInfo'));
  }

  switch (parserResults['command']) {
    case 'initialSync':
      {
        await user.initialSync(client);
      }
      break;
    case 'sync':
      {
        await user.sync(client);
      }
      break;
    case 'newMessages':
      {
        await user.getMessages(client, parserResults['roomID'], limit: 25);
      }
      break;
    case 'oldMessages':
      {
        await user.getMessages(client, parserResults['roomID'],
            reverse: true, limit: 25);
      }
      break;
    case 'join':
      {
        await user.joinRoom(client, parserResults['roomID']);
      }
      break;
    case 'create':
      {
        await user.createRoom(client, parserResults['room-name'],
            parserResults['preset'], parserResults['topic'],
            alias: parserResults['alias']);
      }
      break;
    case 'message':
      {
        await user.sendMessage(
            client, parserResults['message'], parserResults['roomID']);
      }
      break;
    case 'list':
      {
        await user.listRooms(client);
      }
      break;
    case 'invite':
      {
        await user.inviteToRoom(client, parserResults['roomID'],
            parserResults['user'], parserResults['reason']);
      }
      break;
    case 'knock':
      {
        await user.knockOnRoom(
            client, parserResults['roomID'], parserResults['reason']);
      }
      break;
    default:
  }

  await db.close();
  client.close();
}
