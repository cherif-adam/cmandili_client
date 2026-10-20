import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../data/models/order_customization.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import 'customization_type_selector.dart';
import 'instructions_sheet_header.dart';
import 'instructions_text_input.dart';
import 'save_instructions_button.dart';
import 'voice_recorder_section.dart';

/// Bottom sheet for a cart item's special instructions, top to bottom:
/// InstructionsSheetHeader, CustomizationTypeSelector (text / voice),
/// InstructionsTextInput or VoiceRecorderSection, SaveInstructionsButton.
///
/// Recording / playback / saving logic stays in the State below.
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
            content: Text(AppLocalizations.of(context)!.voiceRecordStartFailed('$e')),
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
            content: Text(AppLocalizations.of(context)!.voiceRecordStopFailed('$e')),
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
            content: Text(AppLocalizations.of(context)!.voicePlayFailed('$e')),
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
              InstructionsSheetHeader(screenWidth: screenWidth),
              SizedBox(height: screenHeight * 0.02),

              CustomizationTypeSelector(
                selectedType: _selectedType,
                onChanged: (type) => setState(() => _selectedType = type),
                screenWidth: screenWidth,
              ),
              SizedBox(height: screenHeight * 0.03),

              // Content: text box or voice recorder
              if (_selectedType == CustomizationType.text)
                InstructionsTextInput(
                  controller: _textController,
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                )
              else
                VoiceRecorderSection(
                  hasRecording: _audioPath != null,
                  isRecording: _isRecording,
                  isPlaying: _isPlaying,
                  durationLabel: _formatDuration(_recordingDuration),
                  pulse: _pulseController,
                  onPlay: _playAudio,
                  onDelete: _deleteRecording,
                  onRecordTap: _isRecording ? _stopRecording : _startRecording,
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                ),
              SizedBox(height: screenHeight * 0.03),

              SaveInstructionsButton(
                onPressed: _save,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
