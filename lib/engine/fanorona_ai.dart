import 'dart:math';
import '../models/game_models.dart';
import 'fanorona_engine.dart';

class FanoronaAI {
  static final Random _rng = Random();

  static Move? getMove({
    required Map<BoardPoint, PieceType> board,
    required PieceType botPlayer,
    required BotDifficulty difficulty,
    required FanoronaVariant variant,
    BoardPoint? chainedPiece,
    List<BoardPoint>? visitedInTurn,
    BoardPoint? lastDirectionVector,
  }) {
    final legalMoves = FanoronaEngine.getLegalMoves(
      board: board,
      player: botPlayer,
      variant: variant,
      chainedPiece: chainedPiece,
      visitedInTurn: visitedInTurn,
      lastDirectionVector: lastDirectionVector,
    );

    if (legalMoves.isEmpty) return null;

    // ==========================================
    // 1. EASY (Acemi)
    // ==========================================
    if (difficulty == BotDifficulty.easy) {
      // %65 ihtimalle tamamen rastgele bir yasal hamle seçer
      if (_rng.nextDouble() < 0.65) {
        return legalMoves[_rng.nextInt(legalMoves.length)];
      }
      // Kalan %35'te sadece anlık en çok taş yiyeni alır (derinlik 1)
      legalMoves.sort((a, b) => b.capturedPieces.length.compareTo(a.capturedPieces.length));
      return legalMoves.first;
    }

    // ==========================================
    // 2. MEDIUM (Orta)
    // ==========================================
    if (difficulty == BotDifficulty.medium) {
      if (_rng.nextDouble() < 0.25) {
        // Arada bir taktiksel hata payı
        return legalMoves[_rng.nextInt(legalMoves.length)];
      }
      return _findBestMoveMinimax(
        board: board,
        legalMoves: legalMoves,
        visitedInTurn: visitedInTurn,
        botPlayer: botPlayer,
        variant: variant,
        maxDepth: 2,
        useAdvancedHeuristics: false,
      );
    }

    // ==========================================
    // 3. HARD (Zor)
    // ==========================================
    if (difficulty == BotDifficulty.hard) {
      return _findBestMoveMinimax(
        board: board,
        legalMoves: legalMoves,
        visitedInTurn: visitedInTurn,
        botPlayer: botPlayer,
        variant: variant,
        maxDepth: 3,
        useAdvancedHeuristics: true,
      );
    }

    // ==========================================
    // 4. EXPERT (Uzman)
    // ==========================================
    if (difficulty == BotDifficulty.expert) {
      return _findBestMoveMinimax(
        board: board,
        legalMoves: legalMoves,
        visitedInTurn: visitedInTurn,
        botPlayer: botPlayer,
        variant: variant,
        maxDepth: 4,
        useAdvancedHeuristics: true,
      );
    }

    // ==========================================
    // 5. MASTER (Yenilmez / En Güçlü)
    // ==========================================
    // 9x5 varyantında dallanma çok yüksek olduğu için derinlik 4, 3x3 ve 5x5'te 5 derinlik
    final int masterDepth = (variant == FanoronaVariant.tsivy) ? 4 : 5;
    return _findBestMoveMinimax(
      board: board,
      legalMoves: legalMoves,
      visitedInTurn: visitedInTurn,
      botPlayer: botPlayer,
      variant: variant,
      maxDepth: masterDepth,
      useAdvancedHeuristics: true,
      isMasterMode: true,
    );
  }

  static Move _findBestMoveMinimax({
    required Map<BoardPoint, PieceType> board,
    required List<Move> legalMoves,
    required PieceType botPlayer,
    required FanoronaVariant variant,
    required int maxDepth,
    required bool useAdvancedHeuristics,
    bool isMasterMode = false,
    List<BoardPoint>? visitedInTurn,
  }) {
    final opponent = (botPlayer == PieceType.white) ? PieceType.black : PieceType.white;
    Move bestMove = legalMoves.first;
    int bestScore = -99999999;
    int alpha = -99999999;
    const int beta = 99999999;

    // Hamle Sıralaması (Move Ordering): Yeme hamlelerini önce değerlendirerek budamayı (pruning) hızlandırıyoruz
    legalMoves.sort((a, b) => b.capturedPieces.length.compareTo(a.capturedPieces.length));

    for (final move in legalMoves) {
      final simBoard = Map<BoardPoint, PieceType>.from(board);
      _executeFullTurnSim(simBoard, move, botPlayer, variant, visitedInTurn);

      final score = _alphaBeta(
        board: simBoard,
        depth: maxDepth - 1,
        alpha: alpha,
        beta: beta,
        isMaximizing: false,
        botPlayer: botPlayer,
        opponent: opponent,
        variant: variant,
        useAdvancedHeuristics: useAdvancedHeuristics,
        isMasterMode: isMasterMode,
      );

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
      alpha = max(alpha, bestScore);
    }

    return bestMove;
  }

