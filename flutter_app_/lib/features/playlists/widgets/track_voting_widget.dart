import 'package:flutter/material.dart';
import '../../../core/models/index.dart';

/// Voting buttons widget for a track
/// Shows upvote/downvote buttons with vote counts
class TrackVotingWidget extends StatelessWidget {
  final String trackId;
  final int upvotes;
  final int downvotes;
  final VoteType? userVote;
  final bool isCurrentTrack;
  final bool isEnabled;
  final Function(VoteType)? onVote;
  final VoidCallback? onRemoveVote;

  const TrackVotingWidget({
    super.key,
    required this.trackId,
    required this.upvotes,
    required this.downvotes,
    this.userVote,
    this.isCurrentTrack = false,
    this.isEnabled = true,
    this.onVote,
    this.onRemoveVote,
  });

  int get score => upvotes - downvotes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Disable voting for current track
    final canVote = isEnabled && !isCurrentTrack;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Upvote button
        _VoteButton(
          icon: Icons.thumb_up_outlined,
          activeIcon: Icons.thumb_up,
          count: upvotes,
          isActive: userVote == VoteType.upvote,
          isEnabled: canVote,
          color: Colors.green,
          onTap: canVote ? () {
            // Always call onVote - backend handles toggle behavior
            onVote?.call(VoteType.upvote);
          } : null,
        ),
        
        // Score display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            score >= 0 ? '+$score' : '$score',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: score > 0 
                  ? Colors.green 
                  : score < 0 
                      ? Colors.red 
                      : theme.colorScheme.onSurface,
            ),
          ),
        ),
        
        // Downvote button
        _VoteButton(
          icon: Icons.thumb_down_outlined,
          activeIcon: Icons.thumb_down,
          count: downvotes,
          isActive: userVote == VoteType.downvote,
          isEnabled: canVote,
          color: Colors.red,
          onTap: canVote ? () {
            // Always call onVote - backend handles toggle behavior
            onVote?.call(VoteType.downvote);
          } : null,
        ),
        
        // Current track indicator
        if (isCurrentTrack) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'PLAYING',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _VoteButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final int count;
  final bool isActive;
  final bool isEnabled;
  final Color color;
  final VoidCallback? onTap;

  const _VoteButton({
    required this.icon,
    required this.activeIcon,
    required this.count,
    required this.isActive,
    required this.isEnabled,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = isActive ? color : theme.colorScheme.onSurface.withOpacity(0.6);
    
    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isEnabled ? buttonColor : buttonColor.withOpacity(0.4),
              size: 20,
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isEnabled ? buttonColor : buttonColor.withOpacity(0.4),
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact voting widget for list items
class CompactTrackVotingWidget extends StatelessWidget {
  final int score;
  final VoteType? userVote;
  final bool isCurrentTrack;
  final bool isEnabled;
  final Function(VoteType)? onVote;
  final VoidCallback? onRemoveVote;

  const CompactTrackVotingWidget({
    super.key,
    required this.score,
    this.userVote,
    this.isCurrentTrack = false,
    this.isEnabled = true,
    this.onVote,
    this.onRemoveVote,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canVote = isEnabled && !isCurrentTrack;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Upvote
        IconButton(
          icon: Icon(
            userVote == VoteType.upvote ? Icons.arrow_upward : Icons.arrow_upward_outlined,
            size: 16,
          ),
          color: userVote == VoteType.upvote ? Colors.green : null,
          onPressed: canVote ? () {
            // Always call onVote - backend handles toggle behavior
            onVote?.call(VoteType.upvote);
          } : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          iconSize: 16,
        ),
        
        // Score
        SizedBox(
          width: 24,
          child: Text(
            '$score',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: score > 0 
                  ? Colors.green 
                  : score < 0 
                      ? Colors.red 
                      : null,
            ),
          ),
        ),
        
        // Downvote
        IconButton(
          icon: Icon(
            userVote == VoteType.downvote ? Icons.arrow_downward : Icons.arrow_downward_outlined,
            size: 16,
          ),
          color: userVote == VoteType.downvote ? Colors.red : null,
          onPressed: canVote ? () {
            // Always call onVote - backend handles toggle behavior
            onVote?.call(VoteType.downvote);
          } : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          iconSize: 16,
        ),
      ],
    );
  }
}
