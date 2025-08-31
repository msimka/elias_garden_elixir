# 🔧 Multi-Format Text Converter: Component Architecture

## Based on Architect Guidance: Hierarchical Atomic Components with Blockchain Verification

---

## 🏗️ **Component Hierarchy Tree**

```
MultiFormatTextConverter (root)
├── 1.0 FileOperations
│   ├── 1.1 FileReader (atomic)
│   ├── 1.2 FileValidator (atomic)
│   └── 1.3 OutputWriter (atomic)
├── 2.0 FormatDetection
│   ├── 2.1 FormatDetector (atomic)
│   └── 2.2 MimeTypeAnalyzer (atomic)
├── 3.0 ContentExtraction
│   ├── 3.1 PdfTextExtractor (atomic)
│   ├── 3.2 RtfTextExtractor (atomic)  
│   ├── 3.3 DocxTextExtractor (atomic)
│   ├── 3.4 PlainTextExtractor (atomic)
│   └── 3.5 HtmlTextExtractor (atomic)
├── 4.0 StructureAnalysis
│   ├── 4.1 HeadingDetector (atomic)
│   ├── 4.2 ListDetector (atomic)
│   ├── 4.3 ParagraphSeparator (atomic)
│   └── 4.4 TableDetector (atomic)
├── 5.0 MarkdownGeneration
│   ├── 5.1 HeadingFormatter (atomic)
│   ├── 5.2 ListFormatter (atomic)
│   ├── 5.3 ParagraphFormatter (atomic)
│   ├── 5.4 TableFormatter (atomic)
│   └── 5.5 LinkFormatter (atomic)
└── 6.0 QualityAssurance
    ├── 6.1 MarkdownValidator (atomic)
    └── 6.2 ContentVerifier (atomic)
```

---

## ⚛️ **Atomic Component Definitions**

### **1.0 FileOperations**

#### **1.1 FileReader**
- **Function**: Read file bytes from filesystem
- **Input**: `file_path: string`
- **Output**: `content: binary`, `size: integer`
- **Responsibility**: ONLY read file, no processing
- **Real Test**: Read actual test files, verify byte count matches filesystem

#### **1.2 FileValidator** 
- **Function**: Validate file exists, readable, size limits
- **Input**: `file_path: string`
- **Output**: `valid: boolean`, `error_reason: string | nil`
- **Responsibility**: ONLY validation checks
- **Real Test**: Test with non-existent files, permission denied, oversized files

#### **1.3 OutputWriter**
- **Function**: Write markdown content to file
- **Input**: `content: string`, `output_path: string`
- **Output**: `success: boolean`, `bytes_written: integer`
- **Responsibility**: ONLY write output file
- **Real Test**: Write file, verify content on disk matches input exactly

### **2.0 FormatDetection**

#### **2.1 FormatDetector**
- **Function**: Identify file format via magic bytes
- **Input**: `file_content: binary`
- **Output**: `format: :pdf | :rtf | :docx | :txt | :html | :unknown`
- **Responsibility**: ONLY format identification
- **Real Test**: Test known file samples, verify format detection accuracy

#### **2.2 MimeTypeAnalyzer**
- **Function**: Extract MIME type information
- **Input**: `file_content: binary`
- **Output**: `mime_type: string`, `charset: string`
- **Responsibility**: ONLY MIME analysis
- **Real Test**: Verify MIME detection matches file command output

### **3.0 ContentExtraction**

#### **3.1 PdfTextExtractor**
- **Function**: Extract text content from PDF files
- **Input**: `pdf_content: binary`
- **Output**: `text: string`, `metadata: map`
- **Responsibility**: ONLY PDF text extraction
- **Real Test**: Extract from known PDFs, verify text matches expected content
- **Implementation**: Python port to PyMuPDF

#### **3.2 RtfTextExtractor**  
- **Function**: Extract text content from RTF files
- **Input**: `rtf_content: binary`
- **Output**: `text: string`, `metadata: map`
- **Responsibility**: ONLY RTF text extraction
- **Real Test**: Extract from known RTFs, verify formatting preservation
- **Implementation**: Python port to striprtf or pypandoc

#### **3.3 DocxTextExtractor**
- **Function**: Extract text content from DOCX files  
- **Input**: `docx_content: binary`
- **Output**: `text: string`, `metadata: map`
- **Responsibility**: ONLY DOCX text extraction
- **Real Test**: Extract from known DOCX files, verify content accuracy
- **Implementation**: Python port to python-docx

