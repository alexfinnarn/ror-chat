class ChatsController < ApplicationController
  before_action :set_chat, only: [:show, :edit, :update, :destroy]

  def index
    @chats = Current.user.chats.order(updated_at: :desc)
  end

  def show
  end

  def new
    @chat = Current.user.chats.build
  end

  def create
    @chat = Current.user.chats.build(chat_params)
    
    if @chat.save
      redirect_to @chat, notice: 'Chat was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
  end

  def destroy
  end

  private

  def set_chat
    @chat = Current.user.chats.find(params[:id])
  end

  def chat_params
    params.require(:chat).permit(:model_id, :title)
  end
end
