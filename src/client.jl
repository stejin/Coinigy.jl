using DataFrames
using DataFramesIO
using JSON
using Requests
import Requests: URI, post

using DandelionWebSockets
# Explicitly import the callback functions that we're going to add more methods for.
import DandelionWebSockets: on_text, on_binary,
                            state_connecting, state_open, state_closing, state_closed

type CoinigyHandler <: WebSocketHandler
  client::WSClient
  api::Dict
  forceAuthentication::Bool
  stop_channel::Channel{Any}
  debug::Bool
  cid::Int
  requests::Dict

  function CoinigyHandler(;
                    public_key = "",
                    private_key = "",
                    force_authentication = false)
      api = Dict("apiKey" => public_key, "apiSecret" => private_key)
      new(WSClient(), api, force_authentication, Channel{Any}(3), false, 0, Dict())
  end
end

function load_token()
  token = nothing
  if isfile("coinigy.token")
    open("coinigy.token") do f
      token = readall(f)
    end
  end
  return token
end

function save_token(token)
  open("coinigy.token", "w") do f
    write(f, token)
  end
end

function getResult(handler, url, data = Dict())
  headers = Dict("Content-Type" => "application/json",
                  "X-API-KEY" => handler.api["apiKey"],
                  "X-API-SECRET" => handler.api["apiSecret"])
  resp = post(url; headers = headers, data = JSON.json(data))
  parsedresp = Requests.json(resp)
  if resp.status != 200 || "error" in keys(parsedresp)
    error("$(resp.status): Error executing the request: $(parsedresp["error"])")
  end
  parsedresp
end

# These are called when you get text/binary frames, respectively.
on_text(handler::CoinigyHandler, s::UTF8String)         = onMessage(handler, s, false)
on_binary(handler::CoinigyHandler, data::Vector{UInt8}) = onMessage(handler, data, true)

function onMessage(handler::CoinigyHandler, payload, isBinary)
  if handler.debug
    isBinary && println("Binary message received: $(length(payload)) bytes.")
    !isBinary && println("Text message received: $payload.")
  end

  # ping
  if payload == "1"
    return sendMessage(handler, b"2", true)
  end

  try
    responseEventInfo = JSON.parse(payload)

    if "cid" in keys(responseEventInfo)
      handle_command(handler, responseEventInfo)
    end

    if handler.debug
      if length(utf8(payload)) > 2048
        println("Ignoring payload of $(length(utf8(payload))) bytes.")
      else
        println("Data: $responseEventInfo")
      end
    end

    if ("rid" in keys(responseEventInfo)) && (responseEventInfo["rid"] in keys(handler.requests))
      request = handler.requests[responseEventInfo["rid"]]
      handler.debug && println("In response to $(request["eventInfo"])")
      cb = request["callback"]
      cb(handler, responseEventInfo)
    end
  catch e
    println("Error processing payload: $payload: $e")
  end
end

function sendMessage(handler::CoinigyHandler, payload, isBinary)
  handler.debug && println("Sending: $payload")
  isBinary && send_binary(handler.client, payload)
  !isBinary && send_text(handler.client, utf8(payload))
end

function generateCallId(handler::CoinigyHandler)
  handler.cid += 1
  return handler.cid
end

function emitRaw(handler::CoinigyHandler, event, data, callback)
  # Make an event object and send it out
  cid = generateCallId(handler)
  eventInfo = Dict("event" => event, "data" => data, "cid" => cid)
  handler.debug && println("Sending: $eventInfo")

  payload = JSON.json(eventInfo)
  sendMessage(handler, payload, false)
  handler.debug && println("Sent: $payload")

  # Keep reference of the request
  request = Dict("callback" => callback, "eventInfo" => eventInfo)
  handler.requests[cid] = request
  return cid
end

# These are called when the WebSocket state changes.

state_connecting(::CoinigyHandler) = println("State: CONNECTING")

# Called when the connection is open, and ready to send/receive messages.
function state_open(handler::CoinigyHandler)
  println("State: OPEN")

  token = load_token()
  # Try and get a saved token.
  if token == nothing
    token = "ux87psl$(abs(rand(Int)))z8l"
  end

  emitRaw(handler, "#handshake", Dict("authToken" => token), handle_handshake)
end

state_closing(handler::CoinigyHandler) = println("State: CLOSING")
state_closed(handler::CoinigyHandler) = println("State: CLOSED")

function handle_handshake(handler::CoinigyHandler, eventInfo)
  handler.debug && println("HANDSHAKE CALLBACK")
  if handler.forceAuthentication || !eventInfo["data"]["isAuthenticated"]
    emitRaw(handler, "auth", handler.api, handle_auth)
  else
    handle_auth(handler, eventInfo)
  end
end

function handle_auth(handler::CoinigyHandler, eventInfo)
  handler.debug && println("AUTH CALLBACK")
  coinigy(handler)
end

