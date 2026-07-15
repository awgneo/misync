/* apps/shared/modules/misync.js */
import interconnect from '@system.interconnect'

class MiSync {
  constructor() {
    this.connection = null
    this.messageListeners = []
  }

  initialize(options = {}) {
    const { onOpen, onClose, onError } = options
    try {
      this.connection = interconnect.instance()

      this.connection.onmessage = (event) => {
        try {
          const payload = JSON.parse(event.data)
          this.messageListeners.forEach(listener => listener(payload))
        } catch (error) {
          console.error('MiSync JSON parse error:', error)
        }
      }

      this.connection.onopen = (event) => {
        console.log('MiSync connection opened')
        if (onOpen) onOpen(event)
      }

      this.connection.onclose = (event) => {
        console.log('MiSync connection closed:', event ? event.code : 'unknown')
        if (onClose) onClose(event)
      }

      this.connection.onerror = (event) => {
        console.error('MiSync connection error:', event ? event.code : 'unknown')
        if (onError) onError(event)
      }
    } catch (error) {
      console.error('MiSync initialization error:', error)
    }
  }

  // Subscribe to incoming messages
  onMessage(listener) {
    this.messageListeners.push(listener)
    return () => {
      this.messageListeners = this.messageListeners.filter(l => l !== listener)
    }
  }

  // Unified send command
  send(command, data = {}) {
    if (!this.connection) {
      console.warn('MiSync connection not initialized.')
      return
    }
    try {
      this.connection.send({
        data: { command, ...data },
        fail: (response, code) => {
          console.error(`Send failed. Code: ${code}, Detail: ${response}`)
        }
      })
    } catch (error) {
      console.error('MiSync send error:', error)
    }
  }
}

export default new MiSync()
