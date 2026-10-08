import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/game_models.dart';
import 'models/game_theme.dart';
import 'engine/fanorona_engine.dart';
import 'engine/fanorona_ai.dart';
import 'widgets/board_painter.dart';
import 'services/game_storage.dart';

void main() {
  runApp(const FanoronaApp());
}

class FanoronaApp extends StatefulWidget {
  const FanoronaApp({super.key});

  @override
  State<FanoronaApp> createState() => _FanoronaAppState();
}

class _FanoronaAppState extends State<FanoronaApp> {
  GameThemeData _currentTheme = GameThemeData.allThemes.first;

  void _updateTheme(GameThemeData theme) {
    setState(() => _currentTheme = theme);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Openorona',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _currentTheme.activeHighlightColor,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1115),
      ),
      home: MainMenuScreen(
        currentTheme: _currentTheme,
        onThemeChanged: _updateTheme,
      ),
    );
  }
}

// ==========================================
// 1. MAIN MENU SCREEN (Yazı Temizlendi)
// ==========================================
class MainMenuScreen extends StatefulWidget {
  final GameThemeData currentTheme;
  final ValueChanged<GameThemeData> onThemeChanged;

  const MainMenuScreen({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  FanoronaVariant _selectedVariant = FanoronaVariant.tsivy;
  Map<String, dynamic>? _savedGame;
  bool _vibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final saved = await GameStorage.load();
    final vibration = await GameStorage.vibrationEnabled();
    if (!mounted) return;
    setState(() {
      _savedGame = saved;
      _vibrationEnabled = vibration;
    });
  }

  Future<void> _openGame({bool vsBot = false, BotDifficulty difficulty = BotDifficulty.medium,
    int minutes = 0, Map<String, dynamic>? saved}) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(
      isVsBot: saved?['vsBot'] as bool? ?? vsBot,
      botDifficulty: saved == null ? difficulty : BotDifficulty.values[saved['difficulty'] as int],
      variant: saved == null ? _selectedVariant : FanoronaVariant.values[saved['variant'] as int],
      theme: saved == null ? widget.currentTheme : GameThemeData.allThemes.firstWhere(
        (theme) => theme.id.index == saved['theme'], orElse: () => widget.currentTheme),
      vibrationEnabled: _vibrationEnabled,
      timeLimitMinutes: saved?['minutes'] as int? ?? minutes,
      savedGame: saved,
    )));
    if (mounted) await _loadPreferences();
  }

  void _showTimeSelector() {
    showModalBottomSheet(context: context, showDragHandle: true,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const ListTile(title: Text('Pass & Play — Time per player')),
        for (final minutes in [0, 1, 3, 5, 10])
          ListTile(title: Text(minutes == 0 ? 'Unlimited' : '$minutes minutes'), onTap: () {
            Navigator.pop(ctx);
            _openGame(minutes: minutes);
          }),
      ])),
    );
  }

  void _showSettings() {
    showModalBottomSheet(context: context, showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, update) => SafeArea(
        child: SwitchListTile(title: const Text('Vibration'), value: _vibrationEnabled,
          onChanged: (enabled) {
            update(() => _vibrationEnabled = enabled);
            unawaited(GameStorage.setVibration(enabled));
          }),
      )),
    );
  }

  void _showThemeSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Board & Piece Themes',
                style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              for (final th in GameThemeData.allThemes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    tileColor: th.id == widget.currentTheme.id
                        ? th.boardBackgroundColor
                        : Theme.of(ctx).colorScheme.surfaceContainerHighest.withAlpha(60),
                    leading: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: th.boardBackgroundColor,
                        border: Border.all(color: th.activeHighlightColor, width: 2),
                      ),
                    ),
                    title: Text(th.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(th.description, style: const TextStyle(fontSize: 12)),
                    trailing: th.id == widget.currentTheme.id
                        ? Icon(Icons.check_circle_rounded, color: th.activeHighlightColor)
                        : null,
                    onTap: () {
                      widget.onThemeChanged(th);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showDifficultySelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Bot Difficulty',
                  style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                for (final diff in BotDifficulty.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      tileColor: Theme.of(ctx).colorScheme.surfaceContainerHighest.withAlpha(80),
                      leading: CircleAvatar(
                        backgroundColor: widget.currentTheme.activeHighlightColor.withAlpha(40),
                        child: Icon(Icons.psychology_outlined, color: widget.currentTheme.activeHighlightColor),
                      ),
                      title: Text(diff.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(diff.description, style: const TextStyle(fontSize: 12)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openGame(vsBot: true, difficulty: diff);
                      },
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHowToPlay(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 32, top: 8),
          children: [
            Text(
              'How to Play Fanorona',
              style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildRuleItem(
              ctx,
              icon: Icons.grid_view_rounded,
              title: 'Board Variants',
              body: '• Fanorona-Telo (3x3): 3 stones each. Fast micro-tactics.\n'
                  '• Fanorona-Dimy (5x5): 12 stones each. Quick match.\n'
                  '• Fanorona-Tsivy (9x5): 22 stones each. The Grand Madagascar strategy.',
            ),
            _buildRuleItem(
              ctx,
              icon: Icons.double_arrow_rounded,
              title: 'Captures (Mandatory)',
              body: 'Capturing is compulsory! There are 2 capture methods:\n'
                  '• Approach: Move towards an opponent stone to capture it and all unbroken stones behind it.\n'
                  '• Withdrawal: Move away from an adjacent opponent stone to capture it and all unbroken stones behind it.',
            ),
            _buildRuleItem(
              ctx,
              icon: Icons.touch_app_rounded,
              title: 'Interactive Choice',
              body: 'If a single move can capture in both directions, both target stones will glow. Tap the enemy stone you wish to take!',
            ),
            _buildRuleItem(
              ctx,
              icon: Icons.link_rounded,
              title: 'Multi-Capture Chains',
              body: 'After making a capture, the same piece can continue capturing in the same turn, provided it changes direction and does not revisit any previously stepped intersection.',
            ),
            _buildRuleItem(
              ctx,
              icon: Icons.emoji_events_rounded,
              title: 'Winning the Game',
              body: 'Capture all opponent stones to claim victory!',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleItem(BuildContext context, {required IconData icon, required String title, required String body}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: theme.colorScheme.onPrimaryContainer, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(body, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings', onPressed: _showSettings),
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Change Theme',
            onPressed: () => _showThemeSelector(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: widget.currentTheme.boardBackgroundColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: widget.currentTheme.activeHighlightColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: widget.currentTheme.activeHighlightColor.withAlpha(60),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Icon(Icons.blur_on_rounded, size: 48, color: widget.currentTheme.activeHighlightColor),
                ),
                const SizedBox(height: 20),
                Text(
                  'OPENORONA',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Traditional Strategy of Madagascar',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: 28),

                SegmentedButton<FanoronaVariant>(
                  segments: const [
                    ButtonSegment(value: FanoronaVariant.telo, label: Text('3x3')),
                    ButtonSegment(value: FanoronaVariant.dimy, label: Text('5x5')),
                    ButtonSegment(value: FanoronaVariant.tsivy, label: Text('9x5')),
                  ],
                  selected: {_selectedVariant},
                  onSelectionChanged: (val) {
                    setState(() => _selectedVariant = val.first);
                  },
                ),

                const Spacer(),
                if (_savedGame != null) ...[
                  SizedBox(width: double.infinity, height: 52,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _openGame(saved: _savedGame),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Continue Game'),
                    )),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.currentTheme.activeHighlightColor,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: _showTimeSelector,
                    icon: const Icon(Icons.people_outline_rounded),
                    label: Text(
                      'Pass & Play (${_selectedVariant.shortName})',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _showDifficultySelector(context),
                    icon: const Icon(Icons.smart_toy_outlined),
                    label: Text(
                      'Play vs Bot (${_selectedVariant.shortName})',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: TextButton.icon(
                    onPressed: () => _showHowToPlay(context),
                    icon: const Icon(Icons.menu_book_rounded),
                    label: const Text('How to Play', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
                const Spacer(),
                Text(
                  'Open Source Edition',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outlineVariant),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. GAME SCREEN (Sabit Yükseklikli Durum Alanı)
// ==========================================
class GameScreen extends StatefulWidget {
  final bool isVsBot;
  final BotDifficulty botDifficulty;
  final FanoronaVariant variant;
  final GameThemeData theme;
  final bool vibrationEnabled;
  final int timeLimitMinutes;
  final Map<String, dynamic>? savedGame;
  final BotMoveSelector botMoveSelector;

  const GameScreen({
    super.key,
    required this.isVsBot,
    this.botDifficulty = BotDifficulty.medium,
    required this.variant,
    required this.theme,
    this.vibrationEnabled = true,
    this.timeLimitMinutes = 0,
    this.savedGame,
    this.botMoveSelector = FanoronaAI.getMoveAsync,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late Map<BoardPoint, PieceType> _board;
  PieceType _turn = PieceType.white;

  BoardPoint? _selectedPoint;
  List<Move> _validMovesForSelected = [];

  BoardPoint? _chainedPiece;
  final List<BoardPoint> _visitedPoints = [];
  BoardPoint? _lastDirection;
  bool _isBotThinking = false;

  Map<BoardPoint, Move>? _interactiveCaptureTargets;

  late AnimationController _animController;
  late Animation<double> _animCurve;
  BoardPoint? _slidingFrom;
  BoardPoint? _slidingTo;
  PieceType? _slidingPiece;
  Move? _pendingMove;
  int _gameSession = 0;
  final List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _animationStart;
  List<Map<String, dynamic>>? _historyBeforeAnimation;
  Timer? _clockTimer;
  final Stopwatch _clock = Stopwatch();
  int _whiteTime = 0;
  int _blackTime = 0;
  bool _active = true;
  bool _finished = false;
  bool _leaving = false;

  bool get _timed => !widget.isVsBot && widget.timeLimitMinutes > 0;

  Map<String, dynamic> _snapshot() => {
    'board': [for (int y = 0; y < widget.variant.rows; y++)
      for (int x = 0; x < widget.variant.cols; x++)
        (_board[BoardPoint(x, y)] ?? PieceType.none).index],
    'turn': _turn.index,
    'chain': _chainedPiece == null ? null : [_chainedPiece!.x, _chainedPiece!.y],
    'visited': [for (final point in _visitedPoints) [point.x, point.y]],
    'direction': _lastDirection == null ? null : [_lastDirection!.x, _lastDirection!.y],
    'whiteTime': _whiteTime, 'blackTime': _blackTime,
  };

  void _restore(Map<String, dynamic> snapshot) {
    final pieces = snapshot['board'] as List;
    _board = {
      for (int y = 0; y < widget.variant.rows; y++)
        for (int x = 0; x < widget.variant.cols; x++)
          BoardPoint(x, y): PieceType.values[pieces[y * widget.variant.cols + x] as int],
    };
    _turn = PieceType.values[snapshot['turn'] as int];
    BoardPoint? point(dynamic value) => value == null ? null : BoardPoint(value[0] as int, value[1] as int);
    _chainedPiece = point(snapshot['chain']);
    _lastDirection = point(snapshot['direction']);
    _visitedPoints..clear()..addAll((snapshot['visited'] as List).map((p) => point(p)!));
    _whiteTime = snapshot['whiteTime'] as int;
    _blackTime = snapshot['blackTime'] as int;
    _selectedPoint = _chainedPiece;
    _validMovesForSelected = _chainedPiece == null ? [] : FanoronaEngine.getLegalMoves(
      board: _board, player: _turn, variant: widget.variant,
      chainedPiece: _chainedPiece, visitedInTurn: _visitedPoints,
      lastDirectionVector: _lastDirection,
    );
  }

  Future<bool> _saveGame() async {
    if (_finished) return false;
    final snapshot = _pendingMove == null ? _snapshot() : _animationStart!;
    final history = _pendingMove == null ? _history : _historyBeforeAnimation!;
    try {
      await GameStorage.save({
        'version': 1, 'vsBot': widget.isVsBot, 'difficulty': widget.botDifficulty.index,
        'variant': widget.variant.index, 'theme': widget.theme.id.index,
        'minutes': _timed ? widget.timeLimitMinutes : 0,
        'state': snapshot, 'history': List<Map<String, dynamic>>.from(history),
      });
      return true;
    } catch (_) {
      if (mounted && _active) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save game.')));
      }
      return false;
    }
  }

  void _cancelWork() {
    _gameSession++;
    _animController.stop();
    _pendingMove = null;
    _slidingFrom = null;
    _slidingTo = null;
    _slidingPiece = null;
    _isBotThinking = false;
    _interactiveCaptureTargets = null;
  }

  void _undo() {
    if (_history.isEmpty || _finished) return;
    _chargeClock();
    if (_finished) return;
    setState(() {
      _cancelWork();
      _restore(_history.removeLast());
      _clock..reset()..start();
    });
    unawaited(_saveGame());
  }

  void _resumeBot() {
    if (!_active || _finished || _isBotThinking || _pendingMove != null ||
        !widget.isVsBot || _turn != PieceType.black) {
      return;
    }
    if (_chainedPiece == null) {
      _triggerBotMove();
    } else {
      _triggerBotChain();
    }
  }

  void _chargeClock() {
    if (!_timed || !_active || _finished) return;
    final elapsed = _clock.elapsedMilliseconds;
    _clock..reset()..start();
    if (_turn == PieceType.white) {
      _whiteTime = (_whiteTime - elapsed).clamp(0, widget.timeLimitMinutes * 60000).toInt();
    } else {
      _blackTime = (_blackTime - elapsed).clamp(0, widget.timeLimitMinutes * 60000).toInt();
    }
    if (_whiteTime == 0 || _blackTime == 0) {
      _finishGame(_whiteTime == 0 ? 'Black' : 'White', timeExpired: true);
    }
  }

  void _pauseWork() {
    if (_pendingMove != null) {
      _restore(_animationStart!);
      _history..clear()..addAll(_historyBeforeAnimation!);
    }
    _cancelWork();
    _clock.stop();
  }

  Future<void> _leaveGame() async {
    if (_leaving) return;
    _leaving = true;
    _chargeClock();
    if (_finished) {
      _leaving = false;
      return;
    }
    _active = false;
    _pauseWork();
    await _saveGame();
    if (mounted) Navigator.pop(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_leaving) return;
    if (state == AppLifecycleState.resumed) {
      _active = true;
      _clock..reset()..start();
      setState(() {});
      _resumeBot();
    } else if (_active) {
      _chargeClock();
      _active = false;
      _pauseWork();
      unawaited(_saveGame());
    }
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _animCurve = CurvedAnimation(parent: _animController, curve: Curves.easeInOutQuad);

    WidgetsBinding.instance.addObserver(this);
    _resetGame(save: false);
    if (widget.savedGame != null) {
      try {
        _restore(Map<String, dynamic>.from(widget.savedGame!['state'] as Map));
        _history.addAll((widget.savedGame!['history'] as List).map(
          (state) => Map<String, dynamic>.from(state as Map)));
      } catch (_) {
        _resetGame(save: false);
      }
    }
    unawaited(_saveGame());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_checkWinner()) _resumeBot();
    });
    if (_timed) {
      int ticks = 0;
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_active || _finished) return;
        _chargeClock();
        setState(() {});
        if (++ticks % 5 == 0) unawaited(_saveGame());
      });
    }
  }

  @override
  void dispose() {
    _active = false;
    unawaited(_saveGame());
    _gameSession++;
    _clockTimer?.cancel();
    _clock.stop();
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    super.dispose();
  }

  void _resetGame({bool save = true}) {
    _cancelWork();
    setState(() {
      _history.clear();
      _finished = false;
      _whiteTime = _blackTime = _timed ? widget.timeLimitMinutes * 60000 : 0;
      _clock..reset()..start();
      _board = FanoronaEngine.createInitialBoard(widget.variant);
      _turn = PieceType.white;
      _selectedPoint = null;
      _validMovesForSelected = [];
      _chainedPiece = null;
      _visitedPoints.clear();
      _lastDirection = null;
      _isBotThinking = false;
      _slidingFrom = null;
      _slidingTo = null;
      _slidingPiece = null;
      _pendingMove = null;
      _interactiveCaptureTargets = null;
    });
    if (save) unawaited(_saveGame());
  }

  int _countPieces(PieceType type) => _board.values.where((p) => p == type).length;

  void _onPointTapped(BoardPoint pt) {
    if (!_active || _finished || _animController.isAnimating || _isBotThinking || (widget.isVsBot && _turn == PieceType.black)) return;

    if (_interactiveCaptureTargets != null) {
      if (_interactiveCaptureTargets!.containsKey(pt)) {
        final chosenMove = _interactiveCaptureTargets![pt]!;
        setState(() {
          _interactiveCaptureTargets = null;
        });
        _animatePieceSlide(chosenMove);
      }
      return;
    }

    final tappedPiece = _board[pt];

    if (_chainedPiece != null && pt != _chainedPiece) {
      final matchingMove = _validMovesForSelected.where((m) => m.to == pt).toList();
      if (matchingMove.isNotEmpty) {
        _handleMoveSelection(matchingMove);
      }
      return;
    }

    if (tappedPiece == _turn) {
      if (widget.vibrationEnabled) HapticFeedback.selectionClick();
      final allLegal = FanoronaEngine.getLegalMoves(
        board: _board,
        player: _turn,
        variant: widget.variant,
        chainedPiece: _chainedPiece,
        visitedInTurn: _visitedPoints,
        lastDirectionVector: _lastDirection,
      );

      final movesForThisPiece = allLegal.where((m) => m.from == pt).toList();

      setState(() {
        _selectedPoint = pt;
        _validMovesForSelected = movesForThisPiece;
      });
      return;
    }

    if (_selectedPoint != null) {
      final matchingMoves = _validMovesForSelected.where((m) => m.to == pt).toList();
      if (matchingMoves.isNotEmpty) {
        _handleMoveSelection(matchingMoves);
      }
    }
  }

  void _handleMoveSelection(List<Move> candidates) {
    if (candidates.length == 1) {
      _animatePieceSlide(candidates.first);
    } else {
      final targetMap = <BoardPoint, Move>{};
      for (final move in candidates) {
        if (move.capturedPieces.isNotEmpty) {
          targetMap[move.capturedPieces.first] = move;
        }
      }

      if (widget.vibrationEnabled) HapticFeedback.mediumImpact();
      setState(() {
        _interactiveCaptureTargets = targetMap;
      });
    }
  }

  void _animatePieceSlide(Move move) {
    _chargeClock();
    if (_finished) return;
    _animationStart = _snapshot();
    _historyBeforeAnimation = List<Map<String, dynamic>>.from(_history);
    if (!widget.isVsBot || (_turn == PieceType.white && _chainedPiece == null)) {
      _history.add(_animationStart!);
    }
    final session = _gameSession;
    if (widget.vibrationEnabled) HapticFeedback.lightImpact();
    setState(() {
      _pendingMove = move;
      _slidingFrom = move.from;
      _slidingTo = move.to;
      _slidingPiece = _turn;
      _board[move.from] = PieceType.none;
      _selectedPoint = null;
      _validMovesForSelected = [];
      _interactiveCaptureTargets = null;
    });

    _animController.forward(from: 0.0).whenCompleteOrCancel(() {
      if (!mounted || session != _gameSession || _pendingMove != move) return;
      _applyMoveInstantly(move);
    });
  }

  void _applyMoveInstantly(Move move) {
    setState(() {
      _board[move.to] = _slidingPiece!;

      for (final cap in move.capturedPieces) {
        _board[cap] = PieceType.none;
      }

      _slidingFrom = null;
      _slidingTo = null;
      _slidingPiece = null;
      _pendingMove = null;

      if (move.isCapture) {
        _visitedPoints.add(move.from);
        _lastDirection = BoardPoint(move.dx, move.dy);
        _chainedPiece = move.to;

        final nextChainMoves = FanoronaEngine.getLegalMoves(
          board: _board,
          player: _turn,
          variant: widget.variant,
          chainedPiece: _chainedPiece,
          visitedInTurn: _visitedPoints,
          lastDirectionVector: _lastDirection,
        );

        if (nextChainMoves.isNotEmpty) {
          _selectedPoint = move.to;
          _validMovesForSelected = nextChainMoves;
          if (widget.isVsBot && _turn == PieceType.black) {
            _triggerBotChain();
          }
          unawaited(_saveGame());
          return;
        }
      }

      _endTurn();
    });
  }

  void _endTurn() {
    if (_pendingMove != null) return;
    _chargeClock();
    if (_finished) return;
    if (widget.vibrationEnabled) HapticFeedback.selectionClick();
    setState(() {
      // 1. Taş seçimini ve hedef noktaları ANINDA söndür / temizle
      _selectedPoint = null;
      _validMovesForSelected = [];
      _chainedPiece = null;
      _visitedPoints.clear();
      _lastDirection = null;
      _interactiveCaptureTargets = null;

      // 2. Sırayı diğer oyuncuya devret
      _turn = (_turn == PieceType.white) ? PieceType.black : PieceType.white;
    });

    // 3. Sıra Bottaysa botu tetikle
    if (!_checkWinner() && widget.isVsBot && _turn == PieceType.black) {
      _triggerBotMove();
    }
    unawaited(_saveGame());
  }

  void _triggerBotMove() => _scheduleBotMove(const Duration(milliseconds: 500));

  void _triggerBotChain() => _scheduleBotMove(const Duration(milliseconds: 400));

  void _scheduleBotMove(Duration delay) {
    final session = _gameSession;
    setState(() => _isBotThinking = true);
    Future.delayed(delay, () async {
      if (!mounted || session != _gameSession) {
        return;
      }
      final board = Map<BoardPoint, PieceType>.of(_board);
      final visited = List<BoardPoint>.of(_visitedPoints);
      final chain = _chainedPiece;
      final direction = _lastDirection;
      Move? nextMove;
      try {
        nextMove = await widget.botMoveSelector(
          board: board,
          botPlayer: PieceType.black,
          difficulty: widget.botDifficulty,
          variant: widget.variant,
          chainedPiece: chain,
          visitedInTurn: visited,
          lastDirectionVector: direction,
        );
      } catch (error, stack) {
        if (!mounted || session != _gameSession) {
          return;
        }
        FlutterError.reportError(FlutterErrorDetails(
          exception: error, stack: stack, library: 'Fanorona AI',
        ));
        // If background dispatch fails, finish this move with a cheap legal
        // choice instead of leaving the game stuck on "Bot is thinking".
        nextMove = FanoronaAI.getMove(
          board: board, botPlayer: PieceType.black,
          difficulty: BotDifficulty.easy, variant: widget.variant,
          chainedPiece: chain, visitedInTurn: visited,
          lastDirectionVector: direction,
        );
      }
      if (!mounted || session != _gameSession) {
        return;
      }

      setState(() => _isBotThinking = false);

      if (nextMove != null) {
        _animatePieceSlide(nextMove);
      } else {
        _endTurn();
      }
    });
  }

  void _finishGame(String winner, {bool timeExpired = false}) {
    if (_finished) return;
    setState(() {
      _finished = true;
      _cancelWork();
      _clock.stop();
    });
    unawaited(GameStorage.clear());
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
      title: const Text('Game Over'),
      content: Text(timeExpired ? 'Time expired. $winner wins!' : '$winner player won the match!'),
      actions: [FilledButton(onPressed: () {
        Navigator.pop(ctx);
        _resetGame();
      }, child: const Text('Play Again'))],
    )));
  }

  bool _checkWinner() {
    final whiteCount = _countPieces(PieceType.white);
    final blackCount = _countPieces(PieceType.black);

    if (whiteCount == 0 || blackCount == 0) {
      final winner = whiteCount == 0 ? 'Black' : 'White';
      _finishGame(winner);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final whitePieces = _countPieces(PieceType.white);
    final blackPieces = _countPieces(PieceType.black);
    final cols = widget.variant.cols;
    final rows = widget.variant.rows;
    final th = widget.theme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_leaveGame());
      },
      child: Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _leaveGame),
        title: Text(
          widget.isVsBot
              ? 'Bot (${widget.botDifficulty.displayName}) • ${widget.variant.shortName}'
              : 'Pass & Play • ${widget.variant.shortName}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.undo_rounded), tooltip: 'Undo Move',
            onPressed: _history.isEmpty || _finished ? null : _undo),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Restart Game',
            onPressed: _resetGame,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildPlayerCard(
                    title: 'White',
                    count: whitePieces,
                    isActive: _turn == PieceType.white,
                    isWhitePiece: true,
                  ),
                  const SizedBox(width: 12),
                  _buildPlayerCard(
                    title: widget.isVsBot ? 'Bot' : 'Black',
                    count: blackPieces,
                    isActive: _turn == PieceType.black,
                    isWhitePiece: false,
                  ),
                ],
              ),
            ),

            // TAHTANIN KAYMASINI ÖNLEYEN SABİT YÜKSEKLİKLİ DURUM BARI
            SizedBox(
              height: 52,
              child: Center(
                child: _buildActionStatusWidget(th),
              ),
            ),

            const Spacer(),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: th.boardBackgroundColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: th.boardBorderColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(120),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: AspectRatio(
                    aspectRatio: widget.variant.aspectRatio,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final cellW = constraints.maxWidth / (cols - 1);
                        final cellH = constraints.maxHeight / (rows - 1);

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CustomPaint(
                              size: Size(constraints.maxWidth, constraints.maxHeight),
                              painter: BoardPainter(
                                variant: widget.variant,
                                theme: th,
                                highlightedPoints: _validMovesForSelected.map((m) => m.to).toList(),
                              ),
                            ),
                            for (int y = 0; y < rows; y++)
                              for (int x = 0; x < cols; x++)
                                _buildNode(x, y, cellW, cellH),

                            if (_slidingPiece != null && _slidingFrom != null && _slidingTo != null)
                              AnimatedBuilder(
                                animation: _animCurve,
                                builder: (context, child) {
                                  final currentX = _slidingFrom!.x + (_slidingTo!.x - _slidingFrom!.x) * _animCurve.value;
                                  final currentY = _slidingFrom!.y + (_slidingTo!.y - _slidingFrom!.y) * _animCurve.value;

                                  return Positioned(
                                    left: currentX * cellW - 18,
                                    top: currentY * cellH - 18,
                                    child: IgnorePointer(
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        alignment: Alignment.center,
                                        child: _buildPieceWidget(
                                          piece: _slidingPiece!,
                                          isSelected: false,
                                          isTarget: false,
                                          isCaptureTarget: false,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildActionStatusWidget(GameThemeData th) {
    if (_interactiveCaptureTargets != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: th.captureGlowColor.withAlpha(40),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: th.captureGlowColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_rounded, size: 16, color: th.captureGlowColor),
            const SizedBox(width: 6),
            Text(
              'Tap glowing enemy piece to capture!',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: th.captureGlowColor),
            ),
          ],
        ),
      );
    }

    if (_isBotThinking) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: th.activeHighlightColor),
          ),
          const SizedBox(width: 10),
          const Text('Bot is thinking...', style: TextStyle(fontStyle: FontStyle.italic)),
        ],
      );
    }

    if (_chainedPiece != null && (!widget.isVsBot || _turn == PieceType.white)) {
      return FilledButton.tonalIcon(
        onPressed: () {
          // Doğrudan turu bitirip seçimi anında temizler
          _endTurn();
        },
        icon: const Icon(Icons.check, size: 18),
        label: const Text('End Turn (Pass)'),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildNode(int x, int y, double cellW, double cellH) {
    final pt = BoardPoint(x, y);
    final piece = _board[pt] ?? PieceType.none;
    final isSelected = _selectedPoint == pt;
    final isTarget = _validMovesForSelected.any((m) => m.to == pt);
    final isCaptureTarget = _interactiveCaptureTargets?.containsKey(pt) ?? false;

    return Positioned(
      left: x * cellW - 18,
      top: y * cellH - 18,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onPointTapped(pt),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: AnimatedScale(
            scale: (isSelected || isCaptureTarget) ? 1.25 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: _buildPieceWidget(
              piece: piece,
              isSelected: isSelected,
              isTarget: isTarget,
              isCaptureTarget: isCaptureTarget,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPieceWidget({
    required PieceType piece,
    required bool isSelected,
    required bool isTarget,
    required bool isCaptureTarget,
  }) {
    final th = widget.theme;

    if (piece == PieceType.none) {
      if (isTarget) {
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: th.activeHighlightColor.withAlpha(210),
            boxShadow: [
              BoxShadow(
                color: th.activeHighlightColor.withAlpha(120),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final isWhite = piece == PieceType.white;
    final colors = isWhite ? th.whitePieceGradient : th.blackPieceGradient;
    final borderColor = isWhite ? th.whitePieceBorder : th.blackPieceBorder;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.35),
          radius: 0.85,
          colors: colors,
        ),
        border: Border.all(
          color: isCaptureTarget
              ? th.captureGlowColor
              : isSelected
                  ? th.activeHighlightColor
                  : borderColor,
          width: (isSelected || isCaptureTarget) ? 2.8 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(140),
            blurRadius: 5,
            offset: const Offset(1, 3),
          ),
          if (isCaptureTarget)
            BoxShadow(
              color: th.captureGlowColor,
              blurRadius: 12,
              spreadRadius: 3,
            )
          else if (isSelected)
            BoxShadow(
              color: th.activeHighlightColor.withAlpha(160),
              blurRadius: 8,
              spreadRadius: 2,
            ),
        ],
      ),
    );
  }

  String _formatTime(int milliseconds) {
    final seconds = (milliseconds / 1000).ceil();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Widget _buildPlayerCard({
    required String title,
    required int count,
    required bool isActive,
    required bool isWhitePiece,
  }) {
    final th = widget.theme;
    final pieceColors = isWhitePiece ? th.whitePieceGradient : th.blackPieceGradient;

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive ? th.boardBackgroundColor : const Color(0xFF1E222B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? th.activeHighlightColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.35, -0.35),
                      colors: pieceColors,
                    ),
                    border: Border.all(color: isWhitePiece ? th.whitePieceBorder : th.blackPieceBorder),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _timed ? '$title\n${_formatTime(isWhitePiece ? _whiteTime : _blackTime)}' : title,
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? th.activeHighlightColor : Colors.white,
                  ),
                ),
              ],
            ),
            Badge(
              label: Text('$count'),
              backgroundColor: th.activeHighlightColor,
              textColor: Colors.black,
            ),
          ],
        ),
      ),
    );
  }
}
