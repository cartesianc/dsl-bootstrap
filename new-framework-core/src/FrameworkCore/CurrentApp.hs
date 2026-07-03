module FrameworkCore.CurrentApp
  ( frameworkCoreApp
  ) where

import FrameworkCore.BaseApp
  ( baseApp
  , currentTrustBase
  )
import FrameworkCore.CurrentAst
  ( currentAst
  )
import FrameworkCore.CurrentEffects
  ( currentEffects
  )
import FrameworkCore.CurrentInterpreter
  ( currentInterpreter
  )

frameworkCoreApp :: IO ()
frameworkCoreApp =
  baseApp currentTrustBase currentInterpreter currentAst currentEffects
