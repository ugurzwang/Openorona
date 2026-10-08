import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_test/flutter_test.dart';
import 'package:fanorona_game/engine/fanorona_ai.dart';
import 'package:fanorona_game/engine/fanorona_engine.dart';
import 'package:fanorona_game/models/game_models.dart';

Map<BoardPoint, PieceType> position({
  FanoronaVariant variant = FanoronaVariant.dimy,
  required List<BoardPoint> black,
  required List<BoardPoint> white,
}) => {
  for (int y = 0; y < variant.rows; y++)
    for (int x = 0; x < variant.cols; x++)
      BoardPoint(x, y): PieceType.none,
  for (final point in black) point: PieceType.black,
  for (final point in white) point: PieceType.white,
};

Map<BoardPoint, PieceType> tacticalPosition() => position(
  black: const [BoardPoint(1, 2), BoardPoint(4, 0), BoardPoint(0, 3)],
  white: const [
    BoardPoint(1, 1), BoardPoint(0, 2), BoardPoint(2, 3),
    BoardPoint(3, 4), BoardPoint(0, 1),
  ],
);

bool sameMove(Move first, Move second) =>
    first.from == second.from && first.to == second.to &&
    first.captureType == second.captureType &&
    listEquals(first.capturedPieces, second.capturedPieces);

void main() {
  test('Easy consistently chooses an immediate gain without deep tactics', () {
    final board = tacticalPosition();
    for (int attempt = 0; attempt < 20; attempt++) {
      final move = FanoronaAI.getMove(
        board: board,
        botPlayer: PieceType.black,
        difficulty: BotDifficulty.easy,
        variant: FanoronaVariant.dimy,
      );
      expect(move, isNotNull);
      expect(move!.from, const BoardPoint(0, 3));
      expect(move.to, const BoardPoint(0, 4));
      expect(move.captureType, CaptureType.withdrawal);
      expect(move.capturedPieces, hasLength(2));
    }
  });

  test('Medium plans a complete capture chain instead of the largest first hit', () {
    final move = FanoronaAI.getMove(
      board: tacticalPosition(),
      botPlayer: PieceType.black,
      difficulty: BotDifficulty.medium,
      variant: FanoronaVariant.dimy,
    );
    // This captures one stone now, then (2,2)->(2,1)->(3,1) takes three more.
    // The tempting two-stone capture at (0,3) also exposes a stone to White.
    expect(move, isNotNull);
    expect(move!.from, const BoardPoint(1, 2));
    expect(move.to, const BoardPoint(2, 2));
    expect(move.captureType, CaptureType.withdrawal);
  });

  test('Medium stops a chain when continuing lets the opponent capture everything', () {
    final board = position(
      black: const [BoardPoint(2, 1), BoardPoint(3, 1)],
      white: const [
        BoardPoint(3, 0), BoardPoint(4, 1), BoardPoint(0, 4),
        BoardPoint(4, 3), BoardPoint(1, 4),
      ],
    );
    final original = Map<BoardPoint, PieceType>.of(board);
    final visited = [const BoardPoint(4, 0)];
    final legal = FanoronaEngine.getLegalMoves(
      board: board,
      player: PieceType.black,
      variant: FanoronaVariant.dimy,
      chainedPiece: const BoardPoint(3, 1),
      visitedInTurn: visited,
      lastDirectionVector: const BoardPoint(-1, 1),
    );
    expect(legal, hasLength(1));
    expect(legal.single.to, const BoardPoint(3, 2));
    // Continuing allows White (4,1)->(3,1)->(3,0) to take both black stones.
    expect(FanoronaAI.getMove(
      board: board,
      botPlayer: PieceType.black,
      difficulty: BotDifficulty.medium,
      variant: FanoronaVariant.dimy,
      chainedPiece: const BoardPoint(3, 1),
      visitedInTurn: visited,
      lastDirectionVector: const BoardPoint(-1, 1),
    ), isNull);
    expect(board, equals(original));
    expect(visited, const [BoardPoint(4, 0)]);
  });

  test('Every difficulty returns a legal move without changing the board', () {
    for (final variant in FanoronaVariant.values) {
      final board = FanoronaEngine.createInitialBoard(variant);
      final original = Map<BoardPoint, PieceType>.of(board);
      final legal = FanoronaEngine.getLegalMoves(
        board: board, player: PieceType.black, variant: variant,
      );
      for (final difficulty in BotDifficulty.values) {
        final move = FanoronaAI.getMove(
          board: board,
          botPlayer: PieceType.black,
          difficulty: difficulty,
          variant: variant,
        );
        expect(move, isNotNull, reason: '$variant / $difficulty');
        expect(legal.any((candidate) => sameMove(candidate, move!)), isTrue,
          reason: '$variant / $difficulty must obey mandatory captures');
        expect(board, equals(original), reason: '$variant / $difficulty');
      }
    }
  });

  test('Every difficulty stops after either player has no stones', () {
    for (final difficulty in BotDifficulty.values) {
      for (final survivor in [PieceType.black, PieceType.white]) {
        final board = position(
          variant: FanoronaVariant.telo,
          black: survivor == PieceType.black ? const [BoardPoint(1, 1)] : const [],
          white: survivor == PieceType.white ? const [BoardPoint(1, 1)] : const [],
        );
        expect(FanoronaAI.getMove(
          board: board,
          botPlayer: PieceType.black,
          difficulty: difficulty,
          variant: FanoronaVariant.telo,
        ), isNull, reason: '$difficulty / remaining player $survivor');
      }
    }
  });

  test('Async search uses a snapshot of the board and chain history', () async {
    final board = position(
      variant: FanoronaVariant.telo,
      black: const [BoardPoint(1, 1)],
      white: const [BoardPoint(0, 1), BoardPoint(2, 0)],
    );
    final visited = [const BoardPoint(0, 0)];
    final result = FanoronaAI.getMoveAsync(
      board: board,
      botPlayer: PieceType.black,
      difficulty: BotDifficulty.easy,
      variant: FanoronaVariant.telo,
      chainedPiece: const BoardPoint(1, 1),
      visitedInTurn: visited,
      lastDirectionVector: const BoardPoint(-1, 1),
    );
    board.clear();
    visited.add(const BoardPoint(2, 1));

    final move = await result;
    expect(move, isNotNull);
    expect(move!.from, const BoardPoint(1, 1));
    expect(move.to, const BoardPoint(2, 1));
    expect(move.captureType, CaptureType.withdrawal);
    expect(move.capturedPieces, const [BoardPoint(0, 1)]);
    expect(board, isEmpty);
    expect(visited, const [BoardPoint(0, 0), BoardPoint(2, 1)]);
  });
}
