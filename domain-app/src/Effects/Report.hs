{-# LANGUAGE PatternSynonyms #-}

module Effects.Report
  ( reportEffect
  ) where

import Domain.EffectVocabulary
  ( pattern ReportEffect )
import Domain.Business
  ( reportCapabilities )
import Framework.Business
  ( EffectUnit
  , capabilitiesEffect
  )

-- lowering facade: Domain.Business.reportCapabilities -> EffectUnit
reportEffect :: EffectUnit
reportEffect =
  capabilitiesEffect ReportEffect reportCapabilities
