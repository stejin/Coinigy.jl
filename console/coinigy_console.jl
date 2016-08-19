using ArgParse
using DataFrames
using Coinigy

# Objectes populated by WebApi calls
# Exchanges
# Channels

# Channel managements
subscribe(channel) = Coinigy.subscribe(handler, channel)
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
getOrders(exchange, market) = Coinigy.getOrders(handler, exchange, market)["data"]["orders"]
getMarketData(exchange, market) = Coinigy.getMarketData(handler, exchange, market)["data"]
getTicker(exchange, market) = Coinigy.getTicker(handler, exchange, market)["data"]


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

  coinigy_connect(handler)
  return handler
end

ARGS = ["--config", "config.json", "--forceauth"]
handler = connect(ARGS)
println("Connected")
