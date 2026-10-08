import '../models/game_models.dart';

class FanoronaEngine {
  // Varyanta göre başlangıç tahtası oluşturur
  static Map<BoardPoint, PieceType> createInitialBoard(FanoronaVariant variant) {
    final board = <BoardPoint, PieceType>{};
    final cols = variant.cols;
    final rows = variant.rows;

    if (variant == FanoronaVariant.telo) {
      // 3x3: Üstte 3 Siyah, Altta 3 Beyaz, Orta satır boş
      for (int x = 0; x < cols; x++) {
        board[BoardPoint(x, 0)] = PieceType.black;
        board[BoardPoint(x, 1)] = PieceType.none;
        board[BoardPoint(x, 2)] = PieceType.white;
      }
      return board;
    }

    if (variant == FanoronaVariant.dimy) {
      // 5x5: Üst 2 sıra Siyah (10 taş), Alt 2 sıra Beyaz (10 taş)
      // Orta sıra: S, B, Boş, S, B
      for (int y = 0; y < rows; y++) {
        for (int x = 0; x < cols; x++) {
          final pt = BoardPoint(x, y);
          if (y < 2) {
            board[pt] = PieceType.black;
          } else if (y > 2) {
            board[pt] = PieceType.white;
          } else {
            if (x == 2) {
              board[pt] = PieceType.none; // Merkez boş
            } else if (x == 0 || x == 3) {
              board[pt] = PieceType.black;
            } else {
              board[pt] = PieceType.white;
            }
          }
        }
      }
      return board;
    }

    // 9x5 Standart Tsivy
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        final pt = BoardPoint(x, y);
        if (y < 2) {
          board[pt] = PieceType.black;
        } else if (y > 2) {
          board[pt] = PieceType.white;
        } else {
          if (x == 4) {
            board[pt] = PieceType.none; // Merkez boş
          } else if (x == 0 || x == 2 || x == 5 || x == 7) {
            board[pt] = PieceType.black;
          } else {
            board[pt] = PieceType.white;
          }
        }
      }
    }
    return board;
  }

  // Geçerli komşular
  static List<BoardPoint> getValidNeighbors(BoardPoint pt, FanoronaVariant variant) {
    final neighbors = <BoardPoint>[];
    final isStrong = pt.isStrongIntersection;
    final cols = variant.cols;
    final rows = variant.rows;

    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        if (dx == 0 && dy == 0) continue;
        if (dx != 0 && dy != 0 && !isStrong) continue;

        final nx = pt.x + dx;
        final ny = pt.y + dy;

        if (nx >= 0 && nx < cols && ny >= 0 && ny < rows) {
          neighbors.add(BoardPoint(nx, ny));
        }
      }
    }
    return neighbors;
  }

  // Yeme hesaplama
  static List<BoardPoint> getCaptures({
    required Map<BoardPoint, PieceType> board,
    required BoardPoint from,
    required BoardPoint to,
    required PieceType player,
    required CaptureType type,
    required FanoronaVariant variant,
  }) {
    final opponent = (player == PieceType.white) ? PieceType.black : PieceType.white;
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    final captured = <BoardPoint>[];
    final cols = variant.cols;
    final rows = variant.rows;

    if (type == CaptureType.approach) {
      int cx = to.x + dx;
      int cy = to.y + dy;
      while (cx >= 0 && cx < cols && cy >= 0 && cy < rows) {
        final target = BoardPoint(cx, cy);
        if (board[target] == opponent) {
          captured.add(target);
          cx += dx;
          cy += dy;
        } else {
          break;
        }
      }
    } else if (type == CaptureType.withdrawal) {
      int cx = from.x - dx;
      int cy = from.y - dy;
      while (cx >= 0 && cx < cols && cy >= 0 && cy < rows) {
        final target = BoardPoint(cx, cy);
        if (board[target] == opponent) {
          captured.add(target);
          cx -= dx;
          cy -= dy;
        } else {
          break;
        }
      }
    }

    return captured;
  }

  // Yasal hamleleri hesaplar
  static List<Move> getLegalMoves({
    required Map<BoardPoint, PieceType> board,
    required PieceType player,
    required FanoronaVariant variant,
    BoardPoint? chainedPiece,
    List<BoardPoint>? visitedInTurn,
    BoardPoint? lastDirectionVector,
  }) {
    final captureMoves = <Move>[];
    final paikaMoves = <Move>[];

    final candidatePoints = chainedPiece != null
        ? [chainedPiece]
        : board.keys.where((pt) => board[pt] == player).toList();

    for (final from in candidatePoints) {
      if (board[from] != player) continue;
      for (final to in getValidNeighbors(from, variant)) {
        if ((board[to] ?? PieceType.none) != PieceType.none) continue;

        if (visitedInTurn != null && visitedInTurn.contains(to)) continue;

        final dirX = to.x - from.x;
        final dirY = to.y - from.y;

        if (lastDirectionVector != null &&
            lastDirectionVector.x == dirX &&
            lastDirectionVector.y == dirY) {
          continue;
        }

        final approachCaps = getCaptures(
          board: board,
          from: from,
          to: to,
          player: player,
          type: CaptureType.approach,
          variant: variant,
        );
        if (approachCaps.isNotEmpty) {
          captureMoves.add(Move(
            from: from,
            to: to,
            captureType: CaptureType.approach,
            capturedPieces: approachCaps,
          ));
        }

        final withdrawCaps = getCaptures(
          board: board,
          from: from,
          to: to,
          player: player,
          type: CaptureType.withdrawal,
          variant: variant,
        );
        if (withdrawCaps.isNotEmpty) {
          captureMoves.add(Move(
            from: from,
            to: to,
            captureType: CaptureType.withdrawal,
            capturedPieces: withdrawCaps,
          ));
        }

        if (chainedPiece == null && approachCaps.isEmpty && withdrawCaps.isEmpty) {
          paikaMoves.add(Move(from: from, to: to, captureType: CaptureType.none));
        }
      }
    }

    if (captureMoves.isNotEmpty) {
      return captureMoves;
    }
    return (chainedPiece == null) ? paikaMoves : [];
  }
}
