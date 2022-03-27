module NOM.Error where

import Relude

import Control.Exception (IOException)

data NOMError = InputError IOException | DerivationReadError IOException | DerivationParseError Text | ParseInternalJSONError deriving (Show, Eq)
