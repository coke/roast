use v6;
use Test;

#?DOES 1
sub throws_like($code, $ex_type, *%matcher) {
    my $msg;
    if $code ~~ Callable {
        $msg = 'code dies';
        $code()
    } else {
        $msg = "'$code' died";
        eval $code;
    }
    ok 0, $msg;
    skip 'Code did not die, can not check exception', 1 + %matcher.elems;
    CATCH {
        default {
            ok 1, $msg;
            my $type_ok = $_.WHAT === $ex_type;
            ok $type_ok , "right exception type ({$ex_type.^name})";
            if $type_ok {
                for %matcher.kv -> $k, $v {
                    my $got = $_."$k"();
                    my $ok = $got ~~ $v,;
                    ok $ok, ".$k matches {$v.defined ?? $v !! $v.gist}";
                    unless $ok {
                        diag "Got:      $got\n"
                            ~"Expected: $v";
                    }
                }
            } else {
                diag "Got:      {$_.WHAT.gist}\n"
                    ~"Expected: {$ex_type.gist}";
                diag "Exception message: $_.message()";
                skip 'wrong exception type', %matcher.elems;
            }
        }
    }
}

throws_like { Buf.new().Str }, X::Buf::AsStr, method => 'Str';;
throws_like 'pack("B",  1)',       X::Buf::Pack, directive => 'B';
throws_like 'Buf.new.unpack("B")', X::Buf::Pack, directive => 'B';
throws_like 'my class Foo { method a() { $!bar } }', X::Attribute::Undeclared,
            name => '$!bar', package-name => 'Foo';
throws_like 'sub f() { $^x }', X::Signature::Placeholder,
            line => 1;

#?rakudo skip 'parsing of $& and other p5 variables'
throws_like '$&', X::Obsolete, old => '$@ variable', replacement => '$, rx/<<rx>>// or $()';
throws_like 'qr/a/', X::Obsolete, old => rx/<<qr>>/, replacement => rx/<<rx>>/;

throws_like 'do    { $^x }', X::Placeholder::Block, placeholder => '$^x';
throws_like 'do    { @_  }', X::Placeholder::Block, placeholder => '@_';
throws_like 'class { $^x }', X::Placeholder::Block, placeholder => '$^x';
throws_like '$^x',           X::Placeholder::Mainline, placeholder => '$^x';
# RT #73502
throws_like '@_',            X::Placeholder::Mainline, placeholder => '@_';
# RT #85942
throws_like '"foo".{ say $^a }', X::Placeholder::Mainline;


throws_like 'sub f(*@a = 2) { }', X::Parameter::Default, how => 'slurpy';
throws_like 'sub f($x! = 3) { }', X::Parameter::Default, how => 'required';
throws_like 'sub f(:$x! = 3) { }', X::Parameter::Default, how => 'required';
throws_like 'sub f($:x) { }',  X::Parameter::Placeholder,
        parameter => '$:x',
        right     => ':$x';
throws_like 'sub f($?x) { }',  X::Parameter::Twigil,
        parameter => '$?x',
        twigil    => '?';
throws_like 'sub (Int Str $x) { }', X::Parameter::MultipleTypeConstraints;



# some of these redeclaration errors take different code
# paths in rakudo, so we over-test a bit to catch them all,
# even if the tests look rather boring;
throws_like 'my @a; my @a',  X::Redeclaration,      symbol => '@a';
throws_like 'sub a { }; sub a { }',X::Redeclaration, symbol => 'a', what => 'routine';
# RT #78370
#?rakudo skip 'RT 78370'
throws_like 'my &a; multi a { }', X::Redeclaration, symbol => 'a', what => 'routine';
throws_like 'sub a { }; multi sub a { }',X::Redeclaration, symbol => 'a', what => 'routine';
throws_like 'my class A { }; my class A { }',  X::Redeclaration, symbol => 'A';
throws_like 'my class B { }; my subset B of Any;', X::Redeclaration, symbol => 'B';
throws_like 'CATCH { }; CATCH { }', X::Phaser::Multiple, block => 'CATCH';

throws_like 'my class A { my @a; @a!List::foo() }',
    X::Method::Private::Permission,
    method          => 'foo',
    calling-package => 'A',
    source-package  => 'List';

throws_like '1!foo()',
    X::Method::Private::Unqualified,
    method          => 'foo';

throws_like 'sub f() { }; f() := 2', X::Bind::Comp;
throws_like 'my int $x := 2', X::Bind::NativeType;
throws_like 'my @a; @a[] := <foo bar baz>', X::Bind::ZenSlice, type => Array;
throws_like 'my %a; %a{} := foo=>1, bar=>2, baz=>3', X::Bind::ZenSlice, type => Hash;
throws_like 'my @a; @a[0, 1] := (2, 3)', X::Bind::Slice, type => Array;
throws_like 'my %a; %a<a b> := (2, 3)', X::Bind::Slice, type => Hash;


