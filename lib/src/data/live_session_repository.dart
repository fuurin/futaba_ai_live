import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';


import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class LiveSessionRepository {
  WebSocketChannel? _channel;
  
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  
  StreamSubscription? _recorderSubscription;
  StreamSubscription? _webSocketSubscription;

  // Buffer for accumulation using BytesBuilder for efficiency (Mic input)
  final BytesBuilder _audioBuffer = BytesBuilder();
  // Target buffer size (e.g., 100ms of audio). 
  // 16kHz * 2 bytes/sample * 0.1s = 3200 bytes.
  static const int _targetBufferSize = 3200;

  // Jitter buffer for output (AI voice)
  final BytesBuilder _incomingAudioBuffer = BytesBuilder();
  bool _isBuffering = true;
  // 200ms worth of 24kHz PCM16: 24000 * 2 * 0.2 = 9600 bytes
  static const int _playbackThreshold = 9600;

  Future<void> connect({
    void Function(String text, bool isUser)? onTranscriptionReceived,
    void Function()? onTurnComplete,
    void Function(String expression)? onExpressionChanged,
  }) async {
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
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
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
      final setupMessage = {
        'setup': {
          'model': 'models/gemini-2.5-flash-native-audio-preview-12-2025',
          'system_instruction': {
            'parts': [
              {
                'text': 'あなたは親しみやすいAIキャラクターです。ユーザーのメッセージに対して日本語で応答してください。'
                        'また、応答の内容に合わせて、返答の冒頭に必ず以下の形式で表情を指定してください。'
                        '[表情名] 返答内容...'
                        '表情名は以下のいずれかから選択してください: neutral, positiveLow, positiveMid, positiveHigh, negativeLow, negativeMid, negativeHigh'
                        '例: [positiveHigh] こんにちは！今日はとてもいい天気ですね。'
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
      
      _channel?.sink.add(jsonEncode(setupMessage));

      // Start Recorder (Input)
      final recordingStream = StreamController<Uint8List>();
      _audioBuffer.clear();
      
      _recorderSubscription = recordingStream.stream.listen((data) {
        if (_channel == null) return;
        
        _audioBuffer.add(data);

        if (_audioBuffer.length >= _targetBufferSize) {
           final chunkToSend = _audioBuffer.takeBytes();
           final base64Audio = base64Encode(chunkToSend);
            
            final audioMessage = {
              'realtime_input': {
                'media_chunks': [
                  {
                    'mime_type': 'audio/pcm;rate=16000',
                    'data': base64Audio,
                  }
                ]
              }
            };
            try {
                _channel!.sink.add(jsonEncode(audioMessage));
            } catch(e) {
                debugPrint('Error sending audio chunk: $e');
            }
        }
      });

      await _recorder.startRecorder(
        toStream: recordingStream.sink,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000,
      );
      debugPrint('Recorder started');

      // Reset output buffer state
      _incomingAudioBuffer.clear();
      _isBuffering = true;

      // Listen to WebSocket and play audio
      _webSocketSubscription = _channel?.stream.listen((message) {
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
               final modelTurn = serverContent['modelTurn'] as Map<String, dynamic>;
               if (modelTurn.containsKey('parts')) {
                 final parts = modelTurn['parts'] as List<dynamic>;
                 for (final part in parts) {
                   if (part is Map<String, dynamic>) {
                     // Audio Data
                     if (part.containsKey('inlineData')) {
                       final inlineData = part['inlineData'] as Map<String, dynamic>;
                       if (inlineData['mimeType'] == 'audio/pcm;rate=24000' || inlineData['mimeType'] == 'audio/pcm') {
                         final data = inlineData['data'] as String;
                         final bytes = base64Decode(data);
                         
                         // Apply Jitter Buffer
                         _incomingAudioBuffer.add(bytes);
                         if (_isBuffering) {
                           if (_incomingAudioBuffer.length >= _playbackThreshold) {
                             _isBuffering = false;
                             _player.uint8ListSink?.add(_incomingAudioBuffer.takeBytes());
                           }
                         } else {
                           _player.uint8ListSink?.add(_incomingAudioBuffer.takeBytes());
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
              if (text != null && text.trim().isNotEmpty) {
                // Parse and filter expression tags: [expressionName]
                final tagMatch = RegExp(r'^\[([a-zA-Z]+)\]').firstMatch(text.trim());
                if (tagMatch != null) {
                  final expression = tagMatch.group(1);
                  if (expression != null) {
                    onExpressionChanged?.call(expression);
                  }
                  // Remove the tag from the text
                  text = text.replaceFirst(tagMatch.group(0)!, '').trim();
                }
                
                if (text.isNotEmpty) {
                  onTranscriptionReceived?.call(text, false);
                }
              }
            }

            // Input Transcription (User)
            final userTrans = serverContent['inputAudioTranscription'] ?? serverContent['inputTranscription'];
            if (userTrans != null) {
              final text = userTrans['text'] as String?;
              if (text != null && text.trim().isNotEmpty) {
                onTranscriptionReceived?.call(text, true);
              }
            }

            // Turn Complete or Interrupted
            if (serverContent['turnComplete'] == true) {
              // Flush remaining buffer
              if (_incomingAudioBuffer.isNotEmpty) {
                _player.uint8ListSink?.add(_incomingAudioBuffer.takeBytes());
              }
              _isBuffering = true;
              onTurnComplete?.call();
            } else if (serverContent['interrupted'] == true) {
              // Clear buffer and stop player immediately for responsive interruption
              _incomingAudioBuffer.clear();
              _isBuffering = true;
              _player.stopPlayer().then((_) => _startPlayer());
              onTurnComplete?.call();
            }
          }

          if (json.containsKey('setupComplete')) {
            debugPrint('Gemini Live API Ready');
          }

        } catch (e) {
          debugPrint('Error parsing message: $e');
        }
      }, onError: (e) {
         debugPrint('WebSocket error: $e');
         disconnect();
      }, onDone: () {
         debugPrint('WebSocket closed by server');
         disconnect();
      });

    } catch (e) {
      debugPrint('Connection error: $e');
      await disconnect();
      rethrow;
    }
  }

  Future<void> _startPlayer() async {
    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 24000,
      bufferSize: 16384, // Slightly larger buffer for stability
      interleaved: false,
    );
  }

  Future<void> disconnect() async {
    // Prevent multiple disconnect calls
    if (_recorderSubscription == null && _webSocketSubscription == null && _channel == null) return;

    debugPrint('Disconnecting LiveSession... Caller: ${StackTrace.current}');
    
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
