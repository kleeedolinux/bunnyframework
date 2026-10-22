# 0003 - Kestrel as HTTP/WebSocket transport
Status: accepted
Context: A hand-written socket server cannot match Kestrel's maturity and speed. Alice cannot add a FrameworkReference, but can use NuGet packages. The ASP.NET Core shared runtime may be absent.
Decision: `proxy` (BunnyServer) uses NuGet `Microsoft.AspNetCore.Server.Kestrel`, `Hosting`, `WebSockets` 2.3.0. Kestrel only moves bytes; each request becomes a `Bunny::Conn` run through the endpoint. WebSockets reach core through the transport-agnostic `Bunny::WsTransport`/`Bunny::Upgrader` contracts. Everything above the transport stays pure Alice.
Consequences: Kestrel 2.3 (netstandard2.0) instead of the latest in-box Kestrel; no C# glue; the transport can be swapped without touching core.
