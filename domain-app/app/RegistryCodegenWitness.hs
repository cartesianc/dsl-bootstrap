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
      putStrLn ("[witness] ok registry codegen evidence " ++ show (length expectedEvidence) ++ " claims")
    _ ->
      ioError
        ( userError
            ( "[witness] registry codegen evidence failed\n"
                ++ "missing: "
                ++ show missing
                ++ "\nfailed: "
                ++ show (map domainSemanticEvidenceName failed)
            )
        )

expectedEvidence :: [String]
expectedEvidence =
  [ "registry-codegen-plugins"
  , "registry-codegen-effects"
  ]

evidencePresent :: String -> DomainReport -> Bool
evidencePresent name report =
  any
    (\evidence -> domainSemanticEvidenceName evidence == name)
    (domainReportSemanticEvidence report)
