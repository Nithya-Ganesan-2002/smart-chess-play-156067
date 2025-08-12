import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/chess_game_controller.dart';
import '../widgets/chess_board_widget.dart';

/// PUBLIC_INTERFACE
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChessGameController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Chess'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Board area
            const Expanded(
              flex: 6,
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: ChessBoardWidget(),
                    ),
                  ),
                ),
              ),
            ),
            // Controls area
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ControlsBar(controller: controller),
                    const SizedBox(height: 8),
                    _ResultBanner(controller: controller),
                    const SizedBox(height: 8),
                    _MoveHistoryPanel(controller: controller),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlsBar extends StatelessWidget {
  const _ControlsBar({required this.controller});

  final ChessGameController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _DifficultySelector(controller: controller),
        ElevatedButton.icon(
          onPressed: controller.isAIMoving ? null : () => controller.newGame(),
          icon: const Icon(Icons.refresh),
          label: const Text('New Game'),
        ),
        OutlinedButton.icon(
          onPressed: controller.isAIMoving ? null : controller.undo,
          icon: const Icon(Icons.undo),
          label: const Text('Undo'),
        ),
        OutlinedButton.icon(
          onPressed: controller.isAIMoving ? null : controller.redo,
          icon: const Icon(Icons.redo),
          label: const Text('Redo'),
        ),
        TextButton.icon(
          onPressed: controller.isAIMoving ? null : controller.aiMoveNow,
          icon: const Icon(Icons.smart_toy),
          label: const Text('AI Move'),
        ),
        if (controller.isAIMoving)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
          ),
      ],
    );
  }
}

class _DifficultySelector extends StatelessWidget {
  const _DifficultySelector({required this.controller});
  final ChessGameController controller;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<AIDifficulty>(
      value: controller.difficulty,
      onChanged: (v) {
        if (v != null) controller.setDifficulty(v);
      },
      items: const [
        DropdownMenuItem(
          value: AIDifficulty.easy,
          child: Text('Easy'),
        ),
        DropdownMenuItem(
          value: AIDifficulty.medium,
          child: Text('Medium'),
        ),
        DropdownMenuItem(
          value: AIDifficulty.hard,
          child: Text('Hard'),
        ),
      ],
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.controller});
  final ChessGameController controller;

  @override
  Widget build(BuildContext context) {
    final outcome = controller.outcome;
    if (outcome == null) return const SizedBox.shrink();

    return Card(
      color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.emoji_events, color: Colors.black87),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                outcome,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => controller.newGame(),
              child: const Text('Play again'),
            )
          ],
        ),
      ),
    );
  }
}

class _MoveHistoryPanel extends StatelessWidget {
  const _MoveHistoryPanel({required this.controller});
  final ChessGameController controller;

  @override
  Widget build(BuildContext context) {
    final pairs = controller.movePairs;

    return ExpansionTile(
      title: const Text('Move history'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        if (pairs.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('No moves yet.'),
          ),
        if (pairs.isNotEmpty)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (_, idx) {
              final turn = idx + 1;
              final pair = pairs[idx];
              final white = pair[0];
              final black = pair.length > 1 ? pair[1] : null;

              return Row(
                children: [
                  SizedBox(width: 28, child: Text('$turn.')),
                  Expanded(child: Text(white.san)),
                  Expanded(child: Text(black?.san ?? '')),
                ],
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 12),
            itemCount: pairs.length,
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}
