module StaticError where 

import Ast
import Text.ParserCombinators.Parsec

data KeliError 
    = KErrorParseError ParseError
    | KErrorDuplicatedId StringToken
    | KErrorIncorrectUsageOfRecord StringToken
    | KErrorIncorrectUsageOfTag
    | KErrorIncorrectUsageOfTaggedUnion
    | KErrorUnmatchingFuncReturnType KeliType KeliType
    | KErrorUsingUndefinedFunc [StringToken]
    | KErrorUsingUndefinedId StringToken
    | KErrorWrongTypeInSetter
    | KErrorExcessiveTags [StringToken]
    | KErrorMissingTags [String]
    | KErrorNotAllBranchHaveTheSameType [(StringToken,KeliExpr)]
    | KErrorDuplicatedTags [StringToken]
    | KErrorNotAType KeliExpr
    | KErrorUsingUndefinedType KeliExpr
    | KErrorIncorrectCarryType
        KeliType -- expected type
        KeliExpr -- actual expr
    deriving(Show)