#### **3.4 PlainTextExtractor**
- **Function**: Process plain text files with encoding detection
- **Input**: `text_content: binary`
- **Output**: `text: string`, `encoding: string`
- **Responsibility**: ONLY plain text processing
- **Real Test**: Process files with various encodings (UTF-8, Latin-1, etc.)

#### **3.5 HtmlTextExtractor**
- **Function**: Extract text content from HTML, strip tags
- **Input**: `html_content: binary`  
- **Output**: `text: string`, `links: list`
- **Responsibility**: ONLY HTML text extraction
- **Real Test**: Extract from HTML files, verify tag stripping and link extraction

### **4.0 StructureAnalysis**

#### **4.1 HeadingDetector**
- **Function**: Identify headings in extracted text
- **Input**: `text: string`
- **Output**: `headings: list({level: integer, text: string, position: integer})`
- **Responsibility**: ONLY heading detection
- **Real Test**: Analyze text with known heading structure, verify detection accuracy

#### **4.2 ListDetector**
- **Function**: Identify lists (ordered/unordered) in text
- **Input**: `text: string`
- **Output**: `lists: list({type: :ordered | :unordered, items: list, position: integer})`
- **Responsibility**: ONLY list detection
- **Real Test**: Detect lists in structured text, verify item enumeration

#### **4.3 ParagraphSeparator**
- **Function**: Separate text into logical paragraphs
- **Input**: `text: string`
- **Output**: `paragraphs: list(string)`
- **Responsibility**: ONLY paragraph separation
- **Real Test**: Separate known text, verify paragraph boundaries

#### **4.4 TableDetector**
- **Function**: Identify tabular data in text
- **Input**: `text: string`
- **Output**: `tables: list({rows: list(list), headers: list, position: integer})`
- **Responsibility**: ONLY table detection  
- **Real Test**: Detect tables in structured text, verify row/column parsing

### **5.0 MarkdownGeneration**

#### **5.1 HeadingFormatter**
- **Function**: Convert headings to markdown format
- **Input**: `headings: list({level: integer, text: string})`
- **Output**: `markdown: string`
- **Responsibility**: ONLY heading markdown formatting
- **Real Test**: Format headings, verify correct # symbols and spacing

#### **5.2 ListFormatter**
- **Function**: Convert lists to markdown format
- **Input**: `lists: list({type: :ordered | :unordered, items: list})`
- **Output**: `markdown: string`
- **Responsibility**: ONLY list markdown formatting
- **Real Test**: Format lists, verify correct bullets/numbers and indentation

#### **5.3 ParagraphFormatter**  
- **Function**: Format paragraphs for markdown
- **Input**: `paragraphs: list(string)`
- **Output**: `markdown: string`
- **Responsibility**: ONLY paragraph markdown formatting
- **Real Test**: Format paragraphs, verify proper line spacing

#### **5.4 TableFormatter**
- **Function**: Convert tables to markdown format
- **Input**: `tables: list({rows: list(list), headers: list})`
- **Output**: `markdown: string`
- **Responsibility**: ONLY table markdown formatting
- **Real Test**: Format tables, verify correct pipe syntax and alignment

#### **5.5 LinkFormatter**
- **Function**: Convert links to markdown format
- **Input**: `links: list({url: string, text: string})`
- **Output**: `markdown: string`
- **Responsibility**: ONLY link markdown formatting
- **Real Test**: Format links, verify correct [text](url) syntax

### **6.0 QualityAssurance**

#### **6.1 MarkdownValidator**
- **Function**: Validate generated markdown syntax
- **Input**: `markdown: string`
- **Output**: `valid: boolean`, `errors: list(string)`
- **Responsibility**: ONLY markdown syntax validation
- **Real Test**: Validate known good/bad markdown, verify error detection

#### **6.2 ContentVerifier**  
- **Function**: Verify content preservation from input to output
- **Input**: `original_text: string`, `markdown: string`
- **Output**: `preservation_score: float`, `missing_content: list`
- **Responsibility**: ONLY content verification
- **Real Test**: Compare original vs converted content, verify preservation metrics

---

## 🧪 **Real Verification Testing Framework**

### **Testing Philosophy**
- **Real Files**: Use actual PDF/RTF/DOCX files, not mocks
- **End-to-End Verification**: Test actual functionality, not just code paths
- **Golden Master**: Compare outputs against known-good results
- **Edge Cases**: Test with malformed files, large files, edge encodings

