module Main
  ( main
  ) where

import Framework.Domain
  ( DomainReport (..)
  , DomainSemanticEvidence (..)
  , buildDomainReport
  , domainSemanticEvidencePassed
  )
import SelfDomainApp
  ( domainAppDomain )

main :: IO ()
main = do
  report <- buildDomainReport domainAppDomain
  let missing =
        [ name
        | name <- expectedEvidence
        , not (evidencePresent name report)
        ]
      failed =
        [ evidence
        | evidence <- domainReportSemanticEvidence report
        , domainSemanticEvidenceName evidence `elem` expectedEvidence
        , not (domainSemanticEvidencePassed evidence)
        ]
  case (missing, failed) of
    ([], []) ->
      putStrLn ("[witness] ok runtime diagnosis evidence " ++ show (length expectedEvidence) ++ " claims")
    _ ->
      ioError
        ( userError
            ( "[witness] runtime diagnosis evidence failed\n"
                ++ "missing: "
                ++ show missing
                ++ "\nfailed: "
                ++ show (map domainSemanticEvidenceName failed)
            )
        )

expectedEvidence :: [String]
expectedEvidence =
  [ "runtime-diagnosis-error-handler"
  , "runtime-diagnosis-retry-probe"
  , "runtime-diagnosis-non-idempotent-blocker"
  ]

evidencePresent :: String -> DomainReport -> Bool
evidencePresent name report =
  any
    (\evidence -> domainSemanticEvidenceName evidence == name)
    (domainReportSemanticEvidence report)
