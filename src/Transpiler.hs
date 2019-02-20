module Transpiler 
where

import Prelude hiding (id)
import Data.List
import Debug.Pretty.Simple (pTraceShowId, pTraceShow)
import Text.ParserCombinators.Parsec.Pos
import Data.Char


import qualified Ast.Verified as V
import Env

keliTranspile :: [KeliSymbol] -> String
keliTranspile symbols = (intercalate ";\n" (map transpile symbols)) ++ ";\n"


class Transpilable a where
    transpile :: a -> String

prefix :: String -> String
prefix s = "$" ++ s

quote :: String -> String
quote s = "\"" ++ s ++ "\""

squareBracket :: String -> String
squareBracket s = "[" ++ s ++ "]"

instance Transpilable V.Tag where
    transpile tag = case tag of 
        -- `tail id` is for removing leading hashtag `#`
        V.CarrylessTag (_,id) _ -> 
            quote (prefix id) ++ ":({__tag:\"" ++ id ++ "\"})"

        V.CarryfulTag (_,id) _ _ -> 
            quote (prefix id) ++ ":(__carry)=>({__tag:\"" ++ id ++ "\",__carry})"


instance Transpilable KeliSymbol where
    transpile symbol = case symbol of
        KeliSymFunc fs ->
            intercalate ";" (map transpile fs)

        KeliSymConst (_,id) expr ->
            "const " ++ prefix id ++ "=" ++ transpile expr

        KeliSymType (V.TypeTaggedUnion (V.TaggedUnion (_,id) ids tags _)) ->
            "const " ++ prefix id ++ "={" ++ intercalate "," (map transpile tags) ++ "}"

        KeliSymTypeConstructor (V.TaggedUnion name _ tags _) ->
            "const " ++ prefix (snd name) ++ "={" ++ intercalate "," (map transpile tags) ++ "}"

        KeliSymType {} -> 
            ""

        KeliSymInlineExprs exprs -> 
            intercalate ";" (map (\x -> "console.log(" ++ transpile x ++ ")") exprs)

        other ->
            error (show other)

joinIds :: [V.StringToken] -> String
joinIds ids = intercalate "_" (map snd ids)

instance Transpilable V.Decl where
    transpile x = case x of 
        V.ConstDecl c  -> transpile c
        V.IdlessDecl e -> transpile e
        V.FuncDecl f   -> transpile f


instance Transpilable V.Func where
    transpile f@(V.Func _ params _ _ body) 
        = let params' = intercalate "," (map ((prefix ) . snd . fst) params) in
        "function " ++ getFuncSignature f ++ "(" ++ params' ++ "){return " ++ transpile body ++ ";}"



instance Transpilable V.Const where
    transpile (V.Const (_,id) expr)
        = "const " ++ prefix id ++ "=" ++ (transpile expr)

instance Transpilable V.Expr where
    transpile expr = case expr of 
        V.Expr(V.IntExpr (_,value)) _                       
            -> show value

        V.Expr(V.DoubleExpr (_, value)) _                   
            -> show value

        V.Expr(V.StringExpr (_,value)) _
            -> show value

        V.Expr(V.Id     (_,value)) _
            -> prefix value

        V.Expr(V.Lambda ((_,param),_) body) _                      
            -> "(" ++ prefix param ++ ")=>(" ++ transpile body ++ ")"

        V.Expr(V.Record kvs) _                              
            -> transpileKeyValuePairs False (kvs)

        V.Expr(V.RecordGetter expr prop) _                  
            -> transpile expr ++ "." ++ prefix (snd prop)

        V.Expr(V.RecordSetter subject prop newValue) _      
            -> "({...(" ++ transpile subject ++ ")," ++ prefix (snd prop) ++ ":(" ++ transpile newValue ++ ")})"

        V.Expr(V.TagMatcher subject branches elseBranch) _
            -> 
            -- We will need to implement lazy evaluation here, as JavaScript is strict
            -- Also, lazy evaluation is needed to prevent evaluating unentered branch
            "(($$=>({" ++ intercalate "," (map transpile branches) ++ "})[$$.__tag])(" ++ transpile subject ++ ")" ++
                (case elseBranch of
                    Just expr' -> " || " ++ "(" ++ (lazify (transpile expr')) ++ ")"
                    Nothing   -> "") ++ ")()"

        V.Expr(V.FuncCall params _ ref) _ -> 
            getFuncSignature ref ++ "(" ++ intercalate "," (map transpile params) ++")"

        V.Expr(V.FFIJavascript (_,code)) _ ->
            code

        V.Expr 
            (V.CarryfulTagExpr (_,tag) carry)  
            ( (V.TypeTaggedUnion (V.TaggedUnion (_,id) _ _ _)))
                -> prefix id ++ squareBracket (quote (prefix tag)) ++ "("++ transpileKeyValuePairs False carry ++")"

        V.Expr 
            (V.CarrylessTagExpr(_,tag) _)
            ( (V.TypeTaggedUnion (V.TaggedUnion(_,id) _ _ _)))
                -> prefix id ++ squareBracket (quote (prefix tag))

        V.Expr (V.FuncApp f arg) _ ->
            transpile f ++ "(" ++ transpile arg ++ ")"

        other -> 
            error (show other)

instance Transpilable V.TagBranch where
    transpile b = case b of
        V.CarrylessTagBranch (V.VerifiedTagname (_,tagname)) expr ->
            tagname ++ ":" ++ lazify (transpile expr)

        V.CarryfulTagBranch (V.VerifiedTagname (_,tagname)) propBindings expr ->
            -- Refer https://codeburst.io/renaming-destructured-variables-in-es6-807549754972
            tagname ++ ":" ++ lazify ("(({" 
                ++ (concatMap (\((_,from), (_,to), _) -> prefix from ++ ":" ++ prefix to ++ ",") propBindings)
                ++ "})=>" 
                ++ transpile expr ++ ")($$.__carry)")


transpileKeyValuePairs :: Bool -> [(V.StringToken, V.Expr)] -> String
transpileKeyValuePairs lazifyExpr kvs 
    = "({" ++ (foldl' (\acc (key,expr) -> acc ++ (prefix (snd key)) ++ ":" 
        ++ (if lazifyExpr then lazify (transpile expr) else (transpile expr))
        ++ ",") "" kvs) ++ "})"


lazify :: String -> String
lazify str = "()=>(" ++ str ++ ")"

-- Each function identifier shall follows the following format:
--
--      <front part>$$<back part>
--      id1$id2$id3$$hash
--
--  where <front part> is function names and <back part> is the hash
--  hash is the line number of where the first funcId is defined
-- 
-- Example:
--      this:String.replace old:String with new:String | String = undefined
-- Shall have id of
--      replace$with$$1
--
-- This format is necessary, so that when we do function lookup,
--  we can still construct back the function details from its id when needed
--  especially when looking up generic functions
getFuncSignature :: V.Func -> String
getFuncSignature (V.Func{V.funcDeclIds=ids}) = 
    let hash =sourceLine (fst (head ids)) in
    intercalate "$" (map (toValidJavaScriptId . snd) ids) ++ "$$" ++ show hash

-- Basically, this function will convert all symbols to its corresponding ASCII code
-- e.g. toValidJavaScriptId "$" = "_36"
toValidJavaScriptId :: String -> String
toValidJavaScriptId s = "_" ++ concat (map (\x -> if (not . isAlphaNum) x then show (ord x) else [x]) s)