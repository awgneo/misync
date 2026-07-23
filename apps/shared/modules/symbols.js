/* apps/shared/modules/symbols.js */
import file from '@system.file'

import MiSync from './sync.js'

// Safe cross-platform base64 to Uint8Array decoder
function base64ToUint8Array(base64) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  const lookup = new Uint8Array(256)
  for (let i = 0; i < chars.length; i++) {
    lookup[chars.charCodeAt(i)] = i
  }
  
  const len = base64.length
  let bufferLength = len * 0.75
  if (base64[len - 1] === '=') {
    bufferLength--
    if (base64[len - 2] === '=') {
      bufferLength--
    }
  }
  
  const arrayBuffer = new ArrayBuffer(bufferLength)
  const bytes = new Uint8Array(arrayBuffer)
  let p = 0
  for (let i = 0; i < len; i += 4) {
    const encoded1 = lookup[base64.charCodeAt(i)]
    const encoded2 = lookup[base64.charCodeAt(i + 1)]
    const encoded3 = lookup[base64.charCodeAt(i + 2)]
    const encoded4 = lookup[base64.charCodeAt(i + 3)]
    
    bytes[p++] = (encoded1 << 2) | (encoded2 >> 4)
    if (p < bufferLength) {
      bytes[p++] = ((encoded2 & 15) << 4) | (encoded3 >> 2)
    }
    if (p < bufferLength) {
      bytes[p++] = ((encoded3 & 3) << 6) | (encoded4 & 63)
    }
  }
  return bytes
}

class MiSymbols {
  constructor() {
    this.pending = {}
    this.initialized = false
  }

  ensureInitialized() {
    if (this.initialized) return
    this.initialized = true

    MiSync.onMessage((payload) => {
      if (payload.symbol && payload.name) {
        const name = payload.name
        const base64Data = payload.symbol
        const cacheUri = `internal://cache/symbols/${name}.png`

        file.mkdir({
          uri: 'internal://cache/symbols/',
          recursive: true,
          complete: () => {
            try {
              const bytes = base64ToUint8Array(base64Data)

              file.writeArrayBuffer({
                uri: cacheUri,
                buffer: bytes,
                success: () => {
                  console.log(`Successfully cached symbol: ${name}`)
                  if (this.pending[name]) {
                    this.pending[name].forEach(cb => cb(cacheUri))
                    delete this.pending[name]
                  }
                },
                fail: (err, code) => {
                  console.error(`Failed to write symbol ${name} to cache. Code: ${code}, err: ${err}`)
                }
              })
            } catch (err) {
              console.error(`Error decoding symbol ${name}:`, err)
            }
          }
        })
      }
    })
  }

  get(name, callback) {
    if (!name) return

    this.ensureInitialized()

    const cacheUri = `internal://cache/symbols/${name}.png`

    file.access({
      uri: cacheUri,
      success: () => {
        // Cache hit
        callback(cacheUri)
      },
      fail: () => {
        // Cache miss
        if (!this.pending[name]) {
          this.pending[name] = [callback]
          MiSync.send('getSymbol', { name })
        } else {
          this.pending[name].push(callback)
        }
      }
    })
  }
}

export default new MiSymbols()
