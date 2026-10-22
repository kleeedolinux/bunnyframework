# Connection takeover contracts (WebSocket). Transport-agnostic: the server adapts its socket.
module Bunny
  abstract class WsTransport
    # Next text message, or nil once the peer closed.
    abstract def receive : String?
    # Thread-safe; false when the socket is gone.
    abstract def send(text : String) : Bool
    abstract def close : Nil
  end

  # Set on a Conn by a plug that wants the connection; the server calls take_over after the handshake.
  abstract class Upgrader
    abstract def take_over(c : Conn, ws : WsTransport) : Nil
  end
end