function handle_command(handler::CoinigyHandler, eventInfo)
  handler.debug && println("HANDLE COMMAND")
  # Server told us to do something.
  event = eventInfo["event"]
  cid = eventInfo["cid"]

  if event == "#setAuthToken"
    # Set/save auth token.
    token = eventInfo["data"]["token"]
    save_token(token)
  elseif event == "#publish"
    publish(handler, eventInfo["data"])
  else
    println("Unhandled server event: $eventInfo")
  end
end

function handle_exchanges(handler, eventInfo)
  handler.debug && println("EXCHANGES CALLBACK")
  edata = eventInfo["data"][1]
  global Exchanges = json2df(JSON.json(edata))
  println("Exchanges updated")
  #println("Exchanges: $(json2df(JSON.json(edata)))")
end

function handle_channels(handler, eventInfo)
  handler.debug && println("CHANNEL CALLBACK")
  cdata = eventInfo["data"][1]
  global Channels = json2df(JSON.json(cdata))
  println("Channels updated")
  #println("Got $(length(cdata)) channels.")
  #println("Channels: $(json2df(JSON.json(cdata)))")
end

function handle_subscribe(handler, eventInfo)
  handler.debug && println("SUBSCRIPTION CALLBACK")
  if "rid" in keys(eventInfo)
    println("acked subscription to channel $(handler.requests[eventInfo["rid"]]["eventInfo"]["data"])")
  end
end

function handle_unsubscribe(handler, eventInfo)
  handler.debug && println("UNSUBSCRIBE CALLBACK")
  if "rid" in keys(eventInfo)
    println("acked unsubscription to channel $(handler.requests[eventInfo["rid"]]["eventInfo"]["data"])")
  end
end

function publish(handler, eventInfo)
  pdata = eventInfo["data"]
  println("Publish: $(JSON.json(pdata))")
end

exchanges(handler) = emitRaw(handler, "exchanges", nothing, handle_exchanges)

channels(handler) = emitRaw(handler, "channels", nothing, handle_channels)

function subscribe(handler, channel)
  cid = emitRaw(handler, "#subscribe", channel, handle_subscribe)
  handler.debug && println("Subscribe cid=$cid channel=$channel")
end

function unsubscribe(handler, channel)
  cid = emitRaw(handler, "#unsubscribe", channel, handle_unsubscribe)
  handler.debug && println("Unsubscribe cid=$cid channel=$channel")
end


function coinigy(handler)
  @schedule begin
    exchanges(handler)
    channels(handler)
  end
end

function connect(handler::CoinigyHandler)
  uri = URI("wss://sc-01.coinigy.com:443")
  println("Connecting to $uri")
  wsconnect(handler.client, uri, handler)
end

getUserInfo(handler) = getResult(handler, "https://www.coinigy.com/api/v1/userInfo")
getActivityLog(handler) = getResult(handler, "https://www.coinigy.com/api/v1/activity")
getNotifications(handler) = getResult(handler, "https://www.coinigy.com/api/v1/pushNotifications")
getAccounts(handler) = getResult(handler, "https://www.coinigy.com/api/v1/accounts")
getBalances(handler) = getResult(handler, "https://www.coinigy.com/api/v1/balances")
getBalanceHistory(handler) = getResult(handler, "https://www.coinigy.com/api/v1/balanceHistory")
getOrders(handler) = getResult(handler, "https://www.coinigy.com/api/v1/orders")
getOrderTypes(handler) = getResult(handler, "https://www.coinigy.com/api/v1/orderTypes")
getAlerts(handler) = getResult(handler, "https://www.coinigy.com/api/v1/alerts")
getUserWatchList(handler) = getResult(handler, "https://www.coinigy.com/api/v1/userWatchList")
getNewsFeed(handler) = getResult(handler, "https://www.coinigy.com/api/v1/newsFeed")
getExchanges(handler) = getResult(handler, "https://www.coinigy.com/api/v1/exchanges")
getMarkets(handler) = getResult(handler, "https://www.coinigy.com/api/v1/markets")
getTradeHistory(handler, exchange, market) = getResult(handler, "https://www.coinigy.com/api/v1/data", Dict("exchange_code" => exchange, "exchange_market" => market, "type" => "history"))
getAsks(handler, exchange, market)  = getResult(handler, "https://www.coinigy.com/api/v1/data", Dict("exchange_code" => exchange, "exchange_market" => market, "type" => "asks"))
getBids(handler, exchange, market)  = getResult(handler, "https://www.coinigy.com/api/v1/data", Dict("exchange_code" => exchange, "exchange_market" => market, "type" => "bids"))
getOrders(handler, exchange, market)  = getResult(handler, "https://www.coinigy.com/api/v1/data", Dict("exchange_code" => exchange, "exchange_market" => market, "type" => "orders"))
getMarketData(handler, exchange, market)  = getResult(handler, "https://www.coinigy.com/api/v1/data", Dict("exchange_code" => exchange, "exchange_market" => market, "type" => "all"))
getTicker(handler, exchange, market)  = getResult(handler, "https://www.coinigy.com/api/v1/ticker", Dict("exchange_code" => exchange, "exchange_market" => market))
