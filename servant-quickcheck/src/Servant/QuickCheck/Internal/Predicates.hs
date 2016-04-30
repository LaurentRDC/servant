{-# LANGUAGE MultiWayIf #-}
module Servant.QuickCheck.Internal.Predicates where

import           Control.Monad
import           Data.Aeson            (Object, decode)
import           Data.Bifunctor        (Bifunctor (..))
import qualified Data.ByteString       as SBS
import qualified Data.ByteString.Char8 as SBSC
import qualified Data.ByteString.Lazy  as LBS
import           Data.CaseInsensitive  (mk)
import           Data.Either           (isRight)
import           Data.List.Split       (wordsBy)
import           Data.Maybe            (isJust)
import           Data.Monoid           ((<>))
import           Data.Text             (Text)
import           GHC.Generics          (Generic)
import           Network.HTTP.Client   (Manager, Request, Response, httpLbs,
                                        method, responseBody, responseHeaders,
                                        responseStatus)
import           Network.HTTP.Types    (methodGet, methodHead, parseMethod,
                                        status401, renderStdMethod, status405, status500)

-- | [__Best Practice__]
--
-- @500 Internal Server Error@ should be avoided - it may represent some
-- issue with the application code, and it moreover gives the client little
-- indication of how to proceed or what went wrong.
--
-- This function checks that the response code is not 500.
not500 :: ResponsePredicate Text Bool
not500 = ResponsePredicate "not500" (\resp -> not $ responseStatus resp == status500)

-- | [__Best Practice__]
--
-- Returning anything other than an object when returning JSON is considered
-- bad practice, as:
--
--   (1) it is hard to modify the returned value while maintaining backwards
--   compatibility
--   (2) many older tools do not support top-level arrays
--   (3) whether top-level numbers, booleans, or strings are valid JSON depends
--   on what RFC you're going by
--   (4) there are security issues with top-level arrays
--
-- This function checks that any @application/json@ responses only return JSON
-- objects (and not arrays, strings, numbers, or booleans) at the top level.
--
-- __References__:
--
--   * JSON Grammar: <https://tools.ietf.org/html/rfc7159#section-2 RFC 7159 Section 2>
--   * JSON Grammar: <https://tools.ietf.org/html/rfc4627#section-2 RFC 4627 Section 2>
onlyJsonObjects :: ResponsePredicate Text Bool
onlyJsonObjects
  = ResponsePredicate "onlyJsonObjects" (\resp -> case decode (responseBody resp) of
      Nothing -> False
      Just (_ :: Object) -> True)

-- | __Optional__
--
-- When creating a new resource, it is good practice to provide a @Location@
-- header with a link to the created resource.
--
-- This function checks that every @201 Created@ response contains a @Location@
-- header, and that the link in it responds with a 2XX response code to @GET@
-- requests.
--
-- This is considered optional because other means of linking to the resource
-- (e.g. via the response body) are also acceptable; linking to the resource in
-- some way is considered best practice.
--
-- __References__:
--
--   * 201 Created: <https://tools.ietf.org/html/rfc7231#section-6.3.2 RFC 7231 Section 6.3.2>
--   * Location header: <https://tools.ietf.org/html/rfc7231#section-7.1.2 RFC 7231 Section 7.1.2>
{-createContainsValidLocation :: RequestPredicate Text Bool-}
{-createContainsValidLocation-}
  {-= RequestPredicate-}
    {-{ reqPredName = "createContainsValidLocation"-}
    {-, reqResps = \req mg -> do-}
        {-resp <- httpLbs mgr req-}
        {-if responseStatus resp == status201-}
            {-then case lookup "Location" $ responseHeaders resp of-}
                {-Nothing -> return []-}
                {-Just l  -> if-}

{-
getsHaveLastModifiedHeader :: ResponsePredicate Text Bool
getsHaveLastModifiedHeader
  = ResponsePredicate "getsHaveLastModifiedHeader" (\resp ->

-}

-- | [__RFC Compliance__]
--
-- When an HTTP request has a method that is not allowed,
-- a 405 response should be returned. Additionally, it is good practice to
-- return an @Allow@
-- header with the list of allowed methods.
--
-- This function checks that every @405 Method Not Allowed@ response contains
-- an @Allow@ header with a list of standard HTTP methods.
--
-- __References__:
--
--   * @Allow@ header: <https://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html RFC 2616 Section 14.7>
--   * Status 405: <https://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html RFC 2616 Section 10.4.6>
notAllowedContainsAllowHeader :: RequestPredicate Text Bool
notAllowedContainsAllowHeader
  = RequestPredicate
    { reqPredName = "notAllowedContainsAllowHeader"
    , reqResps = \req mgr -> do
        resp <- mapM (flip httpLbs mgr) $ [ req { method = renderStdMethod m }
                                          | m <- [minBound .. maxBound ]
                                          , renderStdMethod m /= method req ]
        return (all pred' resp, resp)
    }
    where
      pred' resp = responseStatus resp /= status405 || hasValidHeader "Allow" go resp
        where
          go x = all (\y -> isRight $ parseMethod $ SBSC.pack y)
               $ wordsBy (`elem` (", " :: [Char])) (SBSC.unpack x)

  {-
-- | When a request contains an @Accept@ header, the server must either return
-- content in one of the requested representations, or respond with @406 Not
-- Acceptable@.
--
-- This function checks that every *successful* response has a @Content-Type@
-- header that matches the @Accept@ header.
--
-- __References__:
--
--   * @Accept@ header: <https://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html RFC 2616 Section 14.1>
honoursAcceptHeader :: RequestPredicate b Bool
honoursAcceptHeader
  = RequestPredicate name (ResponsePredicate name $ \req mgr -> do

      resp <- httpLbs req mgr
      let scode = responseStatus resp
          sctype = maybeToList $ lookup "Content-Type" $ responseHeaders resp
          sacc  = fromMaybe "*/*" $ lookup "Accept" $ requestHeaders req
      if 100 < scode && scode < 300
        then isJust matchAccept sacc sctype
        else True)
  where name = "honoursAcceptHeader"

-}
-- | [__Best Practice__]
--
-- Whether or not a representation should be cached, it is good practice to
-- have a @Cache-Control@ header for @GET@ requests. If the representation
-- should not be cached, used @Cache-Control: no-cache@.
--
-- This function checks that @GET@ responses have @Cache-Control@ header.
-- It does NOT currently check that the header is valid.
--
-- __References__:
--
--   * @Cache-Control@ header: <https://tools.ietf.org/html/rfc7234#section-5.2 RFC 7234 Section 5.2>
getsHaveCacheControlHeader :: RequestPredicate Text Bool
getsHaveCacheControlHeader
  = RequestPredicate
     { reqPredName = "getsHaveCacheControlHeader"
     , reqResps = \req mgr -> if method req == methodGet
        then do
          resp <- httpLbs req mgr
          let good = isJust $ lookup "Cache-Control" $ responseHeaders resp
          return (good, [resp])
        else return (True, [])
     }

-- | [__Best Practice__]
--
-- Like 'getsHaveCacheControlHeader', but for @HEAD@ requests.
headsHaveCacheControlHeader :: RequestPredicate Text Bool
headsHaveCacheControlHeader
  = RequestPredicate
     { reqPredName = "headsHaveCacheControlHeader"
     , reqResps = \req mgr -> if method req == methodHead
        then do
          resp <- httpLbs req mgr
          let good = isJust $ lookup "Cache-Control" $ responseHeaders resp
          return (good, [resp])
        else return (True, [])
     }
{-
-- |
--
-- If the original request modifies the resource, this function makes two
-- requests:
--
--   (1) Once, with the original request and a future date as the
--   @If-Unmodified-Since@, which is expected to succeed.
--   (2) Then with the original request again, with a @If-Unmodified-Since@
--   safely in the past. Since presumably the representation has been changed
--   recently (by the first request), this is expected to fail with @412
--   Precondition Failure@.
--
-- Note that the heuristic used to guess whether the original request modifies
-- a resource is simply whether the method is @PUT@ or @PATCH@, which may be
-- incorrect in certain circumstances.
supportsIfUnmodifiedSince :: Predicate b Bool
supportsIfUnmodifiedSince
  = ResponsePredicate "supportsIfUnmodifiedSince" _

-- | @OPTIONS@ responses should contain an @Allow@ header with the list of
-- allowed methods.
--
-- If a request is an @OPTIONS@ request, and if the response is a successful
-- one, this function checks the response for an @Allow@ header. It fails if:
--
--   (1) There is no @Allow@ header
--   (2) The @Allow@ header does not have standard HTTP methods in the correct
--   format
--   (3) Making a request to the same URL with one of those methods results in
--   a 404 or 405.
optionsContainsValidAllow :: Predicate b Bool
optionsContainsValidAllow
  = ResponsePredicate "optionsContainsValidAllow" _

-- | Link headers are a standardized way of presenting links that may be
-- relevant to a client.
--
-- This function checks that any @Link@ headers have values in the correct
-- format.
--
-- __References__:
--
--   * <https://tools.ietf.org/html/rfc5988 RFC 5988 Section 5>
linkHeadersAreValid :: Predicate b Bool
linkHeadersAreValid
  = ResponsePredicate "linkHeadersAreValid" _

-}
-- | [__RFC Compliance__]
--
-- Any @401 Unauthorized@ response must include a @WWW-Authenticate@ header.
--
-- This function checks that, if a response has status code 401, it contains a
-- @WWW-Authenticate@ header.
--
-- __References__:
--
--   * @WWW-Authenticate@ header: <https://tools.ietf.org/html/rfc7235#section-4.1 RFC 7235 Section 4.1>
unauthorizedContainsWWWAuthenticate :: ResponsePredicate Text Bool
unauthorizedContainsWWWAuthenticate
  = ResponsePredicate "unauthorizedContainsWWWAuthenticate" (\resp ->
      if responseStatus resp == status401
        then hasValidHeader "WWW-Authenticate" (const True) resp
        else True)

-- * Predicate logic

-- The idea with all this footwork is to not waste any requests. Rather than
-- generating new requests and only applying one predicate to the response, we
-- apply as many predicates as possible.
--
-- Still, this is all kind of ugly.

data ResponsePredicate n r = ResponsePredicate
  { respPredName :: n
  , respPred :: Response LBS.ByteString -> r
  } deriving (Functor, Generic)

instance Bifunctor ResponsePredicate where
  first f (ResponsePredicate a b) = ResponsePredicate (f a) b
  second = fmap

instance (Monoid n, Monoid r) => Monoid (ResponsePredicate n r) where
  mempty = ResponsePredicate mempty mempty
  a `mappend` b = ResponsePredicate
    { respPredName = respPredName a <> respPredName b
    , respPred = respPred a <> respPred b
    }

data RequestPredicate n r = RequestPredicate
  { reqPredName :: n
  , reqResps    :: Request -> Manager -> IO (r, [Response LBS.ByteString])
  } deriving (Generic, Functor)

instance Bifunctor RequestPredicate where
  first f (RequestPredicate a b) = RequestPredicate (f a) b
  second = fmap

-- TODO: This isn't actually a monoid
instance (Monoid n, Monoid r) => Monoid (RequestPredicate n r) where
  mempty = RequestPredicate mempty (\r m -> httpLbs r m >>= \x -> return (mempty, [x]))
  a `mappend` b = RequestPredicate
    { reqPredName = reqPredName a <> reqPredName b
    , reqResps = \x m -> liftM2 (<>) (reqResps a x m) (reqResps b x m)
    }

data Predicates n r = Predicates
  { reqPreds :: RequestPredicate n r
  , respPreds :: ResponsePredicate n r
  } deriving (Generic, Functor)

instance (Monoid n, Monoid r) => Monoid (Predicates n r) where
  mempty = Predicates mempty mempty
  a `mappend` b = Predicates (reqPreds a <> reqPreds b) (respPreds a <> respPreds b)



class JoinPreds a where
  joinPreds :: a -> Predicates [Text] [Text] -> Predicates [Text] [Text]

instance JoinPreds (RequestPredicate Text Bool) where
  joinPreds p (Predicates x y) = Predicates (go <> x) y
    where go = let p' = first return p
               in fmap (\z -> if z then [] else reqPredName p') p'

instance JoinPreds (ResponsePredicate Text Bool) where
  joinPreds p (Predicates x y) = Predicates x (go <> y)
    where go = let p' = first return p
               in fmap (\z -> if z then [] else respPredName p') p'


-- | Adds a new predicate (either `ResponsePredicate` or `RequestPredicate`) to
-- the existing predicates.
--
-- > not500 <%> onlyJsonObjects <%> empty
(<%>) :: JoinPreds a => a -> Predicates [Text] [Text] -> Predicates [Text] [Text]
(<%>) = joinPreds
infixr 6 <%>

finishPredicates :: Predicates [Text] [Text] -> Request -> Manager -> IO [Text]
finishPredicates p req mgr = do
  (soFar, resps) <- reqResps (reqPreds p) req mgr
  return $ soFar <> mconcat [respPred (respPreds p) r | r <- resps]

-- * helpers

hasValidHeader :: SBS.ByteString -> (SBS.ByteString -> Bool) -> Response b -> Bool
hasValidHeader hdr p r = case lookup (mk hdr) (responseHeaders r) of
  Nothing -> False
  Just v  -> p v
