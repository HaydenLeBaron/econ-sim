// Import Phoenix and LiveView from separate script tags (loaded as globals via importmap)
import {Socket} from "/assets/phoenix.min.js"
import {LiveSocket} from "/assets/phoenix_live_view.min.js"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})
liveSocket.connect()
window.liveSocket = liveSocket