throws_like 'for (1; 1; 1) { }', X::Obsolete,
    old         => rx/<<for>>/,
    replacement => rx/<<loop>>/;
throws_like 'foreach (1..10) { }', X::Obsolete,
    old         => "'foreach'",
    replacement => "'for'";
throws_like 'undef', X::Obsolete,
    old         => rx/<<undef>>/;

throws_like 'my $a::::b', X::Syntax::Name::Null;
throws_like 'unless 1 { } else { }', X::Syntax::UnlessElse;
throws_like 'for my $x (1, 2, 3) { }', X::Syntax::P5;
throws_like ':!foo(3)', X::Syntax::NegatedPair;
throws_like 'my $0', X::Syntax::Variable::Numeric;
throws_like 'my sub f($0) { }', X::Syntax::Variable::Numeric, what => 'parameter';
throws_like 'my $<a>', X::Syntax::Variable::Match;
throws_like 'my class A { my $!foo }', X::Syntax::Variable::Twigil, twigil => '!', scope => 'my';
throws_like 'my $?FILE', X::Syntax::Variable::Twigil, twigil => '?', scope => 'my';
throws_like 'my $::("foo")', X::Syntax::Variable::IndirectDeclaration;
throws_like '@a', X::Undeclared, symbol => '@a';
throws_like 'augment class Any { }', X::Syntax::Augment::WithoutMonkeyTyping;
throws_like 'use MONKEY_TYPING; augment role Positional { }', X::Syntax::Augment::Role;
throws_like 'sub postbla:sym<foo>() { }', X::Syntax::Extension::Category, category => 'postbla';
# RT #83992
throws_like 'my @a = 1, => 2', X::Syntax::InfixInTermPosition, infix => '=>';
throws_like 'sub f(:in(:$in)) { }', X::Signature::NameClash, name => 'in';
throws_like 'my $foo does &Int', X::Does::TypeObject;
throws_like 'my $foo does &Int, &Bool', X::Does::TypeObject;
throws_like 'role R { }; 99 but R("wrong");', X::Role::Initialization;
throws_like 'role R { has $.x; has $.y }; 99 but R("wrong");', X::Role::Initialization;
throws_like 'role R { }; 99 does R("wrong");', X::Role::Initialization;
throws_like 'role R { has $.x; has $.y }; 99 does R("wrong");', X::Role::Initialization;

throws_like 'sub f($a?, $b) { }', X::Parameter::WrongOrder,
    misplaced   => 'required',
    after       => 'optional';
throws_like 'sub f(*@a, $b) { }', X::Parameter::WrongOrder,
    misplaced   => 'required',
    after       => 'variadic';
throws_like 'sub f(*@a, $b?) { }', X::Parameter::WrongOrder,
    misplaced   => 'optional positional',
    after       => 'variadic';

#?rakudo skip 'parsing regression'
throws_like '#`', X::Syntax::Comment::Embedded;
# RT #71814
throws_like "=begin\n", X::Syntax::Pod::BeginWithoutIdentifier, line => 1, filename => rx/eval/;

throws_like '@', X::Syntax::SigilWithoutName;
throws_like '1∞', X::Syntax::Confused;
throws_like 'for 1, 2', X::Syntax::Missing, what => 'block';
throws_like 'my @a()', X::Syntax::Reserved, reserved => /shape/ & /array/;
throws_like 'my &a()', X::Syntax::Reserved, instead  => /':()'/;

throws_like 'm:i(@*ARGS[0])/foo/', X::Value::Dynamic;
throws_like 'my enum Foo (:x(@*ARGS[0]))', X::Value::Dynamic;

throws_like 'self', X::Syntax::Self::WithoutObject;
throws_like 'class { has $.x = $.y }', X::Syntax::VirtualCall, call => '$.y';
throws_like '$.a', X::Syntax::NoSelf, variable => '$.a';

throws_like 'has $.x', X::Attribute::NoPackage;
throws_like 'my module A { has $.x }', X::Attribute::Package, package-type => 'module';

throws_like 'has sub a() { }', X::Declaration::Scope, scope => 'has', declaration => 'sub';
throws_like 'has package a { }', X::Declaration::Scope, scope => 'has', declaration => 'package';
throws_like 'our multi a() { }', X::Declaration::Scope::Multi, scope => 'our';
throws_like 'multi sub () { }', X::Anon::Multi, multiness => 'multi';
throws_like 'proto sub () { }', X::Anon::Multi, multiness => 'proto';
throws_like 'class { multi method () { }}', X::Anon::Multi, routine-type => 'method';
throws_like 'use MONKEY_TYPING; augment class { }', X::Anon::Augment, package-type => 'class';
throws_like 'use MONKEY_TYPING; augment class NoSuchClass { }', X::Augment::NoSuchType,
    package-type => 'class',
    package => 'NoSuchClass';