### **Test Structure Per Component**
```elixir
defmodule ComponentTest do
  @test_files_dir "test/fixtures/real_files"
  
  test "component_name performs real operation" do
    # 1. Setup: Use real test file
    input_file = Path.join(@test_files_dir, "sample.pdf")
    
    # 2. Execute: Run actual component
    result = Component.process(input_file)
    
    # 3. Verify: Check real outcome
    assert result.success == true
    assert byte_size(result.content) > 0
    
    # 4. Real validation: Compare with expected
    expected = File.read!(Path.join(@test_files_dir, "sample.expected.txt"))
    assert String.contains?(result.content, extract_key_phrases(expected))
  end
end
```

### **Blockchain Verification Integration**
```elixir
defmodule BlockchainTestVerifier do
  def verify_and_sign(component_id, test_result) do
    # 1. Generate test hash
    test_hash = :crypto.hash(:sha256, "#{component_id}:#{inspect(test_result)}")
    
    # 2. Sign with user key
    signature = sign_hash(test_hash, get_user_private_key())
    
    # 3. Submit to Level 2 rollup (via UFM federation)
    rollup_transaction = %{
      component_id: component_id,
      test_hash: test_hash,
      signature: signature,
      timestamp: DateTime.utc_now()
    }
    
    # 4. Post to rollup via federated API
    UFM.submit_to_available_rollup_node(rollup_transaction)
  end
end
```

---

## 📊 **Tank Building Implementation Stages**

### **Stage 1: BRUTE_FORCE (Single Format)**
- **Target**: PDF-to-MD conversion only
- **Components**: FileReader, FormatDetector, PdfTextExtractor, basic MarkdownFormatter
- **Success Criteria**: Convert one PDF file to readable markdown
- **Blockchain Verification**: All atomic components tested and signed

### **Stage 2: EXTEND (Multi-Format)**  
- **Target**: Add RTF, DOCX support without breaking PDF
- **Components**: RtfTextExtractor, DocxTextExtractor, improved structure detection
- **Success Criteria**: Convert PDF/RTF/DOCX with same interface
- **Blockchain Verification**: New components tested, old components unchanged

### **Stage 3: OPTIMIZE (Structure Recognition)**
- **Target**: Better heading/list/table detection and formatting
- **Components**: Enhanced structure analyzers, better markdown formatters  
- **Success Criteria**: High-quality markdown with proper structure
- **Blockchain Verification**: All optimizations tested and verified

### **Stage 4: ITERATE (Quality + Performance)**
- **Target**: Content verification, performance optimization, edge case handling
- **Components**: QualityAssurance modules, performance monitoring
- **Success Criteria**: Production-ready converter with verification
- **Blockchain Verification**: Full system certification with quality metrics

---

## 🔗 **ELIAS Integration Architecture**

### **CLI Integration via UIM**
```elixir
# CLI command: mix elias.convert --input file.pdf --output file.md
defmodule Mix.Tasks.Elias.Convert do
  def run(args) do
    # 1. Parse arguments via UIM interface management
    opts = UIM.parse_cli_args(args)
    
    # 2. Coordinate conversion via component pipeline
    result = MultiFormatConverter.process(opts.input, opts.output)
    
    # 3. Verify via blockchain (if enabled)
    if opts.verify, do: BlockchainVerifier.verify_conversion(result)
    
    # 4. Output results
    UIM.display_conversion_result(result)
  end
end
```

### **Component Supervision via UIM**
```elixir
defmodule MultiFormatConverter.Supervisor do
  use Supervisor
  
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    children = [
      {FileOperations.Supervisor, []},
      {FormatDetection.Supervisor, []},
      {ContentExtraction.Supervisor, []},
      # ... other component supervisors
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

---

## ✅ **Next Implementation Steps**

1. **Create TIKI Specifications**: Write detailed .tiki files for each component
2. **Build Test Framework**: Create real file testing infrastructure  
3. **Implement Atomic Components**: Start with FileReader, FormatDetector
4. **Setup Blockchain Simulation**: Build Level 2 rollup for test verification
5. **Integrate Components**: Assemble into pipeline
6. **Create CLI Interface**: Wrap in Mix task under UIM

This architecture ensures atomic, testable, blockchain-verified components that can be reused across ELIAS ecosystem while maintaining the Tank Building methodology for systematic development.