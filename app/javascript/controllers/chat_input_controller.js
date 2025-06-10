import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["textarea", "form"]

  connect() {
    this.textareaTarget.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault()
        this.submit()
      }
    })
  }

  submit() {
    if (this.textareaTarget.value.trim()) {
      this.formTarget.requestSubmit()
      this.textareaTarget.value = ""
    }
  }
}
