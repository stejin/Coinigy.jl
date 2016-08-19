module Coinigy

  export  CoinigyHandler,
          coinigy_connect,
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
          getTicker

  export Exchanges, Channels

  include("client.jl")

end
