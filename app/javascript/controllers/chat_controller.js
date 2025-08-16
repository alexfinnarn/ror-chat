import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "form"]

  connect() {
    this.scrollToBottom()
    
    // Listen for form submission events
    this.element.addEventListener("turbo:submit-start", this.handleSubmitStart.bind(this))
    this.element.addEventListener("turbo:submit-end", this.handleSubmitEnd.bind(this))
  }

  handleSubmitStart(event) {
    // Optional: Show loading state or disable form
    const form = event.target
    const submitButton = form.querySelector('input[type="submit"], button[type="submit"]')
    if (submitButton) {
      submitButton.disabled = true
      submitButton.dataset.originalText = submitButton.value || submitButton.textContent
      submitButton.value = submitButton.textContent = "Sending..."
    }
  }

  handleSubmitEnd(event) {
    // Re-enable form after submission
    const form = event.target
    const submitButton = form.querySelector('input[type="submit"], button[type="submit"]')
    if (submitButton) {
      submitButton.disabled = false
      submitButton.value = submitButton.textContent = submitButton.dataset.originalText || "Send"
    }
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
    
    // Check if we have content
    const hasText = textarea && textarea.value.trim() !== ''
    
    if (!hasText) {
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
      const hasText = event.target.value.trim() !== ''
      
      if (form && hasText) {
        form.requestSubmit()
      }
    }
    
    // Debug: Add Ctrl+R to manually trigger message reordering
    if (event.key === 'r' && event.ctrlKey) {
      event.preventDefault()
      const messageOrderingController = this.application.getControllerForElementAndIdentifier(
        document.querySelector('[data-controller="message-ordering"]'),
        'message-ordering'
      )
      if (messageOrderingController) {
        messageOrderingController.manualReorder()
      }
    }
  }
}