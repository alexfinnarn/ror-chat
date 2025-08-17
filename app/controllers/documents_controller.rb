class DocumentsController < ApplicationController
  before_action :require_authentication
  before_action :set_project
  before_action :set_document, only: [ :show, :destroy ]

  def index
    @documents = @project.documents.order(created_at: :desc)
  end

  def show
  end

  def new
    @document = @project.documents.build
  end

  def create
    @document = @project.documents.build

    if params[:file].present?
      uploaded_file = params[:file]

      # Check file size limit
      if uploaded_file.size > Document::MAX_FILE_SIZE
        @error_message = "File too large (maximum #{Document::MAX_FILE_SIZE / 1.megabyte}MB allowed)"
        respond_to do |format|
          format.html {
            @document.errors.add(:file, @error_message)
            render :new
          }
          format.js { render "error" }
        end
        return
      end

      # Save uploaded file temporarily
      temp_path = Rails.root.join("tmp", uploaded_file.original_filename)
      File.open(temp_path, "wb") do |file|
        file.write(uploaded_file.read)
      end

      begin
        # Extract text content
        content = TextExtractionService.extract_from_file(temp_path)

        # Truncate content if it exceeds the limit and add warning
        if content.length > Document::MAX_CONTENT_LENGTH
          content = content[0...Document::MAX_CONTENT_LENGTH]
          Rails.logger.warn "Document content truncated to #{Document::MAX_CONTENT_LENGTH} characters: #{uploaded_file.original_filename}"
        end

        @document.assign_attributes(
          title: uploaded_file.original_filename,
          content: content,
          file_path: uploaded_file.original_filename,
          content_type: uploaded_file.content_type
        )

        if @document.save
          notice_message = "Document uploaded successfully."
          if content.length == Document::MAX_CONTENT_LENGTH
            notice_message += " Note: Content was truncated to #{Document::MAX_CONTENT_LENGTH} characters."
          end

          respond_to do |format|
            format.html { redirect_to @project, notice: notice_message }
            format.js { render "create" }
          end
        else
          respond_to do |format|
            format.html { render :new }
            format.js { render "error" }
          end
        end
      rescue => e
        @error_message = "Error processing file: #{e.message}"
        respond_to do |format|
          format.html {
            @document.errors.add(:file, @error_message)
            render :new
          }
          format.js { render "error" }
        end
      ensure
        File.unlink(temp_path) if File.exist?(temp_path)
      end
    else
      @error_message = "Please select a file to upload"
      respond_to do |format|
        format.html {
          @document.errors.add(:file, @error_message)
          render :new
        }
        format.js { render "error" }
      end
    end
  end

  def destroy
    @document.destroy
    respond_to do |format|
      format.html { redirect_to @project, notice: "Document deleted successfully." }
      format.js { render "destroy" }
    end
  end

  private

  def set_project
    @project = Current.user.projects.find(params[:project_id])
  end

  def set_document
    @document = @project.documents.find(params[:id])
  end
end
