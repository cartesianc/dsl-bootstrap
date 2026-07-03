module Bootstrap.Runtime
  ( module Bootstrap.Runtime.BootstrapHandlers
  , module Bootstrap.Runtime.Build
  , module Bootstrap.Runtime.Interpreter
  , module Bootstrap.Runtime.Types
  , renderNativeAppError
  ) where

import Bootstrap.Runtime.BootstrapHandlers
import Bootstrap.Runtime.Build
import Bootstrap.Runtime.Interpreter
import Bootstrap.Runtime.Types

renderNativeAppError :: String -> String
renderNativeAppError =
  id
