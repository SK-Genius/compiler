import Test.Hspec
import Control.Exception (evaluate)
import Parser
import Ast
import Debug.Trace
import Analyzer
import Data.Either
import StaticError
import Keli

testParseKeli x = 
    (case (parseKeli x) of
        Right _   -> True
        Left  err -> trace (show err) $ False) `shouldBe` True

getBaseCode = readFile "./kelilib/base.keli"

main :: IO ()
main = hspec $ do
    describe "keli exec" $ do
        it "multiple dispatch" $ do
            baseCode <- getBaseCode
            keli' (baseCode ++ "x:str.bom|str=undefined;x:int.bom|int=undefined;a=1 .bom;b=\"1\".bom;")

        it "generic keli func" $ do
            baseCode <- getBaseCode
            keli' (baseCode ++ "\n{a:any}x:a.id | a = x;this:int. ! |int=undefined;z=99;zz=z.id. !;")

        it "keli func" $ do
            baseCode <- getBaseCode
            keli' (baseCode ++ "x:int.+y:int|int=undefined;z=1 .+ 3;")
            keli' (baseCode ++ "this:str.replace old:str with new:str|str=undefined;z=\"hi\".replace\"i\" with \"h\";")

            -- duplicated func
            isLeft (keli'' (baseCode ++ "i:int.-j:int|int=undefined;i:int.-j:int|int=undefined;")) `shouldBe` True

        it "record creation" $ do
            keli' "animal=record.name \"dog\" age 5;"

        it "record getter" $ do
            keli' "animal=(record.name \"dog\").name;"

        it "record setter" $ do
            keli' "animal=(record.name \"dog\").name \"cat\";"

        it "record type declaration" $ do
            baseCode <- getBaseCode
            keli' (baseCode ++ "fruit=record.taste int; x=fruit.taste 3;")
        
        it "carryless tag" $ do
            baseCode <- getBaseCode
            keli' (baseCode ++ "boolean=_.tag true;x=true;")

        it "carryful tag" $ do
            baseCode <- getBaseCode
            keli' (baseCode ++ "intlist=_.tag nothing.or(_.tag cons carry int);x=cons.carry 2;")
            
            -- incorrect carry type
            isLeft (keli'' (baseCode ++ "color=_.tag red.or(_.tag green carry int);x=green.carry red;")) `shouldBe` True

        it "tag union" $ do
            baseCode <- getBaseCode
            keli' (baseCode ++ "boolean=_.tag true.or(_.tag false);a=true;b=false;")
        
        it "case checker" $ do
            baseCode <- getBaseCode

            -- complete tags
            keli' (baseCode ++ "yesOrNo=_.tag yes.or(_.tag no);a=yes;b=a.yes? 2 no? 1;")

            -- else tags
            keli' (baseCode ++ "yesOrNo=_.tag ok.or(_.tag nope);a=ok;b=a.ok? 2 else? 1;")

            -- missing tag `no`
            isLeft (keli'' (baseCode ++ "yesOrNo=_.tag yes.or(_.tag no);a=yes;b=a.yes? 2;")) `shouldBe` True

            -- excessive tag
            isLeft (keli'' (baseCode ++ "yesOrNo=_.tag yes.or(_.tag no);a=yes;b=a.yes? 2 no? 3 ok? 5;")) `shouldBe` True

            -- not all branches have same type
            isLeft (keli'' (baseCode ++ "yesOrNo=_.tag yes.or(_.tag no);a=yes;b=a.yes? 2 no? \"hi\";")) `shouldBe` True

            -- duplicated tags
            isLeft (keli'' (baseCode ++ "yesOrNo=_.tag yes.or(_.tag no);a=yes;b=a.yes? 2 no? 2 no? 3;")) `shouldBe` True

    describe "keli analyzer" $ do
        it "check for duplicated const id" $ do
            (case keli'' "x=5;x=5;" of Left (KErrorDuplicatedId _) -> True;_->False) `shouldBe` True
            isRight (keli'' "x=5;y=5;") `shouldBe` True

        it "keli record 2" $ do
            baseCode <- getBaseCode
            isRight (keli'' (baseCode ++ "dog=record.name \"dog\" age 9;")) `shouldBe` True
        

    describe "keli parser" $ do
        it "identifiers" $ do
            testParseKeli "_=0;"
            testParseKeli "even?=0;"

        it "comments" $ do
            -- comments are just string expressions!
            testParseKeli "=\"this is a comment\";pi=3.142;"

        it "lambda expr" $ do
            testParseKeli "hi = x | console.log x;"
            testParseKeli "hi = x y | x.+y;"

        it "multiple decl" $ do
            testParseKeli "x=5;y=5;"

        it "const decl" $ do
            testParseKeli "x=5;" 
            testParseKeli "=5;" 

        it "monofunc decl" $ do
            testParseKeli "this:string.reverse|string=undefined;"
            testParseKeli "this:string.! |string=undefined;"
            testParseKeli "{a:type}x:a.unit|a=undefined;"
            testParseKeli "{a:type b:type}x:(a.with b).invert|(b.with a)=x.second.with(x.first);"

        it "polyfunc decl" $ do
            testParseKeli "this:string.splitby that:string|string=undefined;"
            testParseKeli "this:string.replace that:string with the:string|string=undefined;"
            testParseKeli "this:int . == that:int|int=undefined;"

        it "monofunc call" $ do
            testParseKeli "=x.reverse;" 
            testParseKeli "=x.!;" 

        it "polyfunc call" $ do
            testParseKeli "=compiler.import x;" 
            testParseKeli "=x.replace a with b;" 
            testParseKeli "=x.+ y;" 