# Keli Compiler

## Namings
Refer Glossary.md

## How to run the binary?

```
stack build
./.stack-work/install/x86_64-linux/lts-13.0/8.6.3/bin/keli-compiler-exe
```

## How to setup this project?

```
stack build
```

## How to run test?

```
stack test --file-watch
```

## How to run ghci?

The following command is to prevent stack overflow due to unknown infinite loop.

Refer https://stackoverflow.com/questions/35342591/haskell-limit-ghci-memory

```sh
stack ghci --package pretty-simple --ghci-options="+RTS -M256m -K256m -RTS -interactive-print=Text.Pretty.Simple.pPrint -Wall" 
```

## Versioning

We will be using SemVer + CalVer, as the following format:

```md
MAJOR.YY.MM.DD
```

## Some extra documentation about Data.Map.Ordered

```hs
-- assocs means valuesOf
-- For example,
--  assocs x
--      means, get the list of key-value pair from x (which is arranged according to insertion order)
-- |> means insert
-- For example,
--      x |> (key, value)
--          means, insert (key,value) into x
-- For more please refer http://hackage.haskell.org/package/ordered-containers-0.1.1/docs/Data-Map-Ordered.html
```

## References

### Algorithm W implemented in Haskell
http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.65.7733&rep=rep1&type=pdf