import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages"]

  connect() {
    // Scroll to bottom on initial load if there are messages
    this.scrollToBottom()
    
    // Track active placeholders and their timeouts
    this.placeholderTimeouts = new Map()
    
    // Listen for new messages being added
    this.element.addEventListener("turbo:before-stream-render", (event) => {
      // Store scroll position before new content is added
      this.wasScrolledToBottom = this.isScrolledToBottom()
    })
    
    this.element.addEventListener("turbo:stream-render", (event) => {
      // If user was at bottom before new message, keep them at bottom
      if (this.wasScrolledToBottom) {
        this.scrollToBottom()
      }
      
      // Check for new placeholders and set timeouts
      this.managePlaceholderTimeouts()
    })
  }

  managePlaceholderTimeouts() {
    // Find all placeholder elements
    const placeholders = this.messagesTarget.querySelectorAll('[id^="llm_placeholder_"]:has(.animate-spin)')
    
    placeholders.forEach(placeholder => {
      const placeholderId = placeholder.id
      
      // Skip if we already have a timeout for this placeholder
      if (this.placeholderTimeouts.has(placeholderId)) {
        return
      }
      
      // Set timeout for 60 seconds (adjust as needed)
      const timeoutId = setTimeout(() => {
        this.handlePlaceholderTimeout(placeholderId)
      }, 60000)
      
      this.placeholderTimeouts.set(placeholderId, timeoutId)
      console.log(`Set timeout for placeholder: ${placeholderId}`)
    })
  }

  handlePlaceholderTimeout(placeholderId) {
    const placeholder = document.getElementById(placeholderId)
    if (placeholder && placeholder.querySelector('.animate-spin')) {
      console.log(`Placeholder timeout reached: ${placeholderId}`)
      
      // Replace the spinning content with an error message
      const errorContent = `
        <div class="flex items-center space-x-2">
          <span class="text-red-500">⚠️</span>
          <div>
            <div class="text-sm text-red-600">Response timed out</div>
            <button onclick="window.location.reload()" class="text-xs text-blue-600 hover:text-blue-800 underline">
              Refresh page to retry
            </button>
          </div>
        </div>
      `
      
      const contentDiv = placeholder.querySelector('.bg-gray-200')
      if (contentDiv) {
        contentDiv.innerHTML = errorContent
        contentDiv.classList.add('bg-red-50', 'border', 'border-red-200')
        contentDiv.classList.remove('bg-gray-200')
      }
    }
    
    // Clean up the timeout
    this.placeholderTimeouts.delete(placeholderId)
  }

  disconnect() {
    // Clean up any remaining timeouts when controller is disconnected
    this.placeholderTimeouts.forEach(timeoutId => clearTimeout(timeoutId))
    this.placeholderTimeouts.clear()
  }

  isScrolledToBottom() {
    const threshold = 100 // px from bottom to consider "at bottom"
    return (this.messagesTarget.scrollTop + this.messagesTarget.clientHeight) >= 
           (this.messagesTarget.scrollHeight - threshold)
  }

  scrollToBottom() {
    requestAnimationFrame(() => {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    })
  }

  // Method to manually scroll to bottom (can be called from UI)
  scrollToBottomManually() {
    this.scrollToBottom()
  }
}