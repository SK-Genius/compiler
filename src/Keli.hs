module Keli where

import Transpiler
import Parser
import Compiler
import Analyzer
import SymbolTable
import qualified Data.HashMap.Strict as H
import Debug.Trace
import Debug.Pretty.Simple (pTraceShowId)
import Text.Pretty.Simple (pPrint)
import Data.List
import System.Process

keli filename = do
    contents <- readFile filename
    keli' contents 

keli' contents = do
    case (keli'' contents) of
        Right code -> callCommand ("node -e " ++ show code)
        Left err -> pPrint err
    

keli'' contents
    =   parseKeli contents
    >>= buildSymTab 
    >>= analyze     
    >>= transpile'  
    where 
        transpile' symtab = return (intercalate ";\n" (map transpile (H.elems symtab)))