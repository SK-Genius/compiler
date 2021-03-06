{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC #-}

module Parser where

import Prelude hiding (id)

import qualified Ast.Raw as Raw

import Lexer

import Text.Parsec.Pos
import StaticError
import Text.ParserCombinators.Parsec hiding (token)
import Text.ParserCombinators.Parsec.Expr
import Debug.Pretty.Simple (pTraceShowId, pTraceShow)
import Text.ParserCombinators.Parsec.Error 
import Data.List

keliParser :: Parser [Raw.Decl]
keliParser = whiteSpace >> keliDecl

keliDecl :: Parser [Raw.Decl]
keliDecl = do
    list <- (many1 keliDecl')
    eof
    return list

keliDecl' :: Parser Raw.Decl
keliDecl' 
    =  try keliFuncDecl
   <|> try keliGenericTypeDecl 
   <|> keliConstDecl

keliConstDecl :: Parser Raw.Decl
keliConstDecl 
    =  optionMaybe (keliFuncId)   >>= \token
    -> getPosition                >>= \pos
    -> reservedOp "="             >>= \_ 
    -> keliExpr                   >>= \expr
    -> case token of 
        Just t  -> return (Raw.ConstDecl (Raw.Const t expr))
        Nothing -> return (Raw.IdlessDecl pos expr)

keliExpr :: Parser Raw.Expr
keliExpr 
    =  try keliIncompleteFuncCall 
   <|> keliExpr'

keliExpr' :: Parser Raw.Expr
keliExpr' 
    =  try keliFuncCall
   <|> try keliLambda
   <|> try keliLambdaShortHand
   <|> keliAtomicExpr 

keliIncompleteFuncCall :: Parser Raw.Expr
keliIncompleteFuncCall
    =  (try 
            keliExpr'          >>= \param1
        ->  getPosition        >>= \pos
        ->  char ';' >> spaces >>= \_
        ->  return (Raw.IncompleteFuncCall param1 pos))
    <|> 
        (-- for lambda shorthand
            getPosition >>= \pos
        ->  char ';'    >>= \_
        ->  
            let lambdaParam = generateLambdaParamName pos in
            let lambdaBody = Raw.IncompleteFuncCall (Raw.Id lambdaParam) pos in
            return (Raw.Lambda lambdaParam lambdaBody))
        
 

keliFuncCall :: Parser Raw.Expr
keliFuncCall 
    =  keliAtomicExpr     >>= \param1
    -> char '.' >> spaces >>= \_
    -> keliFuncCallTail   >>= \chain
    -> return (convertFuncCallChainToFuncCall chain param1)

keliLambda :: Parser Raw.Expr
keliLambda
    =  keliFuncId       >>= \param
    -> reservedOp "|"   >>= \_
    -> keliExpr         >>= \expr
    -> return (Raw.Lambda param expr)

keliLambdaShortHand :: Parser Raw.Expr
keliLambdaShortHand
    =  getPosition         >>= \pos
    -> char '.' >> spaces  >>= \_
    -> keliFuncCallTail    >>= \chain
    ->
        let autoGeneratedLambaParam = generateLambdaParamName pos in
        let lambdaBody = convertFuncCallChainToFuncCall chain (Raw.Id autoGeneratedLambaParam) in
        return (Raw.Lambda autoGeneratedLambaParam lambdaBody)

generateLambdaParamName :: SourcePos -> Raw.StringToken
generateLambdaParamName pos =
    -- example, $0$3
    (pos, "$" ++ show (sourceLine pos) ++ "$" ++ show (sourceColumn pos)) 

data KeliFuncCallChain
    = KeliFuncCallChain KeliFuncCallChain KeliFuncCallChain
    | KeliPartialFuncCall {
        partialFuncCallIds    :: [Raw.StringToken],
        partialFuncCallParams :: [Raw.Expr]
    }

convertFuncCallChainToFuncCall 
    :: KeliFuncCallChain
    -> Raw.Expr -- subject expr, e.g., in `123.square` , `123` is the subject
    -> Raw.Expr

convertFuncCallChainToFuncCall chain subject = 
    let pairs = flattenFuncCallChain chain in
    let firstChain     = head pairs in
    let remainingChain = tail pairs in
    (foldl' 
        (\acc next -> (Raw.FuncCall (acc : Raw.funcCallParams next) (Raw.funcCallIds next))) -- reducer
        (Raw.FuncCall (subject:(snd firstChain)) (fst firstChain))               -- initial value
        (map (\(funcIds,params) -> Raw.FuncCall params funcIds) remainingChain) -- foldee
    )

flattenFuncCallChain :: KeliFuncCallChain -> [([Raw.StringToken], [Raw.Expr])]
flattenFuncCallChain (KeliFuncCallChain x y) = (flattenFuncCallChain x ++ flattenFuncCallChain y)
flattenFuncCallChain (KeliPartialFuncCall ids params) = [(ids, params)]



keliFuncCallTail :: Parser KeliFuncCallChain
keliFuncCallTail
    = buildExpressionParser [[Infix (char '.' >> spaces >> return KeliFuncCallChain) AssocLeft]] keliPartialFuncCall


keliPartialFuncCall
    -- binary/ternary/polynary
    = try ((many1 $ try ( 
                    keliFuncId                     >>= \token 
                --  -> notFollowedBy (reservedOp "=") >>= \_
                 -> parens keliExpr                >>= \expr
                 -> return (token, expr)
            )) >>= \pairs
            -> return (KeliPartialFuncCall (map fst pairs) (map snd pairs))
    )
    -- unary
   <|> (
            keliFuncId  >>= \token
        ->  return (KeliPartialFuncCall [token] []))

keliAtomicExpr :: Parser Raw.Expr
keliAtomicExpr 
    =  parens keliExpr
   <|> (getPosition >>= \pos -> arrayLit    >>= \exprs -> return (Raw.Array exprs)) 
   <|> (getPosition >>= \pos -> try float   >>= \n   　-> return (Raw.NumberExpr (pos, Right n)))
   <|> (getPosition >>= \pos -> try natural >>= \n   　-> return (Raw.NumberExpr (pos, Left n)))
   <|> (getPosition >>= \pos -> stringLit   >>= \str 　-> return (Raw.StringExpr (pos, str)))
   <|> (                        keliFuncId  >>= \id  　-> return (Raw.Id id))

arrayLit :: Parser [Raw.Expr]
arrayLit 
    = between 
        (symbol "[") 
        (symbol "]") 
        (keliExpr `sepBy` (symbol ","))


stringLit :: Parser String
stringLit 
    =   try multilineString
    <|> singlelineString
    

multilineString :: Parser String
multilineString 
    =   string "\"\"\"" >>= \_
    ->  manyTill anyChar (try (string "\"\"\"" >> whiteSpace))
    <?> "end of multiline string literal"


keliFuncDecl :: Parser Raw.Decl
keliFuncDecl 
    =  try keliPolyFuncDecl
   <|> keliMonoFuncDecl

keliMonoFuncDecl :: Parser Raw.Decl
keliMonoFuncDecl
    =  optionMaybe stringLit  >>= \docstring
    -> keliGenericParams      >>= \genparams
    -> keliFuncDeclParam      >>= \param
    -> char '.' >> spaces     >>= \_ 
    -> keliFuncId             >>= \token
    -> keliFuncReturnType     >>= \typeExpr
    -> reservedOp "="         >>= \_
    -> keliExpr               >>= \expr
    -> return (Raw.FuncDecl (Raw.Func docstring (unpackMaybe genparams) [param] [token] typeExpr expr))

keliPolyFuncDecl :: Parser Raw.Decl
keliPolyFuncDecl   
    =  optionMaybe stringLit  >>= \docstring
    -> keliGenericParams      >>= \genparams
    -> keliFuncDeclParam      >>= \param1
    -> char '.' >> spaces     >>= \_ 
    -> keliIdParamPair        >>= \xs
    -> keliFuncReturnType     >>= \typeExpr
    -> reservedOp "="         >>= \_
    -> keliExpr               >>= \expr
    -> return (Raw.FuncDecl (Raw.Func docstring (unpackMaybe genparams) (param1:(map snd xs)) (map fst xs) typeExpr expr))

keliGenericTypeDecl :: Parser Raw.Decl
keliGenericTypeDecl
    =  getPosition        >>= \typenamePos
    -> identifier         >>= \typename
    -> char '.' >> spaces >>= \_ 
    -> keliIdParamPair    >>= \idParamPairs
    -> keliFuncReturnType >>= \typeExpr
    -> reservedOp "="     >>= \_
    -> keliExpr           >>= \expr
    -> return (Raw.GenericTypeDecl (typenamePos, typename) (map fst idParamPairs) (map snd idParamPairs) expr)

keliFuncReturnType :: Parser (Maybe Raw.Expr)
keliFuncReturnType = 
    optionMaybe (
       reservedOp "|"        >>= \_
    -> keliExpr              >>= \typeExpr
    -> optionMaybe stringLit >>= \_
    -> return typeExpr)

unpackMaybe :: Maybe [a] -> [a]
unpackMaybe (Just x) = x
unpackMaybe Nothing  = []


braces  = between (symbol "{") (symbol "}")
keliGenericParams :: Parser (Maybe [Raw.FuncDeclConstraint])
keliGenericParams 
    =  optionMaybe $ many1 $ (braces keliFuncDeclParam' >>= \param ->  return param)


keliIdParamPair = 
    many1 (
            keliFuncId           >>= \token 
        ->  keliFuncDeclParam    >>= \param
        -> return (token, param)) 

keliFuncId = 
        getPosition                   >>= \pos 
    ->  choice [identifier, operator] >>= \id
    ->  return (pos, id)

keliFuncDeclParam ::Parser (Raw.StringToken, Raw.Expr)
keliFuncDeclParam = 
    parens keliFuncDeclParam' >>= \params 
    -> optionMaybe stringLit  >>= \_ 
    -> return params

keliFuncDeclParam' ::Parser (Raw.StringToken, Raw.Expr)
keliFuncDeclParam' 
    =  
       keliFuncId     >>= \id
    -> keliExpr       >>= \typeExpr
    -> return (id, typeExpr)

preprocess :: String -> String
preprocess str = str
    -- just in case we need it in the future:
    -- let packed = T.pack str in
    -- T.unpack (T.replace "\n\n" "\n;;;\n" packed)

keliParse :: String -> String -> Either [KeliError] [Raw.Decl] 
keliParse filename input = 
    case parse keliParser filename (preprocess input) of
        Right decls -> Right decls
        Left parseError -> Left [KErrorParseError (errorPos parseError) (Messages (errorMessages parseError))]
