class ProjectsController < ApplicationController
  before_action :require_authentication
  before_action :set_project, only: [ :show, :edit, :update, :destroy ]

  def index
    @projects = Current.user.projects.order(created_at: :desc)
  end

  def show
    @chats = @project.chats.order(created_at: :desc)
    @documents = @project.documents.order(created_at: :desc)
  end

  def new
    @project = Current.user.projects.build
  end

  def create
    @project = Current.user.projects.build(project_params)
    if @project.save
      redirect_to @project, notice: "Project created successfully."
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @project.update(project_params)
      redirect_to @project, notice: "Project updated successfully."
    else
      render :edit
    end
  end

  def destroy
    @project.destroy
    redirect_to projects_path, notice: "Project deleted successfully."
  end

  private

  def set_project
    @project = Current.user.projects.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name, :description, :instructions)
  end
end
