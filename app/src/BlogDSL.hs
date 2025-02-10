{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE InstanceSigs #-}

module BlogDSL where

import GHC.Generics
import Data.Aeson
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime)
import Lucid
import Data.Time.Format (formatTime, defaultTimeLocale)

-- | Blog element types
data BlogElement = 
    TextContent Text
  | HeaderContent Text
  | Image 
    { path :: Text
    , alt :: Text
    , caption :: Maybe Text
    }
  | CodeBlock 
    { language :: Text
    , codeContent :: Text
    } deriving (Generic, Show)

-- blogpost type
data BlogPost = BlogPost
  { postId :: Int
  , title :: Text
  , date :: UTCTime
  , content :: [BlogElement]
  } deriving (Generic, Show)

-- define json instances
instance ToJSON BlogElement where
  toJSON (TextContent txt) = object 
    [ "type" .= ("text" :: Text)
    , "content" .= txt
    ]
  toJSON (HeaderContent txt) = object 
    [ "type" .= ("header" :: Text)
    , "content" .= txt
    ]
  toJSON (Image path' alt' cap) = object 
    [ "type" .= ("image" :: Text)
    , "path" .= path'
    , "alt" .= alt'
    , "caption" .= cap
    ]
  toJSON (CodeBlock lang code) = object
    [ "type" .= ("code" :: Text)
    , "language" .= lang
    , "content" .= code
    ]

instance FromJSON BlogElement
instance ToJSON BlogPost
instance FromJSON BlogPost

-- define basic HTML instances
instance ToHtml BlogElement where
  toHtml element = case element of
    TextContent text -> toHtml text
    HeaderContent text -> h2_ $ toHtml text
    Image path alt caption -> do
      img_ [src_ path, alt_ alt]
      case caption of
        Just cap -> p_ [class_ "caption"] $ toHtml cap
        Nothing -> pure ()
    CodeBlock lang code -> pre_ [class_ $ "language-" <> lang] $ code_ $ toHtml code
  toHtmlRaw :: Monad m => BlogElement -> HtmlT m ()
  toHtmlRaw = toHtml

instance ToHtml BlogPost where
  toHtml :: Monad m => BlogPost -> HtmlT m ()
  toHtml post = article_ [class_ "blog-post"] $ do
    h1_ [class_ "post-title"] $ toHtml (title post)
    p_ [class_ "post-date"] $ toHtml (show $ date post)
    mapM_ toHtml (content post)
  toHtmlRaw = toHtml

-- HTML generation
class ToHtml a => ToBlogHtml a where
  toBlogHtml :: a -> Html ()

instance ToBlogHtml BlogElement where
  toBlogHtml (TextContent txt) = p_ [] (toHtml txt)
  toBlogHtml (HeaderContent txt) = h2_ [] (toHtml txt)
  toBlogHtml (Image path alt caption) = figure_ [] $ do
    img_ [src_ path, alt_ alt]
    maybe (pure ()) (figcaption_[] . toHtml) caption
  toBlogHtml (CodeBlock lang code) = 
    pre_ [class_ $ "language-" <> lang] $ 
      code_ [class_ $ "language-" <> lang] (toHtml code)

instance ToBlogHtml BlogPost where
  toBlogHtml post = article_ [class_ "blog-post"] $ do
    h1_ [] (toHtml $ title post)
    div_ [class_ "post-date"] (toHtml $ formatDate $ date post)
    mapM_ toBlogHtml (content post)

-- page generator
renderBlogPost :: BlogPost -> Html ()
renderBlogPost post = doctypehtml_ $ do
  head_ $ do
    meta_ [charset_ "utf-8"]
    meta_ [name_ "viewport", content_ "width=device-width, initial-scale=1"]
    title_ (toHtml $ title post)
    link_ [rel_ "stylesheet", type_ "text/css", href_ "../css/style.css"]
    link_ [rel_ "stylesheet", href_ "https://cdnjs.cloudflare.com/ajax/libs/prism/1.24.1/themes/prism-tomorrow.min.css"]
    script_ [src_ "https://cdnjs.cloudflare.com/ajax/libs/prism/1.24.1/components/prism-core.min.js"] ("" :: Text)
    script_ [src_ "https://cdnjs.cloudflare.com/ajax/libs/prism/1.24.1/components/prism-haskell.min.js"] ("" :: Text)
    script_ [src_ "https://cdnjs.cloudflare.com/ajax/libs/prism/1.24.1/plugins/autoloader/prism-autoloader.min.js"] ("" :: Text)
  body_ $ do
    div_ [class_ "container"] $ do
      nav_ [class_ "nav"] $ do
        a_ [href_ "../index.html"] "Home"
        a_ [href_ "../about.html"] "About"
        a_ [href_ "../projects.html"] "Projects"
      main_ [] $ do
        article_ [class_ "blog-post"] $ do
          h1_ [] (toHtml $ title post)
          div_ [class_ "post-date"] (toHtml $ formatDate $ date post)
          mapM_ toBlogHtml (content post)
      footer_ [class_ "footer"] $ do
        p_ [] "Generated in Haskell"

-- date formatter
formatDate :: UTCTime -> String
formatDate = formatTime defaultTimeLocale "%B %e, %Y" 