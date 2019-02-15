module Unify where 

import Control.Monad

import qualified Ast.Verified as V
import Util
import Env
import StaticError
import Prelude hiding(lookup)
import Data.List hiding(lookup)
import qualified Data.Map.Strict as Map
import StaticError

type Substitution = Map.Map String V.Type

emptySubstitution :: Map.Map String V.Type
emptySubstitution = Map.empty

type UnifyResult = Either KeliError Substitution

unify :: 
       V.Expr  -- actual expr (for reporting error location only)
    -> V.Type  -- expected type
    -> UnifyResult

unify (V.Expr actualExpr actualType) expectedType =
    unify' actualExpr actualType expectedType

unify' :: 
       V.Expr' -- actual expr (for reporting error location only)
    -> V.Type  -- actual type
    -> V.Type  -- expected type
    -> UnifyResult

-- unify' type variables
unify' actualExpr (V.FreeTypeVar name constraint) t =
    unifyTVar actualExpr name constraint t

unify' actualExpr t (V.FreeTypeVar name constraint) =
    unifyTVar actualExpr name constraint t

-- unify' named types
unify' _ (V.TypeFloat) (V.TypeFloat) = 
    Right (emptySubstitution)  

unify' _ (V.TypeInt) (V.TypeInt) = 
    Right (emptySubstitution)  

unify' _ (V.TypeString) (V.TypeString) = 
    Right (emptySubstitution)  

-- unify' bounded type variables
unify' 
    actualExpr 
    actualType@(V.BoundedTypeVar name1 constraint1) 
    expectedType@(V.BoundedTypeVar name2 constraint2) = 
    if name1 == name2 then
        Right (emptySubstitution)  
    else
        Left (KErrorTypeMismatch actualExpr actualType expectedType)

-- unify' carryful tag counstructor
unify' 
    actualExpr 
    actualType@(V.TypeCarryfulTagConstructor x _ _ _)
    expectedType@(V.TypeCarryfulTagConstructor y _ _ _) = 
    if x == y then 
        Right (emptySubstitution)  
    else 
        Left (KErrorTypeMismatch actualExpr actualType expectedType)

unify' 
    actualExpr
    actualType@(V.TypeRecordConstructor kvs1)
    expectedType@(V.TypeRecordConstructor kvs2) = 
    undefined

unify' _ V.TypeType V.TypeType = 
    undefined

-- unify' tagged union
unify'
    actualExpr
    actualType@(V.TypeTaggedUnion (V.TaggedUnion name1 _ _ actualInnerTypes))
    expectedType@(V.TypeTaggedUnion (V.TaggedUnion name2 _ _ expectedInnerTypes)) = 
    if name1 == name2 && (length actualInnerTypes == length expectedInnerTypes) then do
        foldM 
            (\prevSubst (actualInnerType, expectedInnerType) -> do
                nextSubst <- unify' actualExpr actualInnerType expectedInnerType
                Right (composeSubst prevSubst nextSubst))
            emptySubstitution
            (zip actualInnerTypes expectedInnerTypes)
    else 
        Left (KErrorTypeMismatch actualExpr actualType expectedType)


-- unfify record type
-- record type is handled differently, because we want to have structural typing
-- NOTE: kts means "key-type pairs"
unify' actualExpr (V.TypeRecord kts1) (V.TypeRecord kts2) = 
    let (actualKeys, actualTypes) = unzip kts1 in
    let (expectedKeys, expectedTypes) = unzip kts2 in
    -- TODO: get the set difference of expectedKeys with actualKeys
    -- because we want to do structural typing
    -- that means, it is acceptable if actualKeys is a valid subset of expectedKeys
    case match actualKeys expectedKeys of
        PerfectMatch ->
            foldM
                (\prevSubst (key, actualType, expectedType) -> 
                    case unify' actualExpr actualType expectedType of
                        Right nextSubst ->
                            Right (composeSubst prevSubst nextSubst)

                        Left KErrorTypeMismatch{} ->
                            Left (KErrorPropertyTypeMismatch key expectedType actualType actualExpr )

                        Left err ->
                            Left err)
                emptySubstitution
                (zip3 expectedKeys actualTypes expectedTypes)

        GotDuplicates duplicates ->
            Left (KErrorDuplicatedProperties duplicates)

        GotExcessive excessiveProps ->
            Left (KErrorExcessiveProperties excessiveProps)
        
        Missing missingProps ->
            Left (KErrorMissingProperties actualExpr missingProps)

        ZeroIntersection ->
            Left (KErrorMissingProperties actualExpr (map snd expectedKeys))
        

unify' actualExpr actualType expectedType =  Left (KErrorTypeMismatch actualExpr actualType expectedType)


unifyTVar :: V.Expr' -> String -> Maybe V.TypeConstraint -> V.Type -> UnifyResult
unifyTVar actualExpr tvarname1 constraint1 t2 =
    -- NOTE: actualExpr is used for reporting error location only
    let result = Right (Map.insert tvarname1 t2 emptySubstitution) in
    case t2 of
        V.FreeTypeVar tvarname2 constraint2 ->
            if tvarname1 == tvarname2 then
                Right emptySubstitution
            else
                result

        _ ->
            if t2 `contains` tvarname1 then
                Left (KErrorTVarSelfReferencing actualExpr tvarname1 t2)
            else
                result 


contains :: V.Type -> String -> Bool
t `contains` tvarname = 
    case t of
        V.FreeTypeVar name _ ->
            name == tvarname

        V.TypeTaggedUnion (V.TaggedUnion _ _ _ types) ->
            any (`contains` tvarname) types

{- 
    Composing substitution s1 and s1

     For example if 

        s1 = {t1 => Int, t3 => t2} 
        s2 = {t2 => t1}

    Then the result will be

        s3 = {
            t1 => Int,
            t2 => Int,
            t3 => Int
        }
-}
composeSubst :: Substitution -> Substitution -> Substitution 
composeSubst s1 s2 =
    let result = 
            foldl 
                (\subst (key, type') -> Map.insert key (applySubstitutionToType s1 type') subst) 
                emptySubstitution
                ((Map.assocs s2)::[(String, V.Type)]) in

    -- cannot be Map.union result s1
    -- because we want keys in result to override duplicates found in s1
    Map.union result s1


-- Replace the type variables in a type that are
-- present in the given substitution and return the
-- type with those variables with their substituted values
-- eg. Applying the substitution {"a": Bool, "b": Int}
-- to a type (a -> b) will give type (Bool -> Int)
applySubstitutionToType :: Substitution -> V.Type -> V.Type
applySubstitutionToType subst type' =
    case type' of
        V.FreeTypeVar name constraint ->
            case Map.lookup name subst of
                Just t ->
                    t
                Nothing ->
                    type'

        V.TypeTaggedUnion (V.TaggedUnion name ids tags innerTypes) ->
            V.TypeTaggedUnion (V.TaggedUnion name ids tags (map (applySubstitutionToType subst) innerTypes))

        other ->
            other