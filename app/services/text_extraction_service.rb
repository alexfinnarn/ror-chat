class TextExtractionService
  def self.extract_from_file(file_path)
    case File.extname(file_path).downcase
    when ".pdf"
      extract_from_pdf(file_path)
    when ".txt", ".md"
      File.read(file_path)
    when ".docx"
      extract_from_docx(file_path)
    else
      raise "Unsupported file type: #{File.extname(file_path)}"
    end
  end

  private

  def self.extract_from_pdf(file_path)
    reader = PDF::Reader.new(file_path)
    reader.pages.map(&:text).join("\n")
  end

  def self.extract_from_docx(file_path)
    doc = Docx::Document.open(file_path)
    doc.paragraphs.map(&:text).join("\n")
  end
end
