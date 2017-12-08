__precompile__()
module Coinigy

  export  CoinigyHandler,
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

  include("client.jl")

end
