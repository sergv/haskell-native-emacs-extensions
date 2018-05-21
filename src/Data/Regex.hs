----------------------------------------------------------------------------
-- |
-- Module      :  Data.Regex
-- Copyright   :  (c) Sergey Vinokurov 2018
-- License     :  BSD3-style (see LICENSE)
-- Maintainer  :  serg.foo@gmail.com
----------------------------------------------------------------------------

{-# LANGUAGE FlexibleContexts  #-}
{-# LANGUAGE OverloadedStrings #-}

module Data.Regex
  ( globsToRegex
  , compileRe
  , reMatches
  , reMatchesPath
  , module Text.Regex.TDFA
  ) where

import Control.Exception.Safe.Checked (Throws, MonadThrow)
import qualified Control.Exception.Safe.Checked as Checked
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Prettyprint.Doc
import Path
import Text.Regex.TDFA
import qualified Text.Regex.TDFA.Text as TDFA

import Emacs.Module.Assert (WithCallStack)
import Emacs.Module.Errors

globsToRegex :: (WithCallStack, Throws UserError, MonadThrow m) => [Text] -> m Regex
globsToRegex =
  compileRe . mkStartEnd . mkGroup . T.intercalate "|" . map (mkGroup . T.concatMap f)
  where
    mkGroup :: Text -> Text
    mkGroup = T.cons '(' . (`T.snoc` ')')
    mkStartEnd :: Text -> Text
    mkStartEnd = T.cons '^' . (`T.snoc` '$')
    f :: Char -> Text
    f '*'  = ".*"
    f '.'  = "\\."
    f '+'  = "\\+"
    f '['  = "\\["
    f ']'  = "\\]"
    f '('  = "\\("
    f ')'  = "\\)"
    f '^'  = "\\^"
    f '$'  = "\\$"
    f '?'  = "\\?"
    f '\\' = "\\\\"
    f c    = T.singleton c

compileRe :: (WithCallStack, MonadThrow m, Throws UserError) => Text -> m Regex
compileRe re =
  case TDFA.compile compOpts execOpts re of
    Left err -> Checked.throw $ mkUserError "compileRe" $
      "Failed to compile regular expression:" <+> pretty err <> ":" <> line <> pretty re
    Right x  -> pure x
  where
    compOpts = defaultCompOpt
      { multiline     = False
      , caseSensitive = True
      }
    execOpts = defaultExecOpt
      { captureGroups = False
      }

reMatches :: Regex -> Text -> Bool
reMatches = match

reMatchesPath :: Regex -> Path a b -> Bool
reMatchesPath re = match re . toFilePath