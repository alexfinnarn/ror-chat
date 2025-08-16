class ChatsController < ApplicationController
  before_action :set_project, only: [ :new, :create, :show, :edit, :update, :destroy ], if: :project_nested?
  before_action :set_chat, only: [ :show, :edit, :update, :destroy ]

  def index
    @chats = Current.user.chats.order(updated_at: :desc)

    if params[:search].present?
      @chats = @chats.search_by_title_and_model(params[:search])
    end
  end

  def show
  end

  def new
    if @project
      @chat = @project.chats.build
    else
      @chat = Current.user.chats.build
    end
  end

  def create
    if @project
      @chat = @project.chats.build(chat_params)
      @chat.user = Current.user

      if @chat.save
        redirect_to [ @project, @chat ], notice: "Chat was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    else
      @chat = Current.user.chats.build(chat_params)

      if @chat.save
        redirect_to @chat, notice: "Chat was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end
  end

  def edit
  end

  def update
  end

  def destroy
    @chat.destroy
    redirect_to chats_path, notice: "Chat was successfully deleted."
  end

  private

  def set_project
    @project = Current.user.projects.find(params[:project_id]) if params[:project_id]
  end

  def project_nested?
    params[:project_id].present?
  end

  def set_chat
    if @project
      @chat = @project.chats.find(params[:id])
    else
      @chat = Current.user.chats.find(params[:id])
    end
  end

  def chat_params
    params.require(:chat).permit(:model_id, :title)
  end
end
