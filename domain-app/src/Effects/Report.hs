{-# LANGUAGE PatternSynonyms #-}

module Effects.Report
  ( reportEffect
  ) where

import Domain.EffectVocabulary
  ( pattern ReportEffect )
import Domain.Business
  ( reportCapabilities )
import Framework.Business
  ( capabilitiesEffect )
import Framework.Effect
  ( EffectUnit )

-- effect: reportEffect
reportEffect :: EffectUnit
reportEffect =
  capabilitiesEffect ReportEffect reportCapabilities
