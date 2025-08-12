// app/javascript/controllers/message_ordering_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message"]

  connect() {
    this.reorderMessages()
    this.observeNewMessages()
    this.setupTurboStreamListeners()
  }

  observeNewMessages() {
    // Watch for new messages being added to the DOM
    const observer = new MutationObserver((mutations) => {
      let shouldReorder = false

      mutations.forEach((mutation) => {
        mutation.addedNodes.forEach((node) => {
          if (node.nodeType === 1 && 
              (node.matches('[data-message-ordering-target="message"]') || 
               node.querySelector('[data-message-ordering-target="message"]'))) {
            shouldReorder = true
          }
        })
      })

      if (shouldReorder) {
        // Longer delay to ensure Turbo has finished processing
        setTimeout(() => this.reorderMessages(), 50)
      }
    })

    observer.observe(this.element, { childList: true, subtree: true })
    this.observer = observer
  }

  setupTurboStreamListeners() {
    // Listen for various Turbo events that might affect message order
    const events = [
      'turbo:before-stream-render',
      'turbo:after-stream-render', 
      'turbo:submit-end',
      'turbo:frame-load'
    ]
    
    events.forEach(eventName => {
      document.addEventListener(eventName, () => {
        setTimeout(() => this.reorderMessages(), 100)
      })
    })

    // Set up periodic reordering as a safety net
    this.setupPeriodicReordering()
  }

  setupPeriodicReordering() {
    // Reorder messages every 2 seconds as a fallback
    this.periodicInterval = setInterval(() => {
      this.reorderMessages()
    }, 2000)
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
    if (this.periodicInterval) {
      clearInterval(this.periodicInterval)
    }
  }

  reorderMessages() {
    const messages = Array.from(this.messageTargets)
    
    if (messages.length === 0) return

    // Debug: Log message timestamps
    console.log('Message timestamps:', messages.map(m => ({
      id: m.id,
      timestamp: m.dataset.createdAt,
      time: new Date(m.dataset.createdAt).getTime()
    })))

    // Sort by timestamp (created_at), then by DOM order as fallback
    messages.sort((a, b) => {
      const timeA = new Date(a.dataset.createdAt).getTime()
      const timeB = new Date(b.dataset.createdAt).getTime()
      
      if (timeA !== timeB) {
        return timeA - timeB
      }
      
      // If timestamps are equal, maintain DOM order
      return Array.from(this.element.children).indexOf(a) - Array.from(this.element.children).indexOf(b)
    })

    // Check if messages are in the correct order
    let needsReordering = false
    const currentOrder = Array.from(this.element.children).filter(child => 
      child.hasAttribute('data-message-ordering-target')
    )
    
    for (let i = 0; i < messages.length; i++) {
      if (currentOrder[i] !== messages[i]) {
        needsReordering = true
        break
      }
    }

    if (needsReordering) {
      console.log('Reordering messages by timestamp')
      console.log('Current order:', currentOrder.map(m => m.id))
      console.log('Correct order:', messages.map(m => m.id))
      
      // Create a document fragment to avoid multiple reflows
      const fragment = document.createDocumentFragment()
      
      // Remove all message elements
      messages.forEach(message => {
        message.remove()
      })
      
      // Add them back in correct order
      messages.forEach(message => {
        fragment.appendChild(message)
      })
      
      // Append the fragment to the container
      this.element.appendChild(fragment)

      // Scroll to bottom after reordering
      setTimeout(() => {
        const messagesContainer = this.element.closest('[data-chat-target="messages"]')
        if (messagesContainer) {
          messagesContainer.scrollTop = messagesContainer.scrollHeight
        }
      }, 10)
    }
  }

  // Add a manual trigger method for debugging
  manualReorder() {
    console.log('Manual reorder triggered')
    this.reorderMessages()
  }

  // Public method to manually trigger reordering
  messageTargetConnected() {
    setTimeout(() => this.reorderMessages(), 50)
  }
}
