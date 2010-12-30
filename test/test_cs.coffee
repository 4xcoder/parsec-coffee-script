Array.prototype.toString = -> '[ ' + (@join ', ') + ' ]'
Function.prototype.toString = -> "<FUNCTION>"

if false
    Object.prototype.toString = ->
        '{' + (("#{k}: #{v}" for k, v of @).join ', ') + '}'

cs = require "../src/CoffeeScriptParser"
gg = require "../src/GrammarGenerator"
{ tree, toIndentedString, equal:astEqual } = require '../src/Tree'

src = { }
ast = { }

# basic identifier
src.id = "foo"

# Don't accept keywords as id
src.fail_id = "if"

# function calls
src.calls = """
    foo()
    foo(bar)
    foo(bar, bar)
    foo bar
    foo bar, bar
    foo foo bar, bar
"""

# no space before function args
src.fail_call = "foo (1,2,3)"

# anonymous functions
src.lambda1 = """
    (x) -> x
    (x, y) -> x+y
    -> meh
    (x) -> (y) -> curry
"""
ast.lambda1 = [
    tree 'Function', [tree 'Id', 'x'], [tree 'Id', 'x']
    tree 'Function',
        [(tree 'Id', 'x'), (tree 'Id', 'y')],
        [tree 'Op', '+',
            (tree 'Id', 'x'),
            (tree 'Id', 'y')]
    tree 'Function', [ ], [tree 'Id', 'meh']
    tree 'Function', [tree 'Id', 'x'],
        [tree 'Function', [tree 'Id', 'y'],
            [tree 'Id', 'curry']]]

src.lambda2 = '''
  ->
  (a) ->
  () ->
  -> b()
  ->
     c()
     d()
  (e) ->
     f()
'''

ast.lambda2 = [
    (tree 'Function', [], []),
    (tree 'Function', [tree 'Id', 'a'], []),
    (tree 'Function', [], []),
    (tree 'Function', [], [tree 'Call', (tree 'Id', 'b'), []]),
    (tree 'Function', [], [
        (tree 'Call', (tree 'Id', 'c'), []),
        (tree 'Call', (tree 'Id', 'd'), [])]),
    (tree 'Function', [tree 'Id', 'e'],
        [(tree 'Call', (tree 'Id', 'f'), [])])]

src.lambda3 = '''
    first = (a, b...) -> a
    last  = (a..., b) -> b
'''

ast.lambda3 = [
    (tree 'Op', '=',
        (tree 'Id', 'first'),
        (tree 'Function', [(tree 'Id', 'a'), (tree 'Id', 'b')], [tree 'Id', 'a'], 1)),
    (tree 'Op', '=',
        (tree 'Id', 'last'),
        (tree 'Function', [(tree 'Id', 'a'), (tree 'Id', 'b')], [tree 'Id', 'b'], 0))]

src.fail_lambda1 = '(a, b..., c...) -> "at most one splatted arg"'

# super invocations
src.super = """
    super
    super 1, 2, 3
    super(1,2,3)
"""

ast.super = [
    tree 'Super'
    tree 'Call', (tree 'Super'), [
        (tree 'Number', 1)
        (tree 'Number', 2)
        (tree 'Number', 3) ]
    tree 'Call', (tree 'Super'), [
        (tree 'Number', 1)
        (tree 'Number', 2)
        (tree 'Number', 3) ] ]


# as for functions, no space before args in parentheses
src.fail_super = "super (1,2)"

src.splat = """
    f x...
    (x...) -> y
    (a,b...,c) ->
"""

ast.splat = [
    tree 'Call', (tree 'Id', 'f'), [
        tree 'Op', '...', (tree 'Id', 'x') ]
    tree 'Function',
        [tree 'Id', 'x']
        [tree 'Id', 'y'], 0
    tree 'Function', [
        (tree 'Id', 'a')
        (tree 'Id', 'b')
        (tree 'Id', 'c') ], [ ], 1 ]


# Splats not accepted except as args or params
src.fail_splat = """
    x...
"""

# at-sign
src.at = """
    foo @
    @foo
    @
    @foo(a, @b, @c)
    @foo a, @b, @c
    @[1]
"""

src.fail_at = """
    @@
"""

src.accessor = """
    x[1]
    x[1][2][3]
    x.y
    x.class
    x[1..10]
    x[1...10]
"""

src.array_arg = """
    f [1,2]
    g([2])
"""

# multiple values -> index forbidden
src.fail_array = """
    x[1,2]
"""

