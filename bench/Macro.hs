{-# OPTIONS_GHC -fno-cse -fno-ignore-asserts #-}
module Macro
  ( benchmarks -- :: IO ()
  ) where

import qualified Macro.Types     as Types
import qualified Macro.MemSize
import           Macro.DeepSeq ()
import qualified Macro.Load as Load

import qualified Macro.ReadShow  as ReadShow
import qualified Macro.PkgBinary as PkgBinary
import qualified Macro.PkgCereal as PkgCereal
import qualified Macro.PkgAesonGeneric as PkgAesonGeneric
import qualified Macro.PkgAesonTH as PkgAesonTH
--import qualified Macro.PkgMsgpack as PkgMsgpack
import qualified Macro.CBOR as CBOR

import Criterion.Main

import Data.Int
import qualified Data.ByteString.Lazy   as BS
import qualified Codec.Compression.GZip as GZip
import Control.DeepSeq

benchmarks :: IO ()
benchmarks = defaultMain macrobenchmarks

readBigTestData :: IO [Types.GenericPackageDescription]
readBigTestData = do
    Right pkgs_ <- fmap (Load.readPkgIndex . GZip.decompress)
                        (BS.readFile "bench/00-index.tar.gz")
    let tstdata  = take 100 pkgs_
    return tstdata

macrobenchmarks :: [Benchmark]
macrobenchmarks =
  [ env readBigTestData $ \tstdata ->
    bgroup "reference"
      [ bench "deepseq" (whnf rnf tstdata)
      , bench "memSize" (whnf (flip Macro.MemSize.memSize 0) tstdata)
      ]

  , env readBigTestData $ \tstdata ->
    bgroup "encoding"
      [ bench "binary"        (whnf perfEncodeBinary       tstdata)
      , bench "cereal"        (whnf perfEncodeCereal       tstdata)
      , bench "aeson generic" (whnf perfEncodeAesonGeneric tstdata)
      , bench "aeson TH"      (whnf perfEncodeAesonTH      tstdata)
      , bench "read/show"     (whnf perfEncodeReadShow     tstdata)
--      , bench "msgpack lib"   (whnf perfEncodeMsgpack      tstdata)
--      , bench "new msgpack"   (whnf perfEncodeNewMsgPack   tstdata)
      , bench "cbor"          (whnf perfEncodeCBOR         tstdata)
      ]

  , env readBigTestData $ \tstdata ->
    bgroup "decoding whnf"
      [ env (return $ PkgBinary.serialise tstdata) $ \tstdataB ->
        bench "binary"        (whnf perfDecodeBinary       tstdataB)

      , env (return $ PkgCereal.serialise tstdata) $ \tstdataC ->
        bench "cereal"        (whnf perfDecodeCereal       tstdataC)

      , env (return $ PkgAesonTH.serialise tstdata) $ \tstdataA ->
        bgroup "aeson"
          [ bench "generic"   (whnf perfDecodeAesonGeneric tstdataA)
          , bench "TH"        (whnf perfDecodeAesonTH      tstdataA)
          ]

      , env (return $ ReadShow.serialise tstdata) $ \tstdataS ->
        bench "read/show"     (whnf perfDecodeReadShow     tstdataS)

--      , bench "msgpack lib"   (whnf perfDecodeMsgpack      tstdataM)

--      , env (return $ NewMsgpack.serialise tstdata) $ \tstdataN ->
--        bench "new msgpack"   (whnf perfDecodeNewMsgPack   tstdataN)

      , env (return $ CBOR.serialise tstdata) $ \tstdataR ->
        bench "cbor"   (whnf perfDecodeCBOR                tstdataR)
      ]

  , env readBigTestData $ \tstdata ->
    bgroup "decoding nf"
      [ env (return $ PkgBinary.serialise tstdata) $ \tstdataB ->
        bench "binary"        (nf perfDecodeBinary       tstdataB)

      , env (return $ PkgCereal.serialise tstdata) $ \tstdataC ->
        bench "cereal"        (nf perfDecodeCereal       tstdataC)

      , env (return $ PkgAesonTH.serialise tstdata) $ \tstdataA ->
        bgroup "aeson"
          [ bench "generic"   (nf perfDecodeAesonGeneric tstdataA)
          , bench "TH"        (nf perfDecodeAesonTH      tstdataA)
          ]

      , env (return $ ReadShow.serialise tstdata) $ \tstdataS ->
        bench "read/show"     (nf perfDecodeReadShow     tstdataS)

--      , bench "msgpack lib"   (nf perfDecodeMsgpack      tstdataM)

--      , env (return $ NewMsgpack.serialise tstdata) $ \tstdataN ->
--        bench "new msgpack"   (nf perfDecodeNewMsgPack   tstdataN)

      , env (return $ CBOR.serialise tstdata) $ \tstdataR ->
        bench "cbor"          (nf perfDecodeCBOR         tstdataR)
      ]
  ]
  where
    perfEncodeBinary, perfEncodeCereal, perfEncodeAesonGeneric,
      perfEncodeAesonTH, perfEncodeReadShow,
      perfEncodeCBOR
      :: [Types.GenericPackageDescription] -> Int64


    perfEncodeBinary       = BS.length . PkgBinary.serialise
    perfEncodeCereal       = BS.length . PkgCereal.serialise
    perfEncodeAesonGeneric = BS.length . PkgAesonGeneric.serialise
    perfEncodeAesonTH      = BS.length . PkgAesonTH.serialise
    perfEncodeReadShow     = BS.length . ReadShow.serialise
    --perfEncodeMsgpack      = BS.length . PkgMsgpack.serialise
    --perfEncodeNewMsgPack   = BS.length . NewMsgpack.serialise
    perfEncodeCBOR         = BS.length . CBOR.serialise

    perfDecodeBinary, perfDecodeCereal, perfDecodeAesonGeneric,
      perfDecodeAesonTH, perfDecodeReadShow,
      perfDecodeCBOR
      :: BS.ByteString -> [Types.GenericPackageDescription]


    perfDecodeBinary       = PkgBinary.deserialise
    perfDecodeCereal       = PkgCereal.deserialise
    perfDecodeAesonGeneric = PkgAesonGeneric.deserialise
    perfDecodeAesonTH      = PkgAesonTH.deserialise
    perfDecodeReadShow     = ReadShow.deserialise
    --perfDecodeMsgpack      = PkgMsgpack.deserialise
    --perfDecodeNewMsgPack   = NewMsgpack.deserialise
    perfDecodeCBOR        = CBOR.deserialise
