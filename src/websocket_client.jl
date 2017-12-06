using JSON
using DandelionWebSockets
# Explicitly import the callback functions that we're going to add more methods for.
import DandelionWebSockets: on_text, on_binary,
state_connecting, state_open, state_closing, state_closed

type CoinigyWebSocketHandler <: WebSocketHandler
    client::WSClient
    api::Dict
    force_authentication::Bool
    token::String
    stop_channel::Channel{Any}
    debug::Bool
    cid::Int
    requests::Dict
    channel_callbacks::Dict
    max_attempts::Int
    Channels::Any
    Exchanges::Any

    function CoinigyWebSocketHandler(;
        public_key = "",
        private_key = "",
        token = load_token(),
        force_authentication = false)
        api = Dict("apiKey" => public_key, "apiSecret" => private_key)
        new(WSClient(), api, force_authentication, token, Channel{Any}(3), false, 0, Dict(), Dict(), 6)
    end
end

function load_token()
  token = ""
  if isfile("coinigy.token")
    open("coinigy.token") do f
      token = readstring(f)
    end
  end
  return token
end

function save_token(handler::CoinigyWebSocketHandler, token::String)
  handler.token = token
  open("coinigy.token", "w") do f
    write(f, token)
  end
end

# These are called when you get text/binary frames, respectively.
on_text(handler::CoinigyWebSocketHandler, s::String)         = onMessage(handler, s, false)
on_binary(handler::CoinigyWebSocketHandler, data::Vector{UInt8}) = onMessage(handler, data, true)

function onMessage(handler::CoinigyWebSocketHandler, payload, isBinary::Bool)
  if handler.debug
    isBinary && println("Binary message received: $(length(payload)) bytes.")
    !isBinary && println("Text message received: $payload.")
  end

  # ping
  if payload == "#1"
    return sendMessage(handler, b"#2", true)
  end

  try
    responseEventInfo = JSON.parse(payload)

    if ("rid" in keys(responseEventInfo)) && (responseEventInfo["rid"] in keys(handler.requests))
      request = handler.requests[responseEventInfo["rid"]]
      handler.debug && println("In response to $(request["eventInfo"])")
      cb = request["callback"]
      cb(handler, responseEventInfo)
    else
      handle_command(handler, responseEventInfo)
    end

  catch e
    error("Error processing payload: $payload: $e")
  end
end

function sendMessage(handler::CoinigyWebSocketHandler, payload, isBinary::Bool)
  handler.debug && println("Sending: $payload")
  isBinary && send_binary(handler.client, payload)
  !isBinary && send_text(handler.client, String(payload))
end

function generateCallId(handler::CoinigyWebSocketHandler)
  handler.cid += 1
  return handler.cid
end

function emitRaw(handler::CoinigyWebSocketHandler, event, data, callback, extra_infos = nothing)
  # Make an event object and send it out
  cid = generateCallId(handler)
  eventInfo = Dict("event" => event, "data" => data, "cid" => cid)
  handler.debug && println("Sending: $eventInfo")

  payload = JSON.json(eventInfo)
  sendMessage(handler, payload, false)
  handler.debug && println("Sent: $payload")

  # Keep reference of the request
  request = Dict("callback" => callback, "eventInfo" => eventInfo, "extra_infos" => extra_infos)
  handler.requests[cid] = request
  return cid
end

# These are called when the WebSocket state changes.

state_connecting(::CoinigyWebSocketHandler) = println("State: CONNECTING")

# Called when the connection is open, and ready to send/receive messages.
function state_open(handler::CoinigyWebSocketHandler)
  println("State: OPEN")

  if isempty(handler.token)
    handler.token = "ux87psl$(abs(rand(Int)))z8l"
  end

  emitRaw(handler, "#handshake", Dict("authToken" => handler.token), handle_handshake)
end

