# Coinigy.jl
Call Coinigy REST and WebSockets API from Julia

## Usage
Create an instance of `CoinigyHandler` and use it to call REST or WebSocket methods.

```
using Coinigy

handler = CoinigyHandler(public_key = "public key", private_key = "private key", force_authentication = true)
Coinigy.connect(handler)

# Wait for connection to complete

# Exchanges - retrieved via WebSockets API on connect
Exchanges

# Channels - retrieved via WebSockets API on connect
Channels

# Get list of markets via REST call
markets = getMarkets(handler)["data"]

# Subscribe to 'TICKER' channel via WebSockets API

print_ticker(data) = println(data)

subscribe(handler, "TICKER", print_ticker)

```

For more usage examples see console/coinigy_console.jl
