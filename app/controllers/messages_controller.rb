class MessagesController < ApplicationController
  before_action :set_chat
  before_action :set_message, only: [ :show, :edit, :update, :destroy ]

  def index
    @messages = @chat.messages.order(:created_at)
  end

  def show
  end

  def new
    @message = @chat.messages.build
  end

  def create
    @message = @chat.messages.build(message_params.merge(role: "user"))

    if @message.save
      # Create assistant response message
      @assistant_message = @chat.messages.create!(role: "assistant", content: "")

      # Queue job to get AI response
      ChatStreamJob.perform_later(@chat.id)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @chat }
      end
    else
      respond_to do |format|
        format.turbo_stream
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    if @message.update(message_params)
      redirect_to [ @chat, @message ], notice: "Message was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @message.destroy
    redirect_to @chat, notice: "Message was successfully deleted."
  end

  private

  def set_chat
    @chat = Current.user.chats.find(params[:chat_id])
  end

  def set_message
    @message = @chat.messages.find(params[:id])
  end

  def message_params
    params.require(:message).permit(:content)
  end
end
