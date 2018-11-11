using ArgParse
using Coinigy

# Objectes populated by WebApi calls
# Exchanges
# Channels

# Channel managements
subscribe(channel, publish_callback) = Coinigy.subscribe(handler, channel, publish_callback)
unsubscribe(channel) = Coinigy.unsubscribe(handler, channel)

# REST calls
getUserInfo() = Coinigy.getUserInfo(handler)["data"]
getActivityLog() = Coinigy.getActivityLog(handler)["data"]
getNotifications() = Coinigy.getNotifications(handler)["data"]
getAccounts() = Coinigy.getAccounts(handler)["data"]
getBalances() = Coinigy.getBalances(handler)["data"]
getBalanceHistory() = Coinigy.getBalanceHistory(handler)["data"]
getOrders() = Coinigy.getOrders(handler)["data"]
getOrderTypes() = Coinigy.getOrderTypes(handler)["data"]
getAlerts() = Coinigy.getAlerts(handler)["data"]
getUserWatchList() = Coinigy.getUserWatchList(handler)["data"]
getNewsFeed() = Coinigy.getNewsFeed(handler)["data"]
getExchanges() = Coinigy.getExchanges(handler)["data"]
getMarkets() = Coinigy.getMarkets(handler)["data"]
getTradeHistory(exchange, market) = Coinigy.getTradeHistory(handler, exchange, market)["data"]["history"]
getAsks(exchange, market) = Coinigy.getAsks(handler, exchange, market)["data"]["asks"]
getBids(exchange, market) = Coinigy.getBids(handler, exchange, market)["data"]["bids"]
getOrders(exchange, market) = Coinigy.getOrders(handler, exchange, market)["data"]
getMarketData(exchange, market) = Coinigy.getMarketData(handler, exchange, market)["data"]
getTicker(exchange, market) = Coinigy.getTicker(handler, exchange, market)["data"]

function submit_order(handler::CoinigyHandler, accounts::Array{Dict{String,Any}}, markets::Array{Dict{String,Any}}, trade)
  market = first(filter(m -> m["exch_code"] == trade.Market.Exchange.Code && m["mkt_name"] == trade.Market.CoinigyCode, markets))
  account = first(filter(a -> a["exch_id"] == market["exch_id"], accounts))
  if !Bool(parse(Int, account["exch_trade_enabled"]))
    println("Trading on exchange $(exchange["exch_code"]) not enabled.")
    return
  end
  println("Submitting Order to Coinigy")
  result = Coinigy.addOrder(handler, account["auth_id"], market["exch_id"], market["mkt_id"], ifelse(trade.Type == BuyOrder, 1, 2), 3, trade.Price, trade.Notional)
  @show result
  (first(result["notifications"])["notification_style"] == "success") && (return result["data"]["internal_order_id"])
  nothing
end

function get_order_book(handler::CoinigyHandler)
  markets = getMarkets()
  result = Array{Dict{String,Any}}(length(markets))
  @sync begin
    for i in 1:length(markets)
      @async begin
        m = markets[i]
        exchange = m["exch_code"]
        market = m["mkt_name"]
        println("Sending request for: Exchange: $exchange, Market: $market")
        orderbook = get_orders(handler, exchange, market)
        bids = []
        haskey(orderbook, "bids") && (bids = orderbook["bids"])
        map(b -> b["ordertype"] = "Buy", bids)
        asks = []
        haskey(orderbook, "asks") && (asks = orderbook["asks"])
        map(a -> a["ordertype"] = "Sell", asks)
        println("Response received for: Exchange: $exchange, Market: $market, Bids: $(size(bids, 1)), Asks: $(size(asks, 1))")
        for orders in Array[bids, asks]
          map(o -> o["price"] = parse(Float64, o["price"]), orders)
          map(o -> o["total"] = parse(Float64, o["total"]), orders)
          map(o -> o["quantity"] = parse(Float64, o["quantity"]), orders)
          map(o -> o["timestamp"] = now(), orders)
        end
        result[i] = Dict("exchange" => exchange, "market" => market, "bids" => bids, "asks" => asks)
      end
    end
  end
  result
end

function update_order_book(orders::Array{Dict{String,Any}}, data::Dict{String,Any}; debug = false)
  m = parse_order_channel_message(ascii(data["channel"]), data["data"])
  debug && (@show m)
  channel = m["channel"]
  bids = m["bids"]
  asks = m["asks"]
  element = first(filter(o -> o["channel"] == channel, orders))
  !isempty(bids) && (element["bids"] = bids)
  !isempty(asks) && (element["asks"] = asks)
end

function parse_order_channel_message(channel::String, orderbook::Array{Dict{String,Any}})
  orders = []
  map(o -> push!(orders,
    Dict("ordertype" => o["ordertype"],
         "price"     => parse(Float64, "$(o["price"])"),
         "total"     => parse(Float64, "$(o["total"])"),
         "quantity"  => parse(Float64, "$(o["quantity"])"),
         "timestamp" => now()
    )), orderbook)
  bids = filter(o -> o["ordertype"] == "Buy", orders)
  asks = filter(o -> o["ordertype"] == "Sell", orders)
  Dict("channel" => channel, "bids" => bids, "asks" => asks)
end


function connect(args)

  a = ArgParseSettings(description = "Example: --config config.json --forceauth")

  @add_arg_table a begin
    "--out"
    help = "output file"
    default = "stdout"
    "--mode"
    help = "output mode"
    range_tester = (x->x=="csv"||x=="std")
    "--api"
    help = "api key/secret"
    nargs = 2
    metavar = "value"
    "--forceauth"
    help = "force authentication"
    action = :store_true
    "--trades"
    help = "trade channels, eg TRADE-OK--BTC--CNY"
    nargs = '*'
    default = nothing
    "--config"
    help = "config file"
    default = nothing
  end

  parsed_args = parse_args(args, a)

  if parsed_args["config"] != nothing
    config_dict = JSON.parsefile(parsed_args["config"])
    config_dict["forceauth"] = parsed_args["forceauth"]
  else
    config_dict = parsed_args
  end

  println("Parsed args:")
  for (key, val) in config_dict
    println(" $key => $(repr(val))")
  end


  outfile = config_dict["out"]
  # println("Out file: $outfile")

  handler = CoinigyHandler(public_key = config_dict["api"][1], private_key = config_dict["api"][2], force_authentication = config_dict["forceauth"])

  println(handler.api)

  Coinigy.connect(handler)
  return handler
end

ARGS = ["--config", "config.json", "--forceauth"]
handler = connect(ARGS)
# handler.debug = true
println("Connected")