state_closing(handler::CoinigyWebSocketHandler) = println("State: CLOSING")
state_closed(handler::CoinigyWebSocketHandler) = println("State: CLOSED")

function handle_handshake(handler::CoinigyWebSocketHandler, eventInfo)
  handler.debug && println("HANDSHAKE CALLBACK")
  if handler.force_authentication || !eventInfo["data"]["isAuthenticated"]
    emitRaw(handler, "auth", handler.api, handle_auth)
  else
    handle_auth(handler, eventInfo)
  end
end

function handle_auth(handler::CoinigyWebSocketHandler, eventInfo)
  handler.debug && println("AUTH CALLBACK")
  coinigy(handler)
end

function handle_command(handler::CoinigyWebSocketHandler, eventInfo)
  handler.debug && println("HANDLE COMMAND")
  # Server told us to do something.
  event = eventInfo["event"]

  if event == "#setAuthToken"
    # Set/save auth token.
    token = eventInfo["data"]["token"]
    save_token(handler, token)
  elseif event == "#removeAuthToken"
      # Set/save auth token.
      token = ""
      save_token(handler, token)
  elseif event == "#publish"
    channel = eventInfo["data"]["channel"]
    cb = handler.channel_callbacks[channel]
    cb(eventInfo["data"])
    #publish(handler, eventInfo["data"])
  elseif event == "NOTIFICATION"
    println("Notification received")
    println(eventInfo["data"])
  else
    println("Unhandled server event: $eventInfo")
  end
end

function handle_exchanges(handler::CoinigyWebSocketHandler, eventInfo)
  handler.debug && println("EXCHANGES CALLBACK")
  edata = eventInfo["data"][1]
  handler.Exchanges = edata
  println("Exchanges updated")
end

function handle_channels(handler::CoinigyWebSocketHandler, eventInfo)
  handler.debug && println("CHANNEL CALLBACK")
  cdata = eventInfo["data"][1]
  handler.Channels = cdata
  println("Channels updated")
end

function handle_subscribe(handler::CoinigyWebSocketHandler, eventInfo)
  handler.debug && println("SUBSCRIPTION CALLBACK")
  if "rid" in keys(eventInfo)
    channel = handler.requests[eventInfo["rid"]]["eventInfo"]["data"]
    callback = handler.requests[eventInfo["rid"]]["extra_infos"]
    handler.channel_callbacks[channel] = callback
    println("acked subscription to channel $channel")
  end
end

function handle_unsubscribe(handler::CoinigyWebSocketHandler, eventInfo)
  handler.debug && println("UNSUBSCRIBE CALLBACK")
  if "rid" in keys(eventInfo)
    println("acked unsubscription to channel $(handler.requests[eventInfo["rid"]]["eventInfo"]["data"])")
  end
end

function publish(data)
  println("Publish: $(JSON.json(data))")
end

exchanges(handler::CoinigyWebSocketHandler) = emitRaw(handler, "exchanges", nothing, handle_exchanges)

channels(handler::CoinigyWebSocketHandler) = emitRaw(handler, "channels", nothing, handle_channels)

function subscribe(handler::CoinigyWebSocketHandler, channel::String, publish_callback::Function = publish)
  cid = emitRaw(handler, "#subscribe", channel, handle_subscribe, publish_callback)
  handler.debug && println("Subscribe cid=$cid channel=$channel")
end

function unsubscribe(handler::CoinigyWebSocketHandler, channel::String)
  cid = emitRaw(handler, "#unsubscribe", channel, handle_unsubscribe)
  handler.debug && println("Unsubscribe cid=$cid channel=$channel")
end


function coinigy(handler::CoinigyWebSocketHandler)
  @schedule begin
    exchanges(handler)
    channels(handler)
  end
end

function connect(handler::CoinigyWebSocketHandler)
  uri = URI("wss://sc-02.coinigy.com:443/socketcluster/")
  println("Connecting to $uri")
  wsconnect(handler.client, uri, handler)
end