  static int _alphaBeta({
    required Map<BoardPoint, PieceType> board,
    required int depth,
    required int alpha,
    required int beta,
    required bool isMaximizing,
    required PieceType botPlayer,
    required PieceType opponent,
    required FanoronaVariant variant,
    required bool useAdvancedHeuristics,
    required bool isMasterMode,
  }) {
    final currentPlayer = isMaximizing ? botPlayer : opponent;
    final moves = FanoronaEngine.getLegalMoves(
      board: board,
      player: currentPlayer,
      variant: variant,
    );

    // Terminal durum: Taşlar bitti mi veya geçerli hamle kalmadı mı?
    if (moves.isEmpty) {
      return isMaximizing ? -5000000 : 5000000;
    }

    if (depth <= 0) {
      // Master modunda taktiksel taş yeme devam ediyorsa 1 adım daha uzat (Quiescence)
      if (isMasterMode && moves.any((m) => m.isCapture)) {
        return _quiescenceSearch(
          board: board,
          alpha: alpha,
          beta: beta,
          isMaximizing: isMaximizing,
          botPlayer: botPlayer,
          opponent: opponent,
          variant: variant,
          depthLimit: 2,
        );
      }
      return _evaluateState(board, botPlayer, opponent, variant, useAdvancedHeuristics);
    }

    // Move Ordering
    moves.sort((a, b) => b.capturedPieces.length.compareTo(a.capturedPieces.length));

    if (isMaximizing) {
      int maxScore = -99999999;
      for (final move in moves) {
        final simBoard = Map<BoardPoint, PieceType>.from(board);
        _executeFullTurnSim(simBoard, move, botPlayer, variant);

        final eval = _alphaBeta(
          board: simBoard,
          depth: depth - 1,
          alpha: alpha,
          beta: beta,
          isMaximizing: false,
          botPlayer: botPlayer,
          opponent: opponent,
          variant: variant,
          useAdvancedHeuristics: useAdvancedHeuristics,
          isMasterMode: isMasterMode,
        );

        maxScore = max(maxScore, eval);
        alpha = max(alpha, eval);
        if (beta <= alpha) break; // Beta cut-off
      }
      return maxScore;
    } else {
      int minScore = 99999999;
      for (final move in moves) {
        final simBoard = Map<BoardPoint, PieceType>.from(board);
        _executeFullTurnSim(simBoard, move, opponent, variant);

        final eval = _alphaBeta(
          board: simBoard,
          depth: depth - 1,
          alpha: alpha,
          beta: beta,
          isMaximizing: true,
          botPlayer: botPlayer,
          opponent: opponent,
          variant: variant,
          useAdvancedHeuristics: useAdvancedHeuristics,
          isMasterMode: isMasterMode,
        );

        minScore = min(minScore, eval);
        beta = min(beta, eval);
        if (beta <= alpha) break; // Alpha cut-off
      }
      return minScore;
    }
  }

  // Quiescence Search: Taktiksel takas bitene kadar sadece yeme hamlelerini arar
  static int _quiescenceSearch({
    required Map<BoardPoint, PieceType> board,
    required int alpha,
    required int beta,
    required bool isMaximizing,
    required PieceType botPlayer,
    required PieceType opponent,
    required FanoronaVariant variant,
    required int depthLimit,
  }) {
    final standPat = _evaluateState(board, botPlayer, opponent, variant, true);
    if (depthLimit <= 0) return standPat;

    if (isMaximizing) {
      if (standPat >= beta) return beta;
      alpha = max(alpha, standPat);

      final captureMoves = FanoronaEngine.getLegalMoves(
        board: board,
        player: botPlayer,
        variant: variant,
      ).where((m) => m.isCapture).toList();

      for (final move in captureMoves) {
        final simBoard = Map<BoardPoint, PieceType>.from(board);
        _executeFullTurnSim(simBoard, move, botPlayer, variant);

        final score = _quiescenceSearch(
          board: simBoard,
          alpha: alpha,
          beta: beta,
          isMaximizing: false,
          botPlayer: botPlayer,
          opponent: opponent,
          variant: variant,
          depthLimit: depthLimit - 1,
        );

        alpha = max(alpha, score);
        if (beta <= alpha) break;
      }
      return alpha;
    } else {
      if (standPat <= alpha) return alpha;
      beta = min(beta, standPat);

      final captureMoves = FanoronaEngine.getLegalMoves(
        board: board,
        player: opponent,
        variant: variant,
      ).where((m) => m.isCapture).toList();

      for (final move in captureMoves) {
        final simBoard = Map<BoardPoint, PieceType>.from(board);
        _executeFullTurnSim(simBoard, move, opponent, variant);

        final score = _quiescenceSearch(
          board: simBoard,
          alpha: alpha,
          beta: beta,
          isMaximizing: true,
          botPlayer: botPlayer,
          opponent: opponent,
          variant: variant,
          depthLimit: depthLimit - 1,
        );

        beta = min(beta, score);
        if (beta <= alpha) break;
      }
      return beta;
    }
  }

