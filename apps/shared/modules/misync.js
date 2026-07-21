/* apps/shared/modules/misync.js */
import interconnect from '@system.interconnect'

class MiSync {
  constructor() {
    this.connection = null
    this.messageListeners = []
    this.sendQueue = []
    this.isOpen = false
    this.autoInitialize()
  }

  autoInitialize() {
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
        this.isOpen = true
        this.flushQueue()
      }

      this.connection.onclose = (event) => {
        console.log('MiSync connection closed:', event ? event.code : 'unknown')
        this.isOpen = false
      }

      this.connection.onerror = (event) => {
        console.error('MiSync connection error:', event ? event.code : 'unknown')
        this.isOpen = false
      }

      // Check current connection state immediately
      this.connection.getReadyState({
        success: (data) => {
          if (data.status === 1) {
            console.log('MiSync connection already open')
            this.isOpen = true
            this.flushQueue()
          }
        },
        fail: (data, code) => {
          console.warn('MiSync getReadyState fail:', code, data)
        }
      })

    } catch (error) {
      console.error('MiSync initialization error:', error)
    }
  }

  flushQueue() {
    if (this.sendQueue.length > 0) {
      console.log('MiSync flushing send queue of size:', this.sendQueue.length)
      const queue = this.sendQueue
      this.sendQueue = []
      queue.forEach(msg => this.send(msg.command, msg.data))
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
    try {
      if (!this.connection) {
        this.connection = interconnect.instance()
      }
      console.log('MiSync sending command:', command, JSON.stringify(data))
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

  // Backward compatibility: keep initialize as a no-op in case other scripts reference it
  initialize() {
    console.log('MiSync.initialize() is now automated and runs on module load.')
  }
}

export default new MiSync()
