import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fanorona_game/services/game_storage.dart';

import 'package:fanorona_game/main.dart';
import 'package:fanorona_game/models/game_models.dart';
import 'package:fanorona_game/models/game_theme.dart';
import 'package:fanorona_game/widgets/board_painter.dart';

void main() {
  late SharedPreferences preferences;
  setUp(() async {
    // Each widget test has a separate fake async zone. Never retain its futures.
    GameStorage.resetForTesting();
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  Map<String, dynamic> readSavedGame() {
    final encoded = preferences.getString('saved_game');
    expect(encoded, isNotNull, reason: 'Game must persist its state after a move.');
    return jsonDecode(encoded!) as Map<String, dynamic>;
  }

  Future<void> flushStorage(WidgetTester tester) async {
    bool completed = false;
    Object? error;
    GameStorage.load().then((_) {
      completed = true;
    }, onError: (Object failure, StackTrace stack) {
      error = failure;
      completed = true;
    });
    for (int attempt = 0; attempt < 20 && !completed; attempt++) {
      await tester.pump();
    }
    expect(error, isNull);
    expect(completed, isTrue, reason: 'Persistence queue did not finish in the widget test zone.');
  }

  Future<void> startGame(WidgetTester tester, {bool vibration = true}) async {
    await tester.binding.setSurfaceSize(const Size(500, 800));
    // Create the queue inside this widget test's fake async zone, not setUp's zone.
    GameStorage.resetForTesting();
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() async {
      // Dispose and flush queued persistence before this test's fake clock ends.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        isVsBot: true,
        botDifficulty: BotDifficulty.easy,
        variant: FanoronaVariant.tsivy,
        theme: GameThemeData.allThemes.first,
        vibrationEnabled: vibration,
      ),
    ));
    await flushStorage(tester);
  }

  Future<void> makeWhiteMove(WidgetTester tester) async {
    final board = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is BoardPainter,
    );
    final topLeft = tester.getTopLeft(board);
    final size = tester.getSize(board);
    final cellWidth = size.width / 8;
    final cellHeight = size.height / 4;

    // (4,3) -> (4,2) captures the black stones at (4,1) and (4,0).
    await tester.tapAt(topLeft + Offset(4 * cellWidth, 3 * cellHeight));
    await tester.pump();
    await tester.tapAt(topLeft + Offset(4 * cellWidth, 2 * cellHeight));
    await tester.pump();
  }

  testWidgets('restart invalidates a pending bot move', (tester) async {
    await startGame(tester);
    await makeWhiteMove(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Bot is thinking...'), findsOneWidget);

    await tester.tap(find.byTooltip('Restart Game'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('22'), findsNWidgets(2));
    expect(find.text('Bot is thinking...'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('restart invalidates a move animation', (tester) async {
    await startGame(tester);
    await makeWhiteMove(tester);

    await tester.tap(find.byTooltip('Restart Game'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('22'), findsNWidgets(2));
    expect(find.text('Bot is thinking...'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending bot callback cannot update a disposed screen', (tester) async {
    await startGame(tester);
    await makeWhiteMove(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Bot is thinking...'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 800));

    expect(tester.takeException(), isNull);
  });

  testWidgets('undo restores board and cancels pending bot', (tester) async {
    await startGame(tester);
    await makeWhiteMove(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Undo Move'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('22'), findsNWidgets(2));
    expect(find.text('Bot is thinking...'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled vibration sends no haptic calls', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,
      (call) async { calls.add(call.method); return null; });
    addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.runAsync(() => GameStorage.setVibration(false));
    expect(await tester.runAsync(GameStorage.vibrationEnabled), isFalse);
    await startGame(tester, vibration: false);
    await makeWhiteMove(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls.where((method) => method == 'HapticFeedback.vibrate'), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('saved game restores board and undo history', (tester) async {
    await startGame(tester);
    debugPrint('Save/restore: making move');
    await makeWhiteMove(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await flushStorage(tester);
    final saved = readSavedGame();
    debugPrint('Save/restore: saved JSON read');
    expect(saved['state']['turn'], PieceType.black.index);
    await tester.pumpWidget(const SizedBox.shrink());
    debugPrint('Save/restore: opening saved game');
    await tester.pumpWidget(MaterialApp(home: GameScreen(
      isVsBot: true, botDifficulty: BotDifficulty.easy,
      variant: FanoronaVariant.tsivy, theme: GameThemeData.allThemes.first,
      savedGame: saved,
    )));
    expect(find.text('20'), findsOneWidget);
    debugPrint('Save/restore: undoing restored game');
    await tester.tap(find.byTooltip('Undo Move'));
    await tester.pump();
    expect(find.text('22'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 15)));

  testWidgets('Pass and Play time expires and clears saved game', (tester) async {
    await startGame(tester);
    await tester.pump();
    await flushStorage(tester);
    final saved = readSavedGame();
    saved['vsBot'] = false;
    saved['minutes'] = 1;
    saved['state']['whiteTime'] = 1;
    saved['state']['blackTime'] = 60000;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(MaterialApp(home: GameScreen(
      isVsBot: false, variant: FanoronaVariant.tsivy,
      theme: GameThemeData.allThemes.first, timeLimitMinutes: 1, savedGame: saved,
    )));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Time expired. Black wins!'), findsOneWidget);
    await tester.pump();
    await flushStorage(tester);
    expect(preferences.getString('saved_game'), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 15)));

  test('storage saves and loads the latest queued game', () async {
    final game = <String, dynamic>{
      'version': 1, 'vsBot': false, 'difficulty': 0, 'variant': 0,
      'theme': 0, 'minutes': 0, 'history': <Map<String, dynamic>>[],
      'state': <String, dynamic>{
        'board': [1, 1, 1, 0, 0, 0, 2, 2, 2], 'turn': 1,
        'chain': null, 'direction': null, 'visited': <List<int>>[],
        'whiteTime': 0, 'blackTime': 0,
      },
    };
    final first = GameStorage.save(game);
    (game['state'] as Map<String, dynamic>)['turn'] = 2;
    final second = GameStorage.save(game);
    await Future.wait([first, second]);
    expect(await GameStorage.load(), equals(game));
    await GameStorage.clear();
    expect(await GameStorage.load(), isNull);
  });
}