# This is accepted because it's a list arg, not an index
# TODO: doesn't work without parentheses, indentation handling also broken.
src.not_an_accessor = """
    x( [a,b,c])
"""

src.array = """
    a1=[a, b, c]
    a2 = [d, e,
        f]
    [g,
    h,
    i]
    [j, k,
        l, m,
    n, o]
    [p, q,]
    [r,
    ]
    [ f x
      a
       b
      c, d]
"""

src.object1 = """
obj = { a:1; b:{c:1} }
"""

src.object2 = """
obj = {
    a:1
    b:2,
    c:3
    d:{e:4; f:5}
}
"""

ast.object2 = [
    tree 'Op', '=', (tree 'Id', 'obj'),
        tree 'Object', [
            [ 'a', (tree 'Number', 1) ]
            [ 'b', (tree 'Number', 2) ]
            [ 'c', (tree 'Number', 3) ]
            [ 'd',  tree 'Object', [
                [ 'e', (tree 'Number', 4) ]
                [ 'f', (tree 'Number', 5) ]]]]]

src.object3 = '''
{
    a: {
        b: {
            c:1
        d:2 } } }
'''

src.operators = """
    a + b * c
    d ? e ? f
    d? ? e? ? f?
    a++
    ++b
    a++ + ++b
    ++--x--++
    -1 - - --2
"""

src.if1 = """
    if cond
        a
        b
        c
"""

src.if2 = """
    if cond then a; b; c
"""

src.if3 = """
    doit() if condition
"""

src.if4 = """
    doit() if cond1 if cond2
"""

src.string1 = """
    x = "string"
"""

src.string2 = '''
    x = "text#{symbol}textAgain"
'''

src.string3 = '''
    x = "t1#{esc1 "t2#{esc2}*t2"}t1"
'''

src.cmp1 = '''
    x<1
    x>2
    x==3
    x is 4
'''

src.cmp2 = '''
    w<x<y<z
'''

ast.cmp2 = [
    (tree 'Op', '<',
        (tree 'Op', '<',
            (tree 'Op', '<',
                (tree 'Id', 'w'),
                (tree 'Id', 'x')),
            (tree 'Id', 'y')),
        (tree 'Id', 'z')) ]


# Determine the set of test names to run
# src: test suite
# regexes: list of regexes, presumably passed from command line
getTestsToRun = (src, regexes) ->
    tests = { }
    if regexes.length is 0
        (tests[name] = true) for name of src
    else
        used_regexes = { }
        for name of src
            for regex in regexes
                if name.match regex
                    tests[name] = true
                    used_regexes[regex]  = true
                    break
        for regex in regexes
            unless used_regex[regex]
                print "Warning, unused regex '#{regex}'\n"
    return tests

# Run one test.
# name: name of the test. The test must fail iff the name starts with "fail_".
# src:  source string of the test.
# ast:  AST that must be produced as a result (optional).
# logger: what to do if a test fails.
runTest = (name, src, ast, logger) ->
    logger ?= print
    print "\n***** Test #{name} *****\n"
    t = cs.parse src
    hasFailed  = t is gg.fail
    shouldFail = name.match /^fail_/
    if ast?
        astFailed = not astEqual ast, t
        hasFailed ||= astFailed
        #if astEqual(a,t) != (a.toString()==t.toString())
        #    print "\nEquality test failed for #{a} and #{t}!!!\n"
    else astFailed = false

    if hasFailed and shouldFail
        print "\n#{name} input:\n#{src}\n\nCompilation of #{name} failed, as expected\n"
        return true
    else if astFailed and not shouldFail
        logger "Failure, invalid tree for src.#{name}\nexp: #{ast}\ngot: #{t}"
        return false
    else if hasFailed and not shouldFail
        logger "Failure, cannot parse src.#{name}"
        return false
    else if not hasFailed and shouldFail
        logger "Test #{name} should have failed"
        return false
    else if not hasFailed and not shouldFail
        print "\n#{name} input:\n#{src}\n\n#{name} result:\n#{toIndentedString t}\n"
        return true

main = (args) ->

    log = [ ]
    logger = (msg) ->
        print "\n>>>>>>>>> ERROR: #{msg}\n"
        log.push msg

    total = success = 0
    for name of getTestsToRun(src, args)
        total++
        success++ if runTest name, src[name], ast[name], logger
    if total == success
        print "\nAll #{total} tests passed successfully\n"
    else
        print "\n#{total-success} failures out of #{total}:\n\n#{log.join '\n\n'}\n"

main (process.argv)

#TODO: src finishing with a comment

