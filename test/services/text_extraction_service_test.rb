require "test_helper"

class TextExtractionServiceTest < ActiveSupport::TestCase
  def setup
    @temp_dir = Rails.root.join("tmp", "test_files")
    FileUtils.mkdir_p(@temp_dir)
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir.exist?
  end

  test "should extract text from plain text file" do
    content = "This is a test document with some content."
    txt_file = create_temp_file("test.txt", content)

    extracted = TextExtractionService.extract_from_file(txt_file)
    assert_equal content, extracted
  end

  test "should extract text from markdown file" do
    content = "# Test Document\n\nThis is **markdown** content."
    md_file = create_temp_file("test.md", content)

    extracted = TextExtractionService.extract_from_file(md_file)
    assert_equal content, extracted
  end

  test "should extract text from PDF file" do
    pdf_file = create_temp_file("test.pdf", "dummy")

    # Mock PDF::Reader
    mock_page = Struct.new(:text).new("This is PDF content")
    mock_reader = Struct.new(:pages).new([ mock_page ])

    PDF::Reader.stub :new, mock_reader do
      extracted = TextExtractionService.extract_from_file(pdf_file)
      assert_equal "This is PDF content", extracted
    end
  end

  test "should extract text from multiple PDF pages" do
    pdf_file = create_temp_file("test.pdf", "dummy")

    # Mock PDF::Reader with multiple pages
    page1 = Struct.new(:text).new("Page 1 content")
    page2 = Struct.new(:text).new("Page 2 content")
    mock_reader = Struct.new(:pages).new([ page1, page2 ])

    PDF::Reader.stub :new, mock_reader do
      extracted = TextExtractionService.extract_from_file(pdf_file)
      assert_equal "Page 1 content\nPage 2 content", extracted
    end
  end

  test "should extract text from DOCX file" do
    docx_file = create_temp_file("test.docx", "dummy")

    # Mock Docx::Document
    paragraph1 = Struct.new(:text).new("First paragraph")
    paragraph2 = Struct.new(:text).new("Second paragraph")
    mock_doc = Struct.new(:paragraphs).new([ paragraph1, paragraph2 ])

    Docx::Document.stub :open, mock_doc do
      extracted = TextExtractionService.extract_from_file(docx_file)
      assert_equal "First paragraph\nSecond paragraph", extracted
    end
  end

  test "should raise error for unsupported file type" do
    unsupported_file = create_temp_file("test.xyz", "content")

    error = assert_raises(RuntimeError) do
      TextExtractionService.extract_from_file(unsupported_file)
    end

    assert_equal "Unsupported file type: .xyz", error.message
  end

  test "should handle file extensions case insensitively" do
    content = "This is test content"

    # Test uppercase extensions
    txt_file = create_temp_file("test.TXT", content)
    extracted = TextExtractionService.extract_from_file(txt_file)
    assert_equal content, extracted

    md_file = create_temp_file("test.MD", content)
    extracted = TextExtractionService.extract_from_file(md_file)
    assert_equal content, extracted
  end

  test "should handle empty files" do
    empty_file = create_temp_file("empty.txt", "")

    extracted = TextExtractionService.extract_from_file(empty_file)
    assert_equal "", extracted
  end

  test "should handle files with special characters" do
    content = "Content with special chars: àáâãäåæçèéêë"
    txt_file = create_temp_file("special.txt", content)

    extracted = TextExtractionService.extract_from_file(txt_file)
    assert_equal content, extracted
  end

  private

  def create_temp_file(filename, content)
    file_path = @temp_dir.join(filename)
    File.write(file_path, content)
    file_path.to_s
  end
end
