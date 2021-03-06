module Ast.Raw where 

import Prelude hiding (id)
import Text.Parsec.Pos
import Debug.Pretty.Simple (pTraceShowId, pTraceShow)

type StringToken = (SourcePos, String)
type NumberToken = (SourcePos, (Either Integer Double))

data Decl 
    = ConstDecl Const
    | FuncDecl Func
    | IdlessDecl 
        SourcePos -- the position of the `=` symbol
        Expr
    | GenericTypeDecl 
        StringToken     -- name
        [StringToken]   -- trailing ids
        [FuncDeclParam] -- type params
        Expr            -- type body
    deriving (Show, Eq)

data Const = Const { 
    constDeclId    :: StringToken, 
    constDeclValue :: Expr
} deriving (Show, Eq)

type FuncDeclParam = (StringToken, Expr)
type FuncDeclConstraint = (StringToken, Expr)

data Func = Func {
    funcDeclDocString     :: Maybe String,
    funcDeclGenericParams :: [FuncDeclConstraint],
    funcDeclParams        :: [FuncDeclParam],
    funcDeclIds           :: [StringToken],
    funcDeclReturnType    :: Maybe Expr,
    funcDeclBody          :: Expr
} deriving (Show, Eq)


data Expr 
    = NumberExpr NumberToken 
    | StringExpr StringToken
    | Id     StringToken
    | FuncCall {
        funcCallParams :: [Expr],
        funcCallIds    :: [StringToken]
    }
    | Lambda {
        lambdaParam  :: StringToken,
        lambdaBody   :: Expr
    }
    | IncompleteFuncCall -- for implementing Intellisense 
        Expr 
        SourcePos -- position of the dot operator

    | Array [Expr]

    deriving (Show,Eq)

