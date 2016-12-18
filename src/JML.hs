{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE RankNTypes #-}
module JML where

import Control.Monad.State
import Text.ParserCombinators.Parsec

import JML.Lang.Parser
import JML.Semantics.Types
import JML.Semantics.Defs
import JML.Lang.Defs
import JML.Exceptions
import JML.Utils

{-
 - Debugging stuff
 -}


successTests =
  [ "(\\x. x)"
  , "(\\x. (\\y. y))"
  , "(\\x. x) 3"
  , "(\\x. (\\y. y)) 5 \"hi\""

  , "\\x. \\y. \\z. x z (y z)" -- S combinator
  
  , "fix f. \\y. y" -- equivalent to fix id, assuming fix :: (a -> a) -> a in Haskell
  , "let y = \\x. x in y y" -- y has type (forall t0. t0 -> t0), thus can be self applied

  , "let x = x in x" -- extension: implicit fix pointer construct
  , "\\f. let x = f x in x" -- fix combinator in ML 

  ]

failTests =
  [ "hello" -- unbounded term hello
  , "fix f. \\y. f" -- occurs check failure: f :: t, and \\y. f :: t0 -> t => cannot unify
  , "\\x. let y = x in y y" -- x has a rigid type t0 => cannot be self applied
  ]

runString = run $ \_ a _ ->
  case a of 
    Term n    -> n
    Const l   -> show l
    Abs ns e  -> concat ["ƛ", unwords ns, ". ", e]
    App e1 e2 -> concat ["(", e1, ")", "(", e2, ")"]
    Fix g e   -> concat ["fix ", g, " . ", e]

instance Show (Expr SrcPos) where
  show = runString

instance Show (MLProg SrcPos) where
  show (MLProg a) = show a

getType :: Expr SrcPos -> Either GenericMLError MLType
getType e = evalStateT (milner e) (TypeState [0..] [])

pparse = parse parseML "<none>"

runOneTest test = 
  do putStrLn $ "test for expression: " ++ show test
     let result = either (error . show) getType $ pparse test
     case result of
       Right t -> do
         putStrLn $ "type: " ++ show t
         putStrLn ""
       Left e -> putStrLn $ (unlines . map (indented 2) . lines . show) e

simpleTest =
  putStrLn "The following tests should succeed -----------------\n" >>
  forM_ successTests runOneTest >>
  putStrLn "The following tests should fail --------------------\n" >>
  forM_ failTests runOneTest