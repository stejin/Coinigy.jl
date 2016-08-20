# Coinigy.jl
Call Coinigy REST and WebSockets API from Julia

## Usage
Create an instance of `CoinigyHandler` and use it to call REST or WebSocket methods.

```
using Coinigy

handler = CoinigyHandler(public_key = "public key", private_key = "private key", force_authentication = true)
Coinigy.connect(handler)

# Wait for connection to complete

# Exchanges
Exchanges

# channels
Channels

markets = getMarkets(handler)["data"]

subscribe(handler, "TICKER")

```

For more usage examples see console/coinigy_console.jl
