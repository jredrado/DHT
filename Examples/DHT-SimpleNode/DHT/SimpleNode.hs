{-|
Stability : experimental

Run a DHT computation using "DHT.SimpleNode.Logger", "DHT.SimpleNode.Messaging", "DHT.SimpleNode.RoutingTable"
and "DHT.SimpleNode.ValueStore" for stdout logging, simple UDP messaging a wrapped "DHT.Routing" routing table
and an in-memory hashmap value store.
-}
module DHT.SimpleNode
  ( mkSimpleNodeConfig
  , newSimpleNode
  )
  where

import           Control.Concurrent
import           Data.Time.Clock.POSIX
import           System.Random

import DHT
import DHT.Address
import DHT.Contact
import DHT.ID
import DHT.Types

import DHT.SimpleNode.Messaging
import DHT.SimpleNode.RoutingTable
import DHT.SimpleNode.ValueStore

import Control.Monad

mkSimpleNodeConfig
  :: Address
  -> Int
  -> LoggingOp IO
  -> Maybe Address
  -> IO (DHTConfig DHT IO)
mkSimpleNodeConfig ourAddr hashSize logging mBootstrapAddr = do
  now          <- timeF
  routingTable <- newSimpleRoutingTable maxBucketSize ourID now hashSize
  valueStore   <- newSimpleValueStore
  messaging    <- newSimpleMessaging hashSize (maxPortLength,ourAddr)

  let ops = DHTOp { _dhtOpTimeOp         = timeF
                  , _dhtOpRandomIntOp    = randF
                  , _dhtOpMessagingOp    = messaging
                  , _dhtOpRoutingTableOp = routingTable
                  , _dhtOpValueStoreOp   = valueStore
                  , _dhtOpLoggingOp      = logging
                  }
  return $ DHTConfig ops ourAddr hashSize mBootstrapAddr
  where
    timeF :: IO Time
    timeF = round <$> getPOSIXTime

    randF :: IO Int
    randF = randomRIO (0,maxBound)

    ourID = mkID ourAddr hashSize

    maxPortLength = 5

    maxBucketSize = 8

-- | Start a new node with some configuration.
-- - Will handle incoming messages for the duration of the given program.
-- Continuing communication after we reach the end of our own DHT computation must be programmed explicitly.
newSimpleNode :: DHTConfig DHT IO
              -> DHT IO a
              -> IO (Either DHTError a)
newSimpleNode dhtConfig dht = do
  forkIO $ void $ startMessaging dhtConfig
  runDHT dhtConfig $ bootstrap >> dht

