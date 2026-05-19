import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/order_customization.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

class OrderCustomizationWidget extends StatefulWidget {
  final OrderCustomization? initialCustomization;
  final Function(OrderCustomization?) onSave;

  const OrderCustomizationWidget({
    super.key,
    this.initialCustomization,
    required this.onSave,
  });

  @override
  State<OrderCustomizationWidget> createState() =>
      _OrderCustomizationWidgetState();
}

class _OrderCustomizationWidgetState extends State<OrderCustomizationWidget>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  FlutterSoundRecorder? _audioRecorder;
  FlutterSoundPlayer? _audioPlayer;
  
  CustomizationType _selectedType = CustomizationType.text;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _audioPath;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _audioRecorder = FlutterSoundRecorder();
    _audioPlayer = FlutterSoundPlayer();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    if (widget.initialCustomization != null) {
      _selectedType = widget.initialCustomization!.type;
      if (_selectedType == CustomizationType.text) {
        _textController.text = widget.initialCustomization!.content;
      } else {
        _audioPath = widget.initialCustomization!.content;
        _recordingDuration = widget.initialCustomization!.durationSeconds ?? 0;
      }
    }

    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    await _audioRecorder!.openRecorder();
    await _audioPlayer!.openPlayer();
  }

  @override
  void dispose() {
    _textController.dispose();
    _audioRecorder?.closeRecorder();
    _audioPlayer?.closePlayer();
    _recordingTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<bool> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> _startRecording() async {
    final hasPermission = await _requestMicrophonePermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.microphonePermissionDenied),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/voice_message_${DateTime.now().millisecondsSinceEpoch}.aac';

      await _audioRecorder!.startRecorder(
        toFile: path,
        codec: Codec.aacADTS,
      );

      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
        _audioPath = path;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _recordingDuration++);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start recording: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder!.stopRecorder();
      _recordingTimer?.cancel();
      setState(() => _isRecording = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stop recording: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _playAudio() async {
    if (_audioPath == null) return;

    try {
      if (_isPlaying) {
        await _audioPlayer!.stopPlayer();
        setState(() => _isPlaying = false);
      } else {
        await _audioPlayer!.startPlayer(
          fromURI: _audioPath!,
          whenFinished: () {
            setState(() => _isPlaying = false);
          },
        );
        setState(() => _isPlaying = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play audio: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _deleteRecording() {
    if (_audioPath != null) {
      try {
        File(_audioPath!).deleteSync();
      } catch (e) {
        // Ignore deletion errors
      }
    }
    setState(() {
      _audioPath = null;
      _recordingDuration = 0;
    });
  }

  void _save() {
    OrderCustomization? customization;

    if (_selectedType == CustomizationType.text) {
      if (_textController.text.trim().isNotEmpty) {
        customization = OrderCustomization(
          type: CustomizationType.text,
          content: _textController.text.trim(),
          timestamp: DateTime.now(),
        );
      }
    } else {
      if (_audioPath != null) {
        customization = OrderCustomization(
          type: CustomizationType.voice,
          content: _audioPath!,
          timestamp: DateTime.now(),
          durationSeconds: _recordingDuration,
        );
      }
    }

    widget.onSave(customization);
    Navigator.pop(context);
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(screenWidth * 0.08),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.06),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.specialInstructions,
                    style: TextStyle(
                      fontSize: screenWidth * 0.05,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              
              SizedBox(height: screenHeight * 0.02),

              // Type Selector
              Container(
                padding: EdgeInsets.all(screenWidth * 0.01),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TypeButton(
                        label: AppLocalizations.of(context)!.typeMessage,
                        icon: Icons.edit_outlined,
                        isSelected: _selectedType == CustomizationType.text,
                        onTap: () => setState(() => _selectedType = CustomizationType.text),
                        screenWidth: screenWidth,
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    Expanded(
                      child: _TypeButton(
                        label: AppLocalizations.of(context)!.voiceMessage,
                        icon: Icons.mic_outlined,
                        isSelected: _selectedType == CustomizationType.voice,
                        onTap: () => setState(() => _selectedType = CustomizationType.voice),
                        screenWidth: screenWidth,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: screenHeight * 0.03),

              // Content Area
              if (_selectedType == CustomizationType.text)
                _buildTextInput(screenWidth, screenHeight)
              else
                _buildVoiceRecorder(screenWidth, screenHeight),

              SizedBox(height: screenHeight * 0.03),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: screenHeight * 0.065,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(screenWidth * 0.04),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.save,
                    style: TextStyle(
                      fontSize: screenWidth * 0.042,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextInput(double screenWidth, double screenHeight) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(screenWidth * 0.05),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: screenWidth * 0.025,
            offset: Offset(0, screenHeight * 0.006),
          ),
        ],
      ),
      child: TextField(
        controller: _textController,
        maxLines: 4,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontSize: screenWidth * 0.04,
        ),
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.typeInstructionsHint,
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withOpacity(0.5),
            fontSize: screenWidth * 0.038,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(screenWidth * 0.05),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.all(screenWidth * 0.05),
        ),
      ),
    );
  }

  Widget _buildVoiceRecorder(double screenWidth, double screenHeight) {
    return Column(
      children: [
        if (_audioPath != null && !_isRecording)
          Container(
            padding: EdgeInsets.all(screenWidth * 0.04),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(screenWidth * 0.05),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: screenWidth * 0.025,
                  offset: Offset(0, screenHeight * 0.006),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _playAudio,
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
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
                        _formatDuration(_recordingDuration),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: screenWidth * 0.035,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _deleteRecording,
                  icon: Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                    size: screenWidth * 0.06,
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              GestureDetector(
                onTap: _isRecording ? _stopRecording : _startRecording,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: screenWidth * 0.25,
                      height: screenWidth * 0.25,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording
                            ? AppColors.error
                            : AppColors.primary,
                        boxShadow: _isRecording
                            ? [
                                BoxShadow(
                                  color: AppColors.error.withOpacity(0.4 * _pulseController.value),
                                  blurRadius: 20 + (20 * _pulseController.value),
                                  spreadRadius: 5 * _pulseController.value,
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 20,
                                ),
                              ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: screenWidth * 0.1,
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              Text(
                _isRecording
                    ? _formatDuration(_recordingDuration)
                    : AppLocalizations.of(context)!.tapToRecord,
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  fontWeight: _isRecording ? FontWeight.bold : FontWeight.normal,
                  color: _isRecording
                      ? AppColors.error
                      : AppColors.textSecondary,
                ),
              ),
              if (_isRecording) ...[
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
          ),
      ],
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final double screenWidth;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
          vertical: screenWidth * 0.03,
          horizontal: screenWidth * 0.02,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(screenWidth * 0.025),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).textTheme.bodyLarge?.color,
              size: screenWidth * 0.05,
            ),
            SizedBox(width: screenWidth * 0.02),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: screenWidth * 0.035,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
