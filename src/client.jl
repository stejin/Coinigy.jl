using JSON
using Requests
import Requests: URI, post

type CoinigyHandler
  base_url::String
  api::Dict
  debug::Bool
  max_attempts::Int

  function CoinigyHandler(;
                    base_url = "https://api.coinigy.com/api/v1",
                    public_key = "",
                    private_key = "",
                    debug = false,
                    max_attempts = 6)
      api = Dict("apiKey" => public_key, "apiSecret" => private_key)
      endswith(base_url, "/") && (base_url = chop(base_url))
      new(base_url, api, debug, max_attempts)
  end
end

function getResult(handler::CoinigyHandler, url::String, data = Dict())
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
      # return Array{Dict}
      return map(d -> d, parsedresp["data"])
    catch e
      error("Error parsing response to request with url: $url, data: $data - $resp - $parsedresp")
    end
  end
end



getUserInfo(handler::CoinigyHandler) = getResult(handler, "$(handler.base_url)/userInfo")
getActivityLog(handler::CoinigyHandler) = getResult(handler, "$(handler.base_url)/activity")
getNotifications(handler::CoinigyHandler) = getResult(handler, "$(handler.base_url)/pushNotifications")
getAccounts(handler::CoinigyHandler) = getResult(handler, "$(handler.base_url)/accounts")
getBalances(handler::CoinigyHandler) = getResult(handler, "$(handler.base_url)/balances")
getBalanceHistory(handler::CoinigyHandler) = getResult(handler, "$(handler.base_url)/balanceHistory")
getOrders(handler::CoinigyHandler) = getResult(handler, "$(handler.base_url)/orders")
getOrderTypes(handler::CoinigyHandler) = getResult(handler, "$(handler.base_url)/orderTypes")
getAlerts(handler::CoinigyHandler) = getResult(handler, "$(handler.base_url)/alerts")
getUserWatchList(handler) = getResult(handler, "$(handler.base_url)/userWatchList")
getNewsFeed(handler::CoinigyHandler) = getResult(handler, "$(handler.base_url)/newsFeed")
getExchanges(handler::CoinigyHandler) = getResult(handler, "$(handler.base_url)/exchanges")
getMarkets(handler::CoinigyHandler) = getResult(handler, "$(handler.base_url)/markets")
getTradeHistory(handler::CoinigyHandler, exchange::String, market::String) = getResult(handler, "$(handler.base_url)/data", Dict("exchange_code" => exchange, "exchange_market" => market, "type" => "history"))
getAsks(handler::CoinigyHandler, exchange::String, market::String)  = getResult(handler, "$(handler.base_url)/data", Dict("exchange_code" => exchange, "exchange_market" => market, "type" => "asks"))
getBids(handler::CoinigyHandler, exchange::String, market::String)  = getResult(handler, "$(handler.base_url)/data", Dict("exchange_code" => exchange, "exchange_market" => market, "type" => "bids"))
getOrders(handler::CoinigyHandler, exchange::String, market::String)  = getResult(handler, "$(handler.base_url)/data", Dict("exchange_code" => exchange, "exchange_market" => market, "type" => "orders"))
getMarketData(handler::CoinigyHandler, exchange::String, market::String)  = getResult(handler, "$(handler.base_url)/data", Dict("exchange_code" => exchange, "exchange_market" => market, "type" => "all"))
getTicker(handler::CoinigyHandler, exchange::String, market::String)  = getResult(handler, "$(handler.base_url)/ticker", Dict("exchange_code" => exchange, "exchange_market" => market))
activateTradingKey(handler::CoinigyHandler, authId) = getResult(handler, "$(handler.base_url)/activateTradingKey", Dict("auth_id" => authId, "auth_trade" => 1))
addOrder(handler::CoinigyHandler, authId, exchId, mktId, orderTypeId, priceTypeId, price, quantity) = getResult(handler, "$(handler.base_url)/addOrder", Dict("auth_id" => authId, "exch_id" => exchId, "mkt_id" => mktId, "order_type_id" => orderTypeId, "price_type_id" => priceTypeId, "limit_price" => price, "order_quantity" => quantity))
