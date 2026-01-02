import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:futaba_ai_live/src/data/constants/prompts.dart';

class LiveSessionRepository {
  // ============================================================================
  // Audio Configuration Constants
  // ============================================================================
  // Adjust these values to tune performance vs stability trade-offs
  
  // --- Input (Microphone) Configuration ---
  static const int _inputSampleRate = 16000;  // 16kHz for voice input
  static const int _inputBufferSize = 3200;   // 100ms worth of 16kHz PCM16 (16000 * 2 * 0.1)
  
  // --- Output (AI Voice) Configuration ---
  static const int _outputSampleRate = 24000;  // 24kHz for AI voice output
  
  // Initial buffering threshold before playback starts
  // Higher = more stable but slower response
  // Recommended: 9600 (200ms) to 24000 (500ms)
  static const int _playbackThreshold = 24000;  // 500ms worth of 24kHz PCM16 (maximum stability)
  
  // Packet aggregation threshold during playback
  // Higher = fewer CPU cycles but slightly delayed
  // Recommended: 2400 (50ms) to 4800 (100ms)
  static const int _aggregationThreshold = 4800;  // 100ms worth of 24kHz PCM16 (maximum stability)
  
  // Player internal buffer size
  // Higher = more stable but uses more memory and slower response
  // Recommended: 24000 (0.5s) to 96000 (2s)
  static const int _playerBufferSize = 96000;  // ~2 seconds worth of 24kHz PCM16 (maximum stability)
  
  // Maximum conversation history to include in context
  static const int _maxHistoryMessages = 10;
  
  // ============================================================================
  
  WebSocketChannel? _channel;
  
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  
  StreamSubscription? _recorderSubscription;
  StreamSubscription? _webSocketSubscription;
  bool _isDisconnected = false;

  // Buffer for accumulation using BytesBuilder for efficiency (Mic input)
  final BytesBuilder _audioBuffer = BytesBuilder();

  // Jitter buffer for output (AI voice)
  final BytesBuilder _incomingAudioBuffer = BytesBuilder();
  bool _isBuffering = true;

  Future<void> connect({
    void Function(String text, bool isUser)? onTranscriptionReceived,
    void Function()? onTurnComplete,
    void Function(String expression)? onExpressionChanged,
    void Function(bool isThinking)? onThinkingChanged,
    List<Map<String, dynamic>>? conversationHistory,
  }) async {
    _isDisconnected = false;
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null) {
      throw Exception('GEMINI_API_KEY not found in .env');
    }

