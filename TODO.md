# THIS FILE IS OBSOLETED
# PLEASE REFER TO GITHUB ISSUES

[x] implement intellisense (refer Haskero)
    - the intellisense should show every possible function for a type
    - For example, if I type `1.`, a list of functions that takes `Int` as any parameter should show up


[] each function decl should be assign a uniq UID, to ease transpilation

[x] error reporting does not contain accurate location

[x] define factorial function

[x] js ffi

[x] problem: cannot map JS boolean to Keli boolean

[] should check for duplciated IDS first before going into analyzing

[] import base code when starting repl

[x] when using tag constructor, should be prefixed by the tagged union name, e.g. use `list.cons` instead of `cons`

[x] replace ":" with ".as" for type-annotated expressions

[x] remove singleton constant feature (can be emulated using tagged union)

[x] change primitive type to PascalCase

[x] implement generic tagged union

[] incomplete function expr does not capture function call chaining

[] combine syntax highlighter with language server

[x] location of error regarding (expected expr not type) is inaccurate

[] make Type into GenericType and ConcreteType (to ease the process of unification)

[] join child error with parent error

[x] update syntax of carryful tag and tag matcher

[] implement generic object

[] implement interface

[x] implement function type

[] update doc regarding constraint type

[] implement bindingful else branch for tag matcher

[] refactor to use type annotation 

[x] return context whenever typechecking expr

[] change transpile prefix from "$" to "k$" to reduce conflicts

[] Add docstring for functions and completion items

[] Add button for running a keli file

[] When completing a function with lambda, automatically writes out `x | x`