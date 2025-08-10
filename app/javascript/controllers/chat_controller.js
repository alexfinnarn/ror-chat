import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "form"]

  connect() {
    this.scrollToBottom()
  }

  messagesTargetConnected() {
    this.scrollToBottom()
  }

  scrollToBottom() {
    if (this.hasMessagesTarget) {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    }
  }

  submitForm(event) {
    const form = event.target
    const textarea = form.querySelector('textarea')
    
    if (textarea && textarea.value.trim() === '') {
      event.preventDefault()
      return
    }

    // Clear the form after submission
    setTimeout(() => {
      if (textarea) {
        textarea.value = ''
        textarea.style.height = 'auto'
        textarea.focus()
      }
    }, 100)
  }

  handleKeydown(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      const form = event.target.closest('form')
      if (form && event.target.value.trim() !== '') {
        form.requestSubmit()
      }
    }
  }
}