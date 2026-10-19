import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';

/// The voice-message part of the instructions sheet:
///   - a recording exists → a card with ▶/⏸, "Message vocal 00:12" and 🗑
///   - otherwise          → the big round mic button (red and pulsing
///                          while recording) with "Appuyez pour enregistrer"
class VoiceRecorderSection extends StatelessWidget {
  final bool hasRecording;
  final bool isRecording;
  final bool isPlaying;

  /// "00:12" — the recorded / recording length.
  final String durationLabel;

  /// Drives the red glow around the mic while recording.
  final Animation<double> pulse;
  final VoidCallback onPlay;
  final VoidCallback onDelete;
  final VoidCallback onRecordTap;
  final double screenWidth;
  final double screenHeight;

  const VoiceRecorderSection({
    super.key,
    required this.hasRecording,
    required this.isRecording,
    required this.isPlaying,
    required this.durationLabel,
    required this.pulse,
    required this.onPlay,
    required this.onDelete,
    required this.onRecordTap,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (hasRecording && !isRecording)
          _RecordedMessageCard(
            isPlaying: isPlaying,
            durationLabel: durationLabel,
            onPlay: onPlay,
            onDelete: onDelete,
            screenWidth: screenWidth,
            screenHeight: screenHeight,
          )
        else
          _RecordButton(
            isRecording: isRecording,
            durationLabel: durationLabel,
            pulse: pulse,
            onTap: onRecordTap,
            screenWidth: screenWidth,
            screenHeight: screenHeight,
          ),
      ],
    );
  }
}

class _RecordedMessageCard extends StatelessWidget {
  final bool isPlaying;
  final String durationLabel;
  final VoidCallback onPlay;
  final VoidCallback onDelete;
  final double screenWidth;
  final double screenHeight;

  const _RecordedMessageCard({
    required this.isPlaying,
    required this.durationLabel,
    required this.onPlay,
    required this.onDelete,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(screenWidth * 0.05),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: screenWidth * 0.025,
            offset: Offset(0, screenHeight * 0.006),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPlay,
            icon: Icon(
              isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: AppColors.primary,
              size: screenWidth * 0.12,
            ),
          ),
          SizedBox(width: screenWidth * 0.03),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.voiceMessage,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: screenWidth * 0.04,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                SizedBox(height: screenHeight * 0.005),
                Text(
                  durationLabel,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: screenWidth * 0.035,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline,
              color: AppColors.error,
              size: screenWidth * 0.06,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  final bool isRecording;
  final String durationLabel;
  final Animation<double> pulse;
  final VoidCallback onTap;
  final double screenWidth;
  final double screenHeight;

  const _RecordButton({
    required this.isRecording,
    required this.durationLabel,
    required this.pulse,
    required this.onTap,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedBuilder(
            animation: pulse,
            builder: (context, child) {
              return Container(
                width: screenWidth * 0.25,
                height: screenWidth * 0.25,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRecording
                      ? AppColors.error
                      : AppColors.primary,
                  boxShadow: isRecording
                      ? [
                          BoxShadow(
                            color: AppColors.error.withValues(alpha: 0.4 * pulse.value),
                            blurRadius: 20 + (20 * pulse.value),
                            spreadRadius: 5 * pulse.value,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                          ),
                        ],
                ),
                child: Icon(
                  isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: screenWidth * 0.1,
                ),
              );
            },
          ),
        ),
        SizedBox(height: screenHeight * 0.02),
        Text(
          isRecording
              ? durationLabel
              : AppLocalizations.of(context)!.tapToRecord,
          style: TextStyle(
            fontSize: screenWidth * 0.04,
            fontWeight: isRecording ? FontWeight.bold : FontWeight.normal,
            color: isRecording
                ? AppColors.error
                : AppColors.textSecondary,
          ),
        ),
        if (isRecording) ...[
          SizedBox(height: screenHeight * 0.01),
          Text(
            AppLocalizations.of(context)!.tapAgainToStop,
            style: TextStyle(
              fontSize: screenWidth * 0.035,
              color: AppColors.textLight,
            ),
          ),
        ],
      ],
    );
  }
}
