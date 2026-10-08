import 'package:flutter/material.dart';

enum GameThemeId {
  obsidian,
  wood,
  emerald,
}

class GameThemeData {
  final GameThemeId id;
  final String name;
  final String description;
  final Color boardBackgroundColor;
  final Color boardBorderColor;
  final Color gridLineColor;
  final Color activeHighlightColor;
  final Color captureGlowColor;

  // Taş renkleri ve degradeleri
  final List<Color> whitePieceGradient;
  final List<Color> blackPieceGradient;
  final Color whitePieceBorder;
  final Color blackPieceBorder;

  const GameThemeData({
    required this.id,
    required this.name,
    required this.description,
    required this.boardBackgroundColor,
    required this.boardBorderColor,
    required this.gridLineColor,
    required this.activeHighlightColor,
    required this.captureGlowColor,
    required this.whitePieceGradient,
    required this.blackPieceGradient,
    required this.whitePieceBorder,
    required this.blackPieceBorder,
  });

  static final List<GameThemeData> allThemes = [
    // 1. Obsidian Night
    GameThemeData(
      id: GameThemeId.obsidian,
      name: 'Obsidian Night',
      description: 'Futuristic obsidian & polished pearl aesthetic.',
      boardBackgroundColor: const Color(0xFF16181D),
      boardBorderColor: const Color(0xFF2C3240),
      gridLineColor: const Color(0xFF4A5568),
      activeHighlightColor: const Color(0xFF00E5FF),
      captureGlowColor: const Color(0xFFFF5252),
      whitePieceGradient: [
        Colors.white,
        const Color(0xFFE2E8F0),
        const Color(0xFFCBD5E1),
      ],
      blackPieceGradient: [
        const Color(0xFF475569),
        const Color(0xFF1E293B),
        const Color(0xFF0F172A),
      ],
      whitePieceBorder: const Color(0xFF94A3B8),
      blackPieceBorder: const Color(0xFF38BDF8),
    ),

    // 2. Madagascar Wood (Antik Ahşap)
    GameThemeData(
      id: GameThemeId.wood,
      name: 'Madagascar Wood',
      description: 'Traditional carved rosewood & ebony craft.',
      boardBackgroundColor: const Color(0xFF3E2723),
      boardBorderColor: const Color(0xFF5D4037),
      gridLineColor: const Color(0xFF8D6E63),
      activeHighlightColor: const Color(0xFFFFB300),
      captureGlowColor: const Color(0xFFFF3D00),
      whitePieceGradient: [
        const Color(0xFFFFF8E1),
        const Color(0xFFFFECB3),
        const Color(0xFFFFE082),
      ],
      blackPieceGradient: [
        const Color(0xFF3E2723),
        const Color(0xFF271A15),
        const Color(0xFF150D0A),
      ],
      whitePieceBorder: const Color(0xFFFFCA28),
      blackPieceBorder: const Color(0xFF6D4C41),
    ),

    // 3. Royal Emerald & Gold (Zümrüt & Altın)
    GameThemeData(
      id: GameThemeId.emerald,
      name: 'Royal Emerald',
      description: 'Velvet green table with regal gold trim.',
      boardBackgroundColor: const Color(0xFF0A261C),
      boardBorderColor: const Color(0xFF1B4D3E),
      gridLineColor: const Color(0xFFD4AF37).withAlpha(140),
      activeHighlightColor: const Color(0xFFFFD700),
      captureGlowColor: const Color(0xFFFF1744),
      whitePieceGradient: [
        const Color(0xFFFFFFFF),
        const Color(0xFFF0FDF4),
        const Color(0xFFDCFCE7),
      ],
      blackPieceGradient: [
        const Color(0xFF064E3B),
        const Color(0xFF022C22),
        const Color(0xFF011A14),
      ],
      whitePieceBorder: const Color(0xFFFFD700),
      blackPieceBorder: const Color(0xFF10B981),
    ),
  ];
}