enum PieceType { none, white, black }

enum CaptureType { none, approach, withdrawal }

enum FanoronaVariant {
  telo, // 3x3
  dimy, // 5x5
  tsivy, // 9x5
}

enum BotDifficulty {
  easy('Easy', 'Plays casually with occasional mistakes.'),
  medium('Medium', 'Standard tactical play with 2-ply search.'),
  hard('Hard', 'Strategic board control and 3-ply analysis.'),
  expert('Expert', 'Deep positional awareness and counter-attacks.'),
  master('Master', 'Uncompromising depth, full chains, and optimal play.');

  final String displayName;
  final String description;

  const BotDifficulty(this.displayName, this.description);
}

extension FanoronaVariantDetails on FanoronaVariant {
  String get displayName {
    switch (this) {
      case FanoronaVariant.telo:
        return 'Fanorona-Telo (3x3)';
      case FanoronaVariant.dimy:
        return 'Fanorona-Dimy (5x5)';
      case FanoronaVariant.tsivy:
        return 'Fanorona-Tsivy (9x5)';
    }
  }

  String get shortName {
    switch (this) {
      case FanoronaVariant.telo:
        return '3x3 Telo';
      case FanoronaVariant.dimy:
        return '5x5 Dimy';
      case FanoronaVariant.tsivy:
        return '9x5 Tsivy';
    }
  }

  int get cols {
    switch (this) {
      case FanoronaVariant.telo:
        return 3;
      case FanoronaVariant.dimy:
        return 5;
      case FanoronaVariant.tsivy:
        return 9;
    }
  }

  int get rows {
    switch (this) {
      case FanoronaVariant.telo:
        return 3;
      case FanoronaVariant.dimy:
        return 5;
      case FanoronaVariant.tsivy:
        return 5;
    }
  }

  double get aspectRatio => (cols - 1) / (rows - 1);
}

class BoardPoint {
  final int x;
  final int y;

  const BoardPoint(this.x, this.y);

  bool get isStrongIntersection => (x + y) % 2 == 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardPoint &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;

  @override
  String toString() => '($x, $y)';
}

class Move {
  final BoardPoint from;
  final BoardPoint to;
  final CaptureType captureType;
  final List<BoardPoint> capturedPieces;

  Move({
    required this.from,
    required this.to,
    this.captureType = CaptureType.none,
    this.capturedPieces = const [],
  });

  bool get isCapture =>
      captureType != CaptureType.none && capturedPieces.isNotEmpty;

  int get dx => to.x - from.x;
  int get dy => to.y - from.y;
}