  // Zincirleme dahil turun tamamını greedy simüle eden fonksiyon
  static void _executeFullTurnSim(
    Map<BoardPoint, PieceType> board,
    Move firstMove,
    PieceType player,
    FanoronaVariant variant, [
    List<BoardPoint>? visitedInTurn,
  ]) {
    _applyMove(board, firstMove, player);

    if (!firstMove.isCapture) return;

    // Zincirleme devamı
    BoardPoint currentPos = firstMove.to;
    final visited = <BoardPoint>[...?visitedInTurn, firstMove.from];
    BoardPoint lastDir = BoardPoint(firstMove.dx, firstMove.dy);

    while (true) {
      final chainMoves = FanoronaEngine.getLegalMoves(
        board: board,
        player: player,
        variant: variant,
        chainedPiece: currentPos,
        visitedInTurn: visited,
        lastDirectionVector: lastDir,
      ).where((m) => m.isCapture).toList();

      if (chainMoves.isEmpty) break;

      // En çok taş yiyen zincir adımını uygula (Greedy Chain)
      chainMoves.sort((a, b) => b.capturedPieces.length.compareTo(a.capturedPieces.length));
      final nextMove = chainMoves.first;

      _applyMove(board, nextMove, player);
      visited.add(nextMove.from);
      lastDir = BoardPoint(nextMove.dx, nextMove.dy);
      currentPos = nextMove.to;
    }
  }

  static void _applyMove(Map<BoardPoint, PieceType> board, Move move, PieceType player) {
    board[move.from] = PieceType.none;
    board[move.to] = player;
    for (final cap in move.capturedPieces) {
      board[cap] = PieceType.none;
    }
  }

  // Gelişmiş Fanorona Tahta Değerlendirme Motoru (Heuristic)
  static int _evaluateState(
    Map<BoardPoint, PieceType> board,
    PieceType botPlayer,
    PieceType opponent,
    FanoronaVariant variant,
    bool useAdvanced,
  ) {
    int botStones = 0;
    int oppStones = 0;
    int botPositionalBonus = 0;
    int oppPositionalBonus = 0;

    final centerX = (variant.cols - 1) / 2.0;
    final centerY = (variant.rows - 1) / 2.0;

    board.forEach((pt, piece) {
      if (piece == botPlayer) {
        botStones++;
        if (useAdvanced) {
          // 1. Güçlü Kesişim Düğümleri: 8 yönlü hareket avantajı
          if (pt.isStrongIntersection) botPositionalBonus += 35;

          // 2. Merkez Kontrolü: Merkeze yakın taşlar tahtanın her iki kanadına hızlı ulaşır
          final dist = (pt.x - centerX).abs() + (pt.y - centerY).abs();
          botPositionalBonus += (10 - dist.toInt()) * 4;
        }
      } else if (piece == opponent) {
        oppStones++;
        if (useAdvanced) {
          if (pt.isStrongIntersection) oppPositionalBonus += 35;
          final dist = (pt.x - centerX).abs() + (pt.y - centerY).abs();
          oppPositionalBonus += (10 - dist.toInt()) * 4;
        }
      }
    });

    if (oppStones == 0) return 1000000;
    if (botStones == 0) return -1000000;

    int totalScore = (botStones - oppStones) * 1000;

    if (useAdvanced) {
      totalScore += (botPositionalBonus - oppPositionalBonus);

      // 3. Hareketlilik (Mobility): Rakibin hamle sayısını kısıtlama
      final botMovesCount = FanoronaEngine.getLegalMoves(board: board, player: botPlayer, variant: variant).length;
      final oppMovesCount = FanoronaEngine.getLegalMoves(board: board, player: opponent, variant: variant).length;
      totalScore += (botMovesCount - oppMovesCount) * 15;
    }

    return totalScore;
  }
}
