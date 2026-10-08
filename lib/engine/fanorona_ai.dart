import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/game_models.dart';
import 'fanorona_engine.dart';

typedef BotMoveSelector = Future<Move?> Function({
  required Map<BoardPoint, PieceType> board,
  required PieceType botPlayer,
  required BotDifficulty difficulty,
  required FanoronaVariant variant,
  BoardPoint? chainedPiece,
  List<BoardPoint>? visitedInTurn,
  BoardPoint? lastDirectionVector,
});

class FanoronaAI {
  static final Random _rng = Random();

  static Future<Move?> getMoveAsync({
    required Map<BoardPoint, PieceType> board,
    required PieceType botPlayer,
    required BotDifficulty difficulty,
    required FanoronaVariant variant,
    BoardPoint? chainedPiece,
    List<BoardPoint>? visitedInTurn,
    BoardPoint? lastDirectionVector,
  }) {
    // Copy before dispatch: restart/undo must not change an in-flight position.
    return compute(_solve, _BotPosition(
      board: Map.of(board),
      player: botPlayer,
      difficulty: difficulty,
      variant: variant,
      chainedPiece: chainedPiece,
      visited: List.of(visitedInTurn ?? const <BoardPoint>[]),
      direction: lastDirectionVector,
    ));
  }

  static Move? _solve(_BotPosition position) => getMove(
    board: position.board,
    botPlayer: position.player,
    difficulty: position.difficulty,
    variant: position.variant,
    chainedPiece: position.chainedPiece,
    visitedInTurn: position.visited,
    lastDirectionVector: position.direction,
  );

  static Move? getMove({
    required Map<BoardPoint, PieceType> board,
    required PieceType botPlayer,
    required BotDifficulty difficulty,
    required FanoronaVariant variant,
    BoardPoint? chainedPiece,
    List<BoardPoint>? visitedInTurn,
    BoardPoint? lastDirectionVector,
  }) {
    final opponent = _other(botPlayer);
    if (!board.containsValue(botPlayer) || !board.containsValue(opponent)) {
      return null;
    }
    final legalMoves = FanoronaEngine.getLegalMoves(
      board: board,
      player: botPlayer,
      variant: variant,
      chainedPiece: chainedPiece,
      visitedInTurn: visitedInTurn,
      lastDirectionVector: lastDirectionVector,
    );
    if (legalMoves.isEmpty) {
      return null;
    }

    // Easy sees only the immediate move. Variety is limited to positions with
    // similar scores; it never switches between a deep search and a random blunder.
    final scored = [for (final move in legalMoves) (
      move: move,
      score: _evaluate(_afterMove(board, move, botPlayer), botPlayer, variant),
    )];
    final bestScore = scored.map((entry) => entry.score).reduce(max);
    final candidates = scored.where((entry) => entry.score >= bestScore - 20).toList();
    Move? bestMove = candidates[_rng.nextInt(candidates.length)].move;
    if (difficulty == BotDifficulty.easy) {
      return bestMove;
    }

    final (depth, nodes, milliseconds) = switch (difficulty) {
      BotDifficulty.easy => (1, 0, 0),
      BotDifficulty.medium => (2, 1500, 350),
      BotDifficulty.hard => (3, 5000, 650),
      BotDifficulty.expert => (4, 15000, 1000),
      BotDifficulty.master => (5, 35000, 1500),
    };
    final search = _BotSearch(
      botPlayer, variant,
      advanced: difficulty.index >= BotDifficulty.hard.index,
      extensions: difficulty == BotDifficulty.master ? 2 : 0,
      maxNodes: nodes,
      timeLimit: Duration(milliseconds: milliseconds),
    );
    _orderMoves(legalMoves);
    // Discard an incomplete iteration, so a budget cutoff cannot favour moves
    // simply because they happened to be searched first.
    for (int currentDepth = 1; currentDepth <= depth; currentDepth++) {
      try {
        bestMove = search.choose(
          board, legalMoves, currentDepth,
          chainedPiece: chainedPiece,
          visited: visitedInTurn ?? const [],
        );
      } on _SearchLimit {
        break;
      }
    }
    return bestMove;
  }
}

class _BotPosition {
  final Map<BoardPoint, PieceType> board;
  final PieceType player;
  final BotDifficulty difficulty;
  final FanoronaVariant variant;
  final BoardPoint? chainedPiece;
  final List<BoardPoint> visited;
  final BoardPoint? direction;

  const _BotPosition({required this.board, required this.player,
    required this.difficulty, required this.variant, required this.chainedPiece,
    required this.visited, required this.direction});
}

class _SearchLimit implements Exception {
  const _SearchLimit();
}

class _BotSearch {
  static const int _infinity = 100000000;
  final PieceType bot;
  final FanoronaVariant variant;
  final bool advanced;
  final int extensions;
  final int maxNodes;
  final Duration timeLimit;
  final Stopwatch _clock = Stopwatch()..start();
  int _nodes = 0;

  _BotSearch(this.bot, this.variant, {required this.advanced,
    required this.extensions, required this.maxNodes, required this.timeLimit});

  void _visit() {
    if (++_nodes > maxNodes || _clock.elapsed >= timeLimit) {
      throw const _SearchLimit();
    }
  }

  Move? choose(Map<BoardPoint, PieceType> board, List<Move> moves, int depth,
      {required BoardPoint? chainedPiece, required List<BoardPoint> visited}) {
    Move? best;
    int score = -_infinity;
    // The existing game permits ending a turn after a capture. Null tells the
    // bot's chain callback to end its turn too.
    if (chainedPiece != null) {
      score = _search(board, _other(bot), depth - 1, extensions,
        -_infinity, _infinity);
    }
    for (final move in moves) {
      final value = _scoreMove(board, move, bot, depth, extensions,
        score, _infinity, visited);
      if (value > score) {
        score = value;
        best = move;
      }
    }
    return best;
  }

  int _scoreMove(Map<BoardPoint, PieceType> board, Move move, PieceType player,
      int depth, int extra, int alpha, int beta, List<BoardPoint> visited) {
    final next = _afterMove(board, move, player);
    if (move.isCapture) {
      // A capture continuation belongs to the SAME player and search depth.
      // Branch over all continuations instead of greedily choosing one chain.
      return _search(next, player, depth, extra, alpha, beta,
        chainedPiece: move.to,
        visited: [...visited, move.from],
        direction: BoardPoint(move.dx, move.dy));
    }
    return _search(next, _other(player), depth - 1,
      depth <= 0 ? extra - 1 : extra, alpha, beta);
  }

  int _search(Map<BoardPoint, PieceType> board, PieceType player,
      int depth, int extra, int alpha, int beta, {
      BoardPoint? chainedPiece, List<BoardPoint> visited = const [],
      BoardPoint? direction}) {
    _visit();
    if (!board.containsValue(bot)) {
      return -1000000;
    }
    if (!board.containsValue(_other(bot))) {
      return 1000000;
    }

    final moves = FanoronaEngine.getLegalMoves(
      board: board, player: player, variant: variant,
      chainedPiece: chainedPiece, visitedInTurn: visited,
      lastDirectionVector: direction,
    );
    final maximizing = player == bot;
    int best = maximizing ? -_infinity : _infinity;

    if (chainedPiece != null) {
      best = _search(board, _other(player), depth - 1,
        depth <= 0 ? extra - 1 : extra, alpha, beta);
      if (maximizing) {
        alpha = max(alpha, best);
      } else {
        beta = min(beta, best);
      }
      if (moves.isEmpty || alpha >= beta) {
        return best;
      }
    } else {
      // The current game declares wins by stone elimination, not immobility.
      // Do not give a blocked position a fictitious winning score.
      if (moves.isEmpty ||
          (depth <= 0 && (extra <= 0 || !moves.first.isCapture))) {
        return _evaluate(board, bot, variant, advanced: advanced);
      }
      // At the horizon, Master extends forced captures. There is no stand-pat
      // option here: passing BEFORE the first capture is not a legal move.
    }

    _orderMoves(moves);
    for (final move in moves) {
      final value = _scoreMove(board, move, player, depth, extra,
        alpha, beta, visited);
      if (maximizing) {
        best = max(best, value);
        alpha = max(alpha, best);
      } else {
        best = min(best, value);
        beta = min(beta, best);
      }
      if (alpha >= beta) {
        break;
      }
    }
    return best;
  }
}

PieceType _other(PieceType player) =>
    player == PieceType.white ? PieceType.black : PieceType.white;

Map<BoardPoint, PieceType> _afterMove(
    Map<BoardPoint, PieceType> board, Move move, PieceType player) {
  final next = Map<BoardPoint, PieceType>.of(board);
  next[move.from] = PieceType.none;
  next[move.to] = player;
  for (final point in move.capturedPieces) {
    next[point] = PieceType.none;
  }
  return next;
}

void _orderMoves(List<Move> moves) {
  moves.sort((a, b) {
    int order = b.capturedPieces.length.compareTo(a.capturedPieces.length);
    if (order != 0) {
      return order;
    }
    order = a.from.y.compareTo(b.from.y);
    if (order != 0) {
      return order;
    }
    order = a.from.x.compareTo(b.from.x);
    if (order != 0) {
      return order;
    }
    order = a.to.y.compareTo(b.to.y);
    if (order != 0) {
      return order;
    }
    order = a.to.x.compareTo(b.to.x);
    return order != 0 ? order : a.captureType.index.compareTo(b.captureType.index);
  });
}

int _evaluate(Map<BoardPoint, PieceType> board, PieceType bot,
    FanoronaVariant variant, {bool advanced = false}) {
  int own = 0;
  int enemy = 0;
  int position = 0;
  final opponent = _other(bot);
  final centerX = (variant.cols - 1) / 2;
  final centerY = (variant.rows - 1) / 2;
  for (final entry in board.entries) {
    if (entry.value == PieceType.none) {
      continue;
    }
    final ours = entry.value == bot;
    if (ours) {
      own++;
    } else {
      enemy++;
    }
    final point = entry.key;
    final distance = (point.x - centerX).abs() + (point.y - centerY).abs();
    final bonus = (point.isStrongIntersection ? 35 : 0) +
        (10 - distance.toInt()) * 4;
    position += ours ? bonus : -bonus;
  }
  if (own == 0) {
    return -1000000;
  }
  if (enemy == 0) {
    return 1000000;
  }
  int score = (own - enemy) * 1000 + position;
  if (advanced) {
    final ownMoves = FanoronaEngine.getLegalMoves(
      board: board, player: bot, variant: variant).length;
    final enemyMoves = FanoronaEngine.getLegalMoves(
      board: board, player: opponent, variant: variant).length;
    score += (ownMoves - enemyMoves) * 15;
  }
  return score;
}
