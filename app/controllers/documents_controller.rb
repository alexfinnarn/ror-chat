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

      # Save uploaded file temporarily
      temp_path = Rails.root.join("tmp", uploaded_file.original_filename)
      File.open(temp_path, "wb") do |file|
        file.write(uploaded_file.read)
      end

      begin
        # Extract text content
        content = TextExtractionService.extract_from_file(temp_path)

        @document.assign_attributes(
          title: uploaded_file.original_filename,
          content: content,
          file_path: uploaded_file.original_filename,
          content_type: uploaded_file.content_type
        )

        if @document.save
          respond_to do |format|
            format.html { redirect_to @project, notice: "Document uploaded successfully." }
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
