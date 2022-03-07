module Main where

import Relude

import Data.Generics.Product (typed)
import Data.Text.IO (hPutStrLn)
import Data.Time (UTCTime, ZonedTime)
import Data.Version (showVersion)

import Optics (view, (.~), _3)
import Paths_nix_output_monitor (version)
import System.Console.Terminal.Size (Window)
import System.Environment (getArgs)

import NOM.IO (interact)
import NOM.Parser (ParseResult, parser)
import NOM.Print (stateToText)
import NOM.State (NOMV1State, ProcessState (..), failedBuilds, fullSummary, initalState)
import qualified NOM.State.CacheId.Map as CMap
import NOM.Update (detectLocalFinishedBuilds, updateState)
import NOM.Update.Monad (UpdateMonad)
import NOM.Util (addPrintCache, passThroughBuffer, (.>), (<|>>), (<||>), (|>))

main :: IO ()
main = do
  System.Environment.getArgs >>= \case
    [] -> pass
    ["--version"] -> do
      hPutStrLn stderr ("nix-output-monitor " <> fromString (showVersion version))
      exitSuccess
    xs -> do
      hPutStrLn stderr helpText
      -- It's not a mistake if the user requests the help text, otherwise tell
      -- them off with a non-zero exit code.
      if any ((== "-h") <||> (== "--help")) xs then exitSuccess else exitFailure
  firstState <- initalState
  let firstCompoundState = (Nothing, firstState, stateToText firstState)
  (_, finalState, _) <- interact parser compoundStateUpdater compoundStateToText finalizer firstCompoundState
  if (finalState |> fullSummary .> failedBuilds .> CMap.size) == 0
    then exitSuccess
    else exitFailure

type CompoundState = (Maybe UTCTime, NOMV1State, Maybe (Window Int) -> ZonedTime -> Text)

compoundStateToText :: (a, b, c) -> c
compoundStateToText = view _3

compoundStateUpdater ::
  UpdateMonad m =>
  (Maybe ParseResult, Text) ->
  CompoundState ->
  m (CompoundState, Text)
compoundStateUpdater = passThroughBuffer (addPrintCache updateState stateToText)

finalizer ::
  UpdateMonad m =>
  CompoundState ->
  m CompoundState
finalizer (n, oldState, _) = do
  newState <- execStateT detectLocalFinishedBuilds oldState <|>> (typed .~ Finished)
  pure (n, newState, stateToText newState)

helpText :: Text
helpText =
  unlines
    [ "Usage: nix-build |& nom"
    , ""
    , "Run any nix command (nixos-rebuild,nix-build,home-manager switch,"
    , "not nix build.) and pipe stderr and stdout into nom."
    , ""
    , "Don‘t forget to redirect stderr, too. That's what the & does."
    , ""
    , "Please see the readme for more details:"
    , "https://github.com/maralorn/nix-output-monitor"
    ]