# Japanese Test Data for ELIAS Content Conversion

This file contains sample Japanese content for testing the ELIAS system's Japanese language processing capabilities.

## Sample 1: Basic Japanese Scripts

### Hiragana (ひらがな)
```
こんにちは、世界。
これはひらがなのテストです。
あいうえお、かきくけこ、さしすせそ。
```

### Katakana (カタカナ)
```
コンピュータ・サイエンス
データベース・システム
アルゴリズム・テスト
プログラミング・ランゲージ
```

### Kanji (漢字)
```
日本語自然言語処理
機械学習アルゴリズム
人工知能研究開発
深層学習システム
```

## Sample 2: Technical Documentation

### AI研究論文
```
## 深層学習による日本語自然言語処理の進歩

### 概要
本研究では、Transformer アーキテクチャを基盤とした日本語自然言語処理システムの開発について報告する。特に、文字レベル、単語レベル、文レベルでの表現学習手法を統合的に扱う新しいアプローチを提案する。

### 技術的貢献
1. **多層表現学習**: ひらがな、カタカナ、漢字の特性を活かした階層的エンコーディング
2. **文脈理解モデル**: 助詞・語順の特性を考慮した双方向注意機構
3. **効率的推論**: 日本語特有の文字体系に最適化されたトークナイゼーション手法

### 実験結果
| タスク | 精度 | F1スコア | 処理速度 |
|--------|------|----------|----------|
| 文書分類 | 94.2% | 0.93 | 1,000文書/秒 |
| 質問応答 | 87.1% | 0.924 | 平均150ms |
| 要約生成 | 89.7% | 0.891 | 平均300ms |

### 今後の課題
- リアルタイム推論の最適化
- ドメイン適応機能の強化
- マルチモーダル対応への拡張
- 文化的文脈の理解向上
```

## Sample 3: Mixed Content Test

### 技術仕様書（日英混在）
```
# ELIAS Japanese Processing Specification

## システム要件
- **入力形式**: PDF, DOCX, RTF, TXT
- **出力形式**: Markdown, JSON, XML
- **対応文字**: UTF-8 (JIS X 0213 全文字)

### Performance Requirements
- 処理速度: ≥ 10,000 characters/second
- Memory usage: ≤ 512MB per document
- Accuracy: ≥ 95% for text extraction

### API Endpoints
```elixir
# Document processing
ULM.ingest_document(path, :pdf, extract_knowledge: true)

# Text conversion
ULM.convert_text(:markdown, input_path, output_path, 
  language: "ja", 
  preserve_formatting: true)
```

## Testing Notes
- UTF-8 encoding preservation is critical
- Multi-byte character boundaries must be respected
- Japanese text segmentation differs from Latin scripts
- Cultural context affects AI model performance
```

## Sample 4: Complex Unicode Test

### Special Characters and Symbols
```
★重要事項★
※注意点※
◆参考資料◆
♪音楽関連♪
🎌日本の旗🎌
📚学習教材📚
🤖AI・ロボット🤖
⚡高速処理⚡
🔧システム調整🔧
```

### Full-width and Half-width Characters
```
全角：ＡＢＣＤＥＦＧ１２３４５６７
半角：ABCDEFG1234567
混在：ABCあいう123ｱｲｳ！？。
```

### Programming Code with Japanese Comments
```python
def 日本語処理関数(入力データ):
    """
    日本語テキストを処理する関数
    
    Args:
        入力データ (str): 処理対象の日本語テキスト
    
    Returns:
        dict: 処理結果とメタデータ
    """
    # 前処理：文字正規化
    正規化済みテキスト = 入力データ.strip().lower()
    
    # 形態素解析
    形態素リスト = tokenize(正規化済みテキスト)
    
    # 結果返却
    return {
        'original': 入力データ,
        'normalized': 正規化済みテキスト,
        'tokens': 形態素リスト,
        'character_count': len(入力データ),
        'processed_at': datetime.now()
    }
```

This test data can be used to validate:
1. UTF-8 encoding preservation
2. Japanese character recognition
3. Mixed script handling
4. Technical content processing
5. Special symbol preservation
6. Code comment extraction