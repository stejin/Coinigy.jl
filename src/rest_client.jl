using JSON
using Requests
import Requests: URI, post

type CoinigyRestHandler
  api::Dict
  debug::Bool
  max_attempts::Int

  function CoinigyRestHandler(;
                    public_key = "",
                    private_key = "",
                    debug = false,
                    max_attempts = 6)
      api = Dict("apiKey" => public_key, "apiSecret" => private_key)
      new(api, debug, max_attempts)
  end
end

function getResult(handler, url, data = Dict())
  headers = Dict("Content-Type" => "application/json",
  "X-API-KEY" => handler.api["apiKey"],
  "X-API-SECRET" => handler.api["apiSecret"])
  attempt = 1
  resp = post(url; headers = headers, data = JSON.json(data))
  # Retry if service temporarily not available
  while resp.status == 503 && attempt < handler.max_attempts
    sleep(attempt) #increase wait time by one second for each failed attempt
    attempt += 1
    resp = post(url; headers = headers, data = JSON.json(data))
  end
  if resp.status == 503
    error("Aborting request with url: $url, data: $data after $(handler.max_attempts) attempts")
  elseif resp.status != 200
    error("$(resp.status): Error executing the request with url: $url, data: $data - $resp")
  else
    try
      parsedresp = Requests.json(resp)
      if "error" in keys(parsedresp)
        println("Error parsing response to request with url: $url, data: $data - $(parsedresp["error"])")
      end
      parsedresp
    catch e
      error("Error parsing response to request with url: $url, data: $data - $resp - $parsedresp")
    end
  end
end



getUserInfo(handler::CoinigyRestHandler) = getResult(handler, "https://api.coinigy.com/api/v1/userInfo")
getActivityLog(handler::CoinigyRestHandler) = getResult(handler, "https://api.coinigy.com/api/v1/activity")
getNotifications(handler::CoinigyRestHandler) = getResult(handler, "https://api.coinigy.com/api/v1/pushNotifications")
getAccounts(handler::CoinigyRestHandler) = getResult(handler, "https://api.coinigy.com/api/v1/accounts")
getBalances(handler::CoinigyRestHandler) = getResult(handler, "https://api.coinigy.com/api/v1/balances")
getBalanceHistory(handler::CoinigyRestHandler) = getResult(handler, "https://api.coinigy.com/api/v1/balanceHistory")
getOrders(handler::CoinigyRestHandler) = getResult(handler, "https://api.coinigy.com/api/v1/orders")
getOrderTypes(handler::CoinigyRestHandler) = getResult(handler, "https://api.coinigy.com/api/v1/orderTypes")
getAlerts(handler::CoinigyRestHandler) = getResult(handler, "https://api.coinigy.com/api/v1/alerts")
getUserWatchList(handler) = getResult(handler, "https://api.coinigy.com/api/v1/userWatchList")
getNewsFeed(handler::CoinigyRestHandler) = getResult(handler, "https://api.coinigy.com/api/v1/newsFeed")
getExchanges(handler::CoinigyRestHandler) = getResult(handler, "https://api.coinigy.com/api/v1/exchanges")
getMarkets(handler::CoinigyRestHandler) = getResult(handler, "https://api.coinigy.com/api/v1/markets")
getTradeHistory(handler::CoinigyRestHandler, exchange::String, market::String) = getResult(handler, "https://api.coinigy.com/api/v1/data", Dict("exchange_code" => exchange, "exchange_market" => market, "type" => "history"))
getAsks(handler::CoinigyRestHandler, exchange::String, market::String)  = getResult(handler, "https://api.coinigy.com/api/v1/data", Dict("exchange_code" => exchange, "exchange_market" => market, "type" => "asks"))
getBids(handler::CoinigyRestHandler, exchange::String, market::String)  = getResult(handler, "https://api.coinigy.com/api/v1/data", Dict("exchange_code" => exchange, "exchange_market" => market, "type" => "bids"))
getOrders(handler::CoinigyRestHandler, exchange::String, market::String)  = getResult(handler, "https://api.coinigy.com/api/v1/data", Dict("exchange_code" => exchange, "exchange_market" => market, "type" => "orders"))
getMarketData(handler::CoinigyRestHandler, exchange::String, market::String)  = getResult(handler, "https://api.coinigy.com/api/v1/data", Dict("exchange_code" => exchange, "exchange_market" => market, "type" => "all"))
getTicker(handler::CoinigyRestHandler, exchange::String, market::String)  = getResult(handler, "https://api.coinigy.com/api/v1/ticker", Dict("exchange_code" => exchange, "exchange_market" => market))
activateTradingKey(handler::CoinigyRestHandler, authId::Int) = getResult(handler, "https://api.coinigy.com/api/v1/activateTradingKey", Dict("auth_id" => authId, "auth_trade" => 1))
addOrder(handler::CoinigyRestHandler, authId::Int, exchId::Int, mktId::Int, orderTypeId::Int, priceTypeId::Int, price::Float64, quantity::Float64) = getResult(handler, "https://api.coinigy.com/api/v1/addOrder", Dict("auth_id" => authId, "exch_id" => exchId, "mkt_id" => mktId, "order_type_id" => orderTypeId, "price_type_id" => priceTypeId, "limit_price" => price, "order_quantity" => quantity))
getChannels(handler::CoinigyRestHandler) = getResult(handler, "https://api.coinigy.com/api/v1/channels")