throws_like 'use MONKEY_TYPING; augment class No::Such::Class { }', X::Augment::NoSuchType,
    package => 'No::Such::Class';

throws_like ':45<abcd>', X::Syntax::Number::RadixOutOfRange, radix => 45;
throws_like ':0<0>', X::Syntax::Number::RadixOutOfRange, message => rx/0/;
throws_like 'rx:g/a/',   X::Syntax::Regex::Adverb, adverb => 'g', construct => 'rx';
throws_like 'my sub f($x, $y:) { }', X::Syntax::Signature::InvocantMarker;

throws_like 'Date.new("2012-02-30")', X::OutOfRange,
    range => Range, message => rx/<<1\.\.29>>/;
throws_like 'use fatal; "foo"[2]', X::OutOfRange, what => rx:i/index/, range => 0..0, got => 2;

throws_like 'sub f() { }; &f.unwrap("foo")', X::Routine::Unwrap;
throws_like 'Mu.new(1)', X::Constructor::Positional;
throws_like 'my %h = 1', X::Hash::Store::OddNumber;

# TOOD: might be X::Syntax::Malformed too...
throws_like 'sub foo;', X::Syntax::Missing, what => 'block';
throws_like 'constant foo;', X::Syntax::Missing, what => /initializer/;
throws_like 'constant * = 3;', X::Syntax::Missing, what => /constant/;

throws_like 'class A {...}; grammar B { ... }', X::Package::Stubbed, packages => <A B>;

throws_like 'my sub a { PRE 0  }; a()', X::Phaser::PrePost, phaser => 'PRE', condition => /0/;
throws_like 'my sub a { POST 0 }; a()', X::Phaser::PrePost, phaser => 'POST', condition => /0/;

throws_like 'use fatal; my $x = "5 foo" + 8;', X::Str::Numeric, source => '5 foo', pos => 1,
            reason => /trailing/;

throws_like '1.foo',  X::Method::NotFound, method => 'foo', typename => 'Int';
throws_like '1.+foo', X::Method::NotFound, method => 'foo', typename => 'Int';
throws_like 'my class Priv { method x { self!foo } }; Priv.x',
                      X::Method::NotFound,
                      method    => '!foo',
                      typename  => 'Priv',
                      private   => { $_ === True };
throws_like '1.List::join', X::Method::InvalidQualifier,
            method         => 'join',
            invocant       => 1,
            qualifier-type => List;

# RT #58558
throws_like '!!! 42', X::AdHoc, payload => 42;
throws_like 'use fatal; ... 42', X::AdHoc, payload => 42;
{
    my $c = 0;
    try {
        ??? 42;
        CONTROL { default { $c++ } }
    }
    is $c, 1, '??? with argument warns';
}

throws_like 'die "foo"', X::AdHoc, backtrace => Backtrace;
throws_like 'use fatal; ~(1, 2, 6 ... 10)', X::Sequence::Deduction;

throws_like 'my Str $x := 3', X::TypeCheck::Binding, got => Int, expected => Str;
throws_like 'sub f() returns Str { 5 }; f', X::TypeCheck::Return, got => Int, expected => Str;

throws_like '1.foo', X::Method::NotFound, method => 'foo', typename => 'Int';
throws_like 'my class NC { }; NC.new does NC', X::Mixin::NonComposable,
            :target(*.defined), :rolish(*.^name eq 'NC');
throws_like 'my class NC { }; NC.new but  NC', X::Mixin::NonComposable,
            :target(*.defined), :rolish(*.^name eq 'NC');

throws_like 'last', X::ControlFlow,
            illegal => 'last', enclosing => 'loop construct';
throws_like 'next', X::ControlFlow,
            illegal => 'next', enclosing => 'loop construct';
throws_like 'redo', X::ControlFlow,
            illegal => 'redo', enclosing => 'loop construct';

throws_like 'my package A { }; my class B is A { }', X::Inheritance::Unsupported;

throws_like 'my module Expo { sub f is export { }; { sub f is export { } } }',
                X::Export::NameClash, symbol => '&f';

#?rakudo skip 'segfaults'
throws_like '<a b> »+« <c>', X::HyperOp::NonDWIM,
            left-elems => 2, right-elems => 1,
            operator => { .name eq 'infix:<+>' };

throws_like '<a b> »+« <c>', X::HyperOp::NonDWIM,
            left-elems => 2, right-elems => 1;

throws_like 'my sub f() { gather { return } }; ~f()', X::ControlFlow::Return;

done;
