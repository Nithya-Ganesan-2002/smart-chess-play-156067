import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/chess_game_controller.dart';

const _lightSquare = Color(0xFFEBEDF2);
const _darkSquare = Color(0xFFB7C1D1);

String _pieceGlyph(Map<String, dynamic> piece) {
  final color = piece['color']?.toString();
  final type = piece['type']?.toString();
  switch ('$color$type') {
    case 'wk':
      return '♔';
    case 'wq':
      return '♕';
    case 'wr':
      return '♖';
    case 'wb':
      return '♗';
    case 'wn':
      return '♘';
    case 'wp':
      return '♙';
    case 'bk':
      return '♚';
    case 'bq':
      return '♛';
    case 'br':
      return '♜';
    case 'bb':
      return '♝';
    case 'bn':
      return '♞';
    case 'bp':
      return '♟';
    default:
      return '';
  }
}

/// PUBLIC_INTERFACE
/// A simple, responsive 8x8 chessboard widget with tap-to-move interaction and
/// legal move highlighting. It draws Unicode chess piece glyphs for a clean,
/// minimal look matching the light theme.
class ChessBoardWidget extends StatefulWidget {
  const ChessBoardWidget({super.key});

  @override
  State<ChessBoardWidget> createState() => _ChessBoardWidgetState();
}

class _ChessBoardWidgetState extends State<ChessBoardWidget> {
  String? _selectedSquare;
  List<String> _legalTargets = const [];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChessGameController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        final boardSize = size; // keep 1:1
        return Center(
          child: SizedBox(
            width: boardSize,
            height: boardSize,
            child: _buildGrid(controller),
          ),
        );
      },
    );
  }

  Widget _buildGrid(ChessGameController controller) {
    final tiles = <Widget>[];
    const files = 'abcdefgh';

    for (int rank = 8; rank >= 1; rank--) {
      for (int file = 0; file < 8; file++) {
        final isDark = ((rank + file) % 2) == 1;
        final squareName = '${files[file]}$rank';
        final piece = controller.pieceAt(squareName);

        final isSelected = _selectedSquare == squareName;
        final canMoveHere = _legalTargets.contains(squareName);
        final squareColor = isSelected
            ? Colors.amber.withValues(alpha: 0.75)
            : canMoveHere
                ? Colors.amber.withValues(alpha: 0.35)
                : (isDark ? _darkSquare : _lightSquare);

        tiles.add(GestureDetector(
          onTap: () => _onTapSquare(controller, squareName, piece != null),
          child: Container(
            decoration: BoxDecoration(
              color: squareColor,
            ),
            child: Center(
              child: piece == null
                  ? const SizedBox.shrink()
                  : Text(
                      _pieceGlyph(piece),
                      style: TextStyle(
                        fontSize: 28,
                        color: piece['color'] == 'w' ? Colors.black87 : const Color(0xFF222222),
                      ),
                    ),
            ),
          ),
        ));
      }
    }

    return GridView.count(
      crossAxisCount: 8,
      physics: const NeverScrollableScrollPhysics(),
      children: tiles,
    );
  }

  void _onTapSquare(ChessGameController game, String square, bool hasPiece) {
    // If selecting source square
    if (_selectedSquare == null) {
      if (!hasPiece) return;
      // Ensure piece belongs to side to move
      final piece = game.pieceAt(square);
      if (piece == null) return;
      final isWhitesTurn = game.turn == 'w';
      if (isWhitesTurn && piece['color'] != 'w') return;
      if (!isWhitesTurn && piece['color'] != 'b') return;

      final moves = game.legalMovesFrom(square);
      setState(() {
        _selectedSquare = square;
        _legalTargets = moves.map((m) => (m['to'] ?? '').toString()).toList();
      });
      return;
    }

    // If tapping same square -> cancel selection
    if (_selectedSquare == square) {
      setState(() {
        _selectedSquare = null;
        _legalTargets = const [];
      });
      return;
    }

    // Attempt move
    final moved = game.makePlayerMove(_selectedSquare!, square);
    setState(() {
      // Clear selection regardless of success to simplify UX
      _selectedSquare = null;
      _legalTargets = const [];
    });

    // If move failed and target has a piece, start a new selection
    if (!moved && hasPiece) {
      final piece = game.pieceAt(square);
      if (piece != null) {
        final moves = game.legalMovesFrom(square);
        setState(() {
          _selectedSquare = square;
          _legalTargets = moves.map((m) => (m['to'] ?? '').toString()).toList();
        });
      }
    }
  }
}
