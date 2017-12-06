__precompile__()
module Coinigy

  export  CoinigyRestHandler,
          CoinigyWebSocketHandler,
          connect,
          subscribe,
          unsubscribe,
          getUserInfo,
          getActivityLog,
          getNotifications,
          getAccounts,
          getBalances,
          getBalanceHistory,
          getOrders,
          getOrderTypes,
          getAlerts,
          getUserWatchList,
          getNewsFeed,
          getExchanges,
          getMarkets,
          getTradeHistory,
          getAsks,
          getBids,
          getOrders,
          getMarketData,
          getTicker,
          activateTradingKey,
          addOrder

  include("rest_client.jl")
  include("websocket_client.jl")

end
