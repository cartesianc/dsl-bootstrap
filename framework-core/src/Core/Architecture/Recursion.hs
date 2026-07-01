module Core.Architecture.Recursion
  ( cata
  , prepro
  , gprepro
  , gpreproHanging
  , gpreproWorkflow
  ) where

cata ::
  (algebra -> source -> result) ->
  algebra ->
  source ->
  result
cata =
  gprepro id

prepro ::
  (source -> source) ->
  (algebra -> source -> result) ->
  algebra ->
  source ->
  result
prepro =
  gprepro

gprepro ::
  (source -> target) ->
  (algebra -> target -> result) ->
  algebra ->
  source ->
  result
gprepro lower interpret algebra =
  interpret algebra . lower

gpreproWorkflow ::
  (workflow -> program) ->
  (algebra -> program -> result) ->
  algebra ->
  workflow ->
  result
gpreproWorkflow =
  gprepro

gpreproHanging ::
  (hanging -> program) ->
  (algebra -> program -> result) ->
  algebra ->
  hanging ->
  result
gpreproHanging =
  gprepro
