module Core.Architecture.Internal
  ( FreeMonad (..)
  , FreeApplicative (..)
  , FreeMonoid (..)
  , FreeAlternative (..)
  , FreeChoice (..)
  , ChoiceBranch (..)
  , RequirementEffect (..)
  , freeMonad
  , freeApplicative
  , freeMonoid
  , freeAlternative
  , freeChoice
  , requirementEffect
  , foldFreeMonadState
  , foldFreeApplicativeState
  , foldFreeMonoidState
  , foldFreeMonoid_
  , foldRequirementEffectState
  ) where

newtype FreeMonad step = FreeMonad
  { freeMonadSteps :: [step]
  }

newtype FreeApplicative branch = FreeApplicative
  { freeApplicativeBranches :: [branch]
  }

newtype FreeMonoid item = FreeMonoid
  { freeMonoidItems :: [item]
  }

newtype FreeAlternative branch = FreeAlternative
  { freeAlternativeBranches :: [branch]
  }

data ChoiceBranch key branch = ChoiceBranch key branch

newtype FreeChoice key branch = FreeChoice
  { freeChoiceBranches :: [ChoiceBranch key branch]
  }

newtype RequirementEffect requirement a = RequirementEffect
  { requirementEffectItems :: [requirement]
  }

instance Functor (RequirementEffect requirement) where
  fmap _ (RequirementEffect requirements) =
    RequirementEffect requirements

instance Applicative (RequirementEffect requirement) where
  pure _ =
    RequirementEffect []

  RequirementEffect left <*> RequirementEffect right =
    RequirementEffect (left <> right)

freeMonad :: [step] -> FreeMonad step
freeMonad =
  FreeMonad

freeApplicative :: [branch] -> FreeApplicative branch
freeApplicative =
  FreeApplicative

freeMonoid :: [item] -> FreeMonoid item
freeMonoid =
  FreeMonoid

freeAlternative :: [branch] -> FreeAlternative branch
freeAlternative =
  FreeAlternative

freeChoice :: [(key, branch)] -> FreeChoice key branch
freeChoice =
  FreeChoice . map (uncurry ChoiceBranch)

requirementEffect :: [requirement] -> RequirementEffect requirement ()
requirementEffect =
  RequirementEffect

instance Functor FreeMonad where
  fmap transform steps =
    FreeMonad (map transform (freeMonadSteps steps))

instance Semigroup (FreeMonad step) where
  FreeMonad left <> FreeMonad right =
    FreeMonad (left <> right)

instance Monoid (FreeMonad step) where
  mempty =
    FreeMonad []

instance Functor FreeApplicative where
  fmap transform branches =
    FreeApplicative (map transform (freeApplicativeBranches branches))

instance Semigroup (FreeApplicative branch) where
  FreeApplicative left <> FreeApplicative right =
    FreeApplicative (left <> right)

instance Monoid (FreeApplicative branch) where
  mempty =
    FreeApplicative []

instance Functor FreeMonoid where
  fmap transform items =
    FreeMonoid (map transform (freeMonoidItems items))

instance Functor FreeAlternative where
  fmap transform branches =
    FreeAlternative (map transform (freeAlternativeBranches branches))

instance Semigroup (FreeAlternative branch) where
  FreeAlternative left <> FreeAlternative right =
    FreeAlternative (left <> right)

instance Monoid (FreeAlternative branch) where
  mempty =
    FreeAlternative []

instance Functor (FreeChoice key) where
  fmap transform choices =
    FreeChoice (map mapChoiceBranch (freeChoiceBranches choices))
    where
      mapChoiceBranch (ChoiceBranch key branch) =
        ChoiceBranch key (transform branch)

instance Semigroup (FreeMonoid item) where
  FreeMonoid left <> FreeMonoid right =
    FreeMonoid (left <> right)

instance Monoid (FreeMonoid item) where
  mempty =
    FreeMonoid []

foldFreeMonadState :: (state -> step -> IO state) -> state -> FreeMonad step -> IO state
foldFreeMonadState interpret initialState steps =
  foldState interpret initialState (freeMonadSteps steps)

foldFreeApplicativeState :: (state -> branch -> IO state) -> state -> FreeApplicative branch -> IO state
foldFreeApplicativeState interpret initialState branches =
  foldState interpret initialState (freeApplicativeBranches branches)

foldFreeMonoid_ :: (item -> IO ()) -> FreeMonoid item -> IO ()
foldFreeMonoid_ interpret items =
  mapM_ interpret (freeMonoidItems items)

foldFreeMonoidState :: (state -> item -> IO state) -> state -> FreeMonoid item -> IO state
foldFreeMonoidState interpret initialState items =
  foldState interpret initialState (freeMonoidItems items)

foldRequirementEffectState ::
  (state -> requirement -> IO state) ->
  state ->
  RequirementEffect requirement result ->
  IO state
foldRequirementEffectState interpret initialState requirements =
  foldState interpret initialState (requirementEffectItems requirements)

foldState :: (state -> item -> IO state) -> state -> [item] -> IO state
foldState _ state [] =
  pure state
foldState interpret state (item : rest) = do
  nextState <- interpret state item
  foldState interpret nextState rest