    // Request permissions
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Microphone permission denied');
    }

    // Initialize Audio Session
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker | AVAudioSessionCategoryOptions.allowBluetooth,
      avAudioSessionMode: AVAudioSessionMode.voiceChat,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));

    // Open Audio Engine
    await _recorder.openRecorder();
    await _player.openPlayer();

    // Start Player Stream (Output)
    await _startPlayer();

    final uri = Uri.parse(
      'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=$apiKey',
    );

    try {
      debugPrint('Connecting to Gemini Live API...');
      _channel = WebSocketChannel.connect(uri);
      await _channel?.ready;
      debugPrint('WebSocket connected');

      // Send Setup Message
      String systemInstructionText = Prompts.systemInstruction;
      
      // Since native audio models don't support 'contents' in setup, we inject
      // conversation context into the system instruction as a workaround
      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        final contextSummary = StringBuffer('\n\n--- Previous Conversation Context ---\n');
        for (final turn in conversationHistory.take(_maxHistoryMessages)) {
          final role = turn['role'] == 'user' ? 'User' : 'You (Futaba Ai)';
          final text = (turn['parts'] as List).first['text'];
          contextSummary.writeln('$role: $text');
        }
        contextSummary.writeln('--- End of Context ---\n');
        contextSummary.writeln('Continue the conversation naturally based on the above context.');
        systemInstructionText += contextSummary.toString();
      }

      final setupMessage = {
        'setup': {
          'model': 'models/gemini-2.5-flash-native-audio-preview-12-2025',
          'system_instruction': {
            'parts': [
              {
                'text': systemInstructionText
              }
            ]
          },
          'generation_config': {
            'response_modalities': ['AUDIO'],
          },
          'output_audio_transcription': {},
          'input_audio_transcription': {},
        }
      };

      // NOTE: The native audio model (gemini-2.5-flash-native-audio) does not currently
      // support the 'contents' field in the setup message. Adding conversation history
      // causes immediate WebSocket disconnection. Context must be managed differently
      // for this model type.
      // TODO: Investigate alternative approaches for context preservation with native audio
      
      // if (conversationHistory != null && conversationHistory.isNotEmpty) {
      //   setupMessage['setup']!['contents'] = conversationHistory;
      // }
      
      debugPrint('Sending setup message...');
      _channel?.sink.add(jsonEncode(setupMessage));

      // Start Recorder (Input)
      final recordingStream = StreamController<Uint8List>();
      _audioBuffer.clear();
      
      _recorderSubscription = recordingStream.stream.listen((data) {
        if (_channel == null || _isDisconnected) return;
        
        _audioBuffer.add(data);

        if (_audioBuffer.length >= _inputBufferSize) {
           final chunkToSend = _audioBuffer.takeBytes();
           final base64Audio = base64Encode(chunkToSend);
            
            final audioMessage = {
              'realtime_input': {
                'media_chunks': [
                  {
                    'mime_type': 'audio/pcm;rate=$_inputSampleRate',
                    'data': base64Audio,
                  }
                ]
              }
            };
            try {
                if (!_isDisconnected) {
                  _channel!.sink.add(jsonEncode(audioMessage));
                }
            } catch(e) {
                debugPrint('Error sending audio chunk: $e');
            }
        }
      });

      await _recorder.startRecorder(
        toStream: recordingStream.sink,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: _inputSampleRate,
        audioSource: AudioSource.voice_communication, // Hardware AEC on Android
      );
      debugPrint('Recorder started');

      // Reset output buffer state
      _incomingAudioBuffer.clear();
      _isBuffering = true;

      // Listen to WebSocket and play audio
      _webSocketSubscription = _channel?.stream.listen((message) {
        if (_isDisconnected) return;
        
        String stringMessage;
        if (message is String) {
          stringMessage = message;
        } else if (message is List<int>) {
          stringMessage = utf8.decode(message);
        } else {
          return;
        }
        
        try {
          final json = jsonDecode(stringMessage) as Map<String, dynamic>;

          if (json.containsKey('serverContent')) {
            final serverContent = json['serverContent'] as Map<String, dynamic>;
            
            // Audio Data
            if (serverContent.containsKey('modelTurn')) {
               onThinkingChanged?.call(false); // Stop thinking when AI starts responding
               final modelTurn = serverContent['modelTurn'] as Map<String, dynamic>;
               if (modelTurn.containsKey('parts')) {
                 final parts = modelTurn['parts'] as List<dynamic>;
                 for (final part in parts) {
                   if (part is Map<String, dynamic>) {
                     // Audio Data
                     if (part.containsKey('inlineData')) {
                       final inlineData = part['inlineData'] as Map<String, dynamic>;
                       if (inlineData['mimeType'] == 'audio/pcm;rate=$_outputSampleRate' || inlineData['mimeType'] == 'audio/pcm') {
                         final data = inlineData['data'] as String;
                         final bytes = base64Decode(data);
                         
                         // Apply Jitter Buffer
                         _incomingAudioBuffer.add(bytes);
                          if (_isBuffering) {
                            if (_incomingAudioBuffer.length >= _playbackThreshold) {
                              _isBuffering = false;
                              _pushToPlayer(_incomingAudioBuffer.takeBytes());
                            }
                          } else {
                            // Aggregate small chunks to reduce overhead
                            if (_incomingAudioBuffer.length >= _aggregationThreshold) {
                              _pushToPlayer(_incomingAudioBuffer.takeBytes());
                            }
                          }
                       }
                     }
                   }
                 }
               }
            }

            // Output Transcription (AI)
            final aiTrans = serverContent['outputAudioTranscription'] ?? serverContent['outputTranscription'];
            if (aiTrans != null) {
              String? text = aiTrans['text'] as String?;
              if (text != null && text.isNotEmpty) {
                // Parse and filter expression tags: [expressionName]
                final tagMatch = RegExp(r'^\[([a-zA-Z]+)\]').firstMatch(text.trim());
                if (tagMatch != null) {
                  final expression = tagMatch.group(1);
                  if (expression != null) {
                    onExpressionChanged?.call(expression);
                  }
                  // Remove the tag from the text
                  text = text.replaceFirst(tagMatch.group(0)!, '');
                }
                
                // Remove noise tags like <noise>, <music>, etc.
                text = text.replaceAll(RegExp(r'<[^>]+>'), '');
                
                // For Japanese response, eliminate spaces introduced by transcription
                if (RegExp(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]').hasMatch(text)) {
                   text = text.replaceAll(' ', '').replaceAll('　', '');
                }

                if (text.isNotEmpty) {
                  onTranscriptionReceived?.call(text, false);
                }
              }
            }

            // Input Transcription (User)
            final userTrans = serverContent['inputAudioTranscription'] ?? serverContent['inputTranscription'];
            if (userTrans != null) {
              onThinkingChanged?.call(true); // User is speaking or just spoke, AI is processing
              String? text = userTrans['text'] as String?;
              if (text != null && text.isNotEmpty) {
                // Remove noise tags like <noise>, <music>, etc.
                text = text.replaceAll(RegExp(r'<[^>]+>'), '');
                
                // For Japanese response, eliminate spaces introduced by transcription
                if (RegExp(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]').hasMatch(text)) {
                   text = text.replaceAll(' ', '').replaceAll('　', '');
                }
                
                if (text.isNotEmpty) {
                  onTranscriptionReceived?.call(text, true);
                }
              }
            }

            // Turn Complete or Interrupted
            if (serverContent['turnComplete'] == true) {
              // Flush remaining buffer
              if (_incomingAudioBuffer.length > 0) {
                _pushToPlayer(_incomingAudioBuffer.takeBytes());
              }
              onThinkingChanged?.call(false);
              _isBuffering = true;
              onTurnComplete?.call();
            } else if (serverContent['interrupted'] == true) {
              onThinkingChanged?.call(false);
              // Clear buffer and stop player immediately for responsive interruption
              _incomingAudioBuffer.clear();
              _isBuffering = true;
              if (!_isDisconnected) {
                _player.stopPlayer().then((_) {
                  if (!_isDisconnected) _startPlayer();
                });
              }
              onTurnComplete?.call();
            }
          }

          if (json.containsKey('setupComplete')) {
            debugPrint('Gemini Live API Ready');
          }

        } catch (e) {
          debugPrint('Error parsing message: $e');
        }
      }, onError: (e, stack) {
         debugPrint('WebSocket error: $e');
         debugPrint('Stack trace: $stack');
         disconnect();
      }, onDone: () {
         debugPrint('WebSocket closed by server. Close code: ${_channel?.closeCode}, Reason: ${_channel?.closeReason}');
         disconnect();
      });

    } catch (e) {
      debugPrint('Connection error: $e');
      await disconnect();
      rethrow;
    }
  }

  void _pushToPlayer(Uint8List data) {
    if (_isDisconnected) return;
    try {
      _player.uint8ListSink?.add(data);
    } catch (e) {
      debugPrint('Error pushing to player: $e');
    }
  }

  Future<void> _startPlayer() async {
    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: _outputSampleRate,
      bufferSize: _playerBufferSize,
      interleaved: false,
    );
  }

  Future<void> disconnect() async {
    // Prevent multiple disconnect calls
    if (_isDisconnected) return;
    _isDisconnected = true;

    debugPrint('Disconnecting LiveSession...');
    
    // Stop subscriptions first to prevent data flow
    await _recorderSubscription?.cancel();
    _recorderSubscription = null;
    await _webSocketSubscription?.cancel();
    _webSocketSubscription = null;
    _audioBuffer.clear();
    _incomingAudioBuffer.clear();

    // Close Recorder
    try {
        if (_recorder.isRecording) {
          await _recorder.stopRecorder();
        }
        await _recorder.closeRecorder();
    } catch(e) { debugPrint('Error closing recorder: $e'); }

    // Close Player
    try {
        if (_player.isPlaying) {
          await _player.stopPlayer();
        }
        await _player.closePlayer();
    } catch(e) { debugPrint('Error closing player: $e'); }

    try {
      await _channel?.sink.close();
    } catch(e) { debugPrint('Error closing channel sink: $e'); }
    
    _channel = null;
    debugPrint('WebSocket disconnected and Audio stopped');
  }
}
