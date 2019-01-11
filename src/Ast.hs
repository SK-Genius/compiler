module Ast where 

import Text.Parsec.Pos
import Data.List

type StringToken = (SourcePos, String)
type NumberToken = (SourcePos, (Either Integer Double))

data KeliDecl 
    = KeliConstDecl KeliConst
    | KeliFuncDecl KeliFunc
    | KeliIdlessDecl KeliExpr
    deriving (Show)

data KeliConst = KeliConst { 
    constDeclId    :: StringToken, -- because we can ignore the identifier
    constDeclValue :: KeliExpr,
    constDeclType  :: Maybe KeliType
} deriving (Show)

data KeliFunc = KeliFunc {
    funcDeclGenericParams :: [KeliFuncDeclParam],
    funcDeclParams        :: [KeliFuncDeclParam],
    funcDeclIds           :: [StringToken],
    funcDeclReturnType    :: KeliType,
    funcDeclBody          :: KeliExpr
} deriving (Show)

data KeliFuncDeclParam 
    = KeliFuncDeclParam {
        funcDeclParamId   :: StringToken,
        funcDeclParamType :: KeliType
    }
    deriving (Show)

data KeliType  
    = KeliTypeUnverified KeliExpr
    | KeliTypeFloat
    | KeliTypeInt
    | KeliTypeString
    | KeliTypeRecord [(StringToken, KeliType)]
    | KeliTypeTagUnion [StringToken] -- list of tags
    | KeliTypeAlias StringToken 
    | KeliTypeSingleton StringToken
    | KeliTypeUndefined
    deriving (Show, Eq)

data KeliTag
    = KeliTagCarryless 
        StringToken -- tag
        KeliType    -- belonging type

    | KeliTagCarryful
        StringToken -- tag
        KeliType    -- carry type
        KeliType    -- beloging type
            deriving (Show, Eq)

data KeliExpr 
    = KeliNumber NumberToken 
    | KeliString StringToken
    | KeliId     StringToken
    | KeliFuncCall {
        funcCallParams :: [KeliExpr],
        funcCallIds    :: [StringToken]
    }
    | KeliLambda {
        lambdaParams :: [StringToken],
        lambdaBody   :: KeliExpr
    }
    | KeliRecord {
        recordKeyValues :: [(StringToken, KeliExpr)]
    }
    | KeliRecordGetter {
        recordGetterSubject      :: KeliExpr,
        recordGetterPropertyName :: StringToken
    }
    | KeliRecordSetter {
        recordSetterSubject      :: KeliExpr,
        recordSetterPropertyName :: StringToken,
        recordSetterNewValue     :: KeliExpr
    }
    | KeliTagMatcher {
        tagMatcherSubject    :: KeliExpr,
        tagMatcherBranches   :: [(StringToken, KeliExpr)], -- [(Tag, KeliExpr)]
        tagMatcherElseBranch :: Maybe KeliExpr
    } 
    | KeliTagConstructor {
        tagConstructorId    :: StringToken,
        tagConstructorCarry :: Maybe KeliExpr
    } 
    | KeliTypeCheckedExpr {
        _expr :: KeliExpr,
        _type :: KeliType
    }
    | KeliTypeExpr KeliType

    | KeliCarrylessTagExpr 
        StringToken -- tag

    | KeliCarryfulTagExpr
        StringToken -- tag
        KeliExpr    -- carry

    | KeliTagUnionExpr [KeliTag]

    deriving (Show, Eq)

class Identifiable a where
    getIdentifier :: a -> StringToken

instance Identifiable KeliDecl where
    getIdentifier d = case d of
        KeliConstDecl c -> getIdentifier c
        KeliFuncDecl  f -> getIdentifier f

instance Identifiable KeliFunc where
    getIdentifier (KeliFunc{funcDeclIds=ids, funcDeclParams=params})
        = (
            fst (head ids)
            ,
            intercalate "$" (map snd ids) ++ intercalate "$" (map (toString . funcDeclParamType) params) 
        )

instance Identifiable KeliConst where
    getIdentifier c = constDeclId c



instance Identifiable KeliType where
    getIdentifier x = (newPos "" (-1) (-1), toString x)

class Stringifiable a where
    toString :: a -> String

instance Stringifiable KeliType where
    toString t = case t of
        KeliTypeFloat  -> "float"
        KeliTypeInt    -> "int"
        KeliTypeString -> "str"
        KeliTypeRecord kvs -> undefined
        KeliTypeTagUnion tags -> undefined
        KeliTypeAlias (_,id) -> id
        KeliTypeUnverified expr -> "unknown"


class HaveType a where
    getType :: a -> KeliType


instance HaveType KeliExpr where
    getType (KeliTypeCheckedExpr _ exprType) = getType exprType
    getType e = KeliTypeUnverified e
    getType _ = undefined


instance HaveType KeliType where
    getType (KeliTypeUnverified expr) = getType expr
    getType t = t