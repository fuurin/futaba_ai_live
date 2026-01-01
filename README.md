# Futaba AI Live (双葉アイ Live)

Gemini 2.0 Flash (Multimodal Live API) を活用した、AIキャラクター「双葉アイ」とリアルタイムに対話できるFlutterアプリです。音声とテキストの両方で、彼女と友達感覚で会話を楽しむことができます。

## 🌟 主な機能

- **Realtime Voice Chat**: Multimodal Live API (WebSocket) を利用した、低遅延な音声対話。
- **Text Chat**: 通常のテキストベースでのチャット。
- **Dynamic Expressions**: AIの感情に合わせてキャラクターの表情がリアルタイムに変化（フェードアニメーション付き）。
- **Transcription**: ユーザーとAIの会話をリアルタイムで文字起こしし、チャット画面に表示。
- **Thinking Indicator**: AIが応答を生成している間、視覚的なフィードバックを表示。
- **Centralized Prompts**: プロンプトを独立したファイルで管理し、性格や口調の調整を容易に。

## 🛠️ セットアップ手順

### 1. APIキーの取得
[Google AI Studio](https://aistudio.google.com/) から Gemini API キーを取得してください。

### 2. 環境変数の設定
プロジェクトのルートディレクトリに `.env` ファイルを作成し、取得したAPIキーを設定します。

```env
GEMINI_API_KEY=your_api_key_here
```

### 3. 依存関係のインストール
```bash
flutter pub get
```

### 4. アプリの実行

接続されているデバイス（エミュレータ・実機）を確認します：
```bash
flutter devices
```

取得したデバイスIDを指定して実行します（デバイスが1つの場合は `flutter run` のみで可）：
```bash
flutter run -d <DEVICE_ID>
```

## 🎙️ オーディオの安定性について

ネットワーク環境によってAIの音声が途切れたり（ぶつ切れ）、ノイズが乗る場合は、`lib/src/data/live_session_repository.dart` 内の以下の値を調整してください：

- **`_playbackThreshold`**: 再生開始前に蓄積するデータの閾値です。値を大きくすると（例: `24000` = 500ms）、通信の揺れに強くなります。
- **`bufferSize`** (`_startPlayer`内): プレイヤー内部のバッファサイズです。安定性のために大きめの値（例: `96000`）を推奨します。
- **Aggregation**: 長い文章でのぶつ切れ対策として、再生中も約100ms単位でデータをまとめてからプレイヤーに渡す処理を導入しています。

## 📂 プロジェクト構造 (主なもの)

- `lib/src/data/constants/prompts.dart`: キャラクターの性格や指示を定義。
- `lib/src/data/live_session_repository.dart`: 音声ライブセッションの通信ロジック。
- `lib/src/presentation/widgets/character_view.dart`: キャラクター表示と表情アニメーション。
- `lib/src/presentation/widgets/chat_view.dart`: チャット画面とインジケーター。

## ⚠️ 免責事項 (Disclaimer)

このプロジェクトのコードの大部分、およびドキュメントは **Google Gemini (Advanced Agentic Coding)** を使用して生成・構成されています。
AIによる自動生成コードが含まれているため、利用にあたっては以下の点にご注意ください。

- 予期しない挙動やセキュリティ上のリスクが含まれる可能性があります。
- 本番環境での利用前には、必ず人間によるコードレビューとテストを行ってください。
- 本ソフトウェアの使用によって生じた損害等について、開発者は一切の責任を負いません。

---
Produced with ❤️ by Antigravity (Gemini Agent)
