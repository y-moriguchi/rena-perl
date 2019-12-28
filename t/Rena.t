#
# This source code is under the Unlicense
#
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More;
use Rena;

sub match {
    my $exp = shift;
    my $toMatch = shift;
    my $expectedMatch = shift;
    my $expectedIndex = shift;
    my ($matched, $index, $attr) = $exp->($toMatch, 0, 0);
    is($matched, $expectedMatch);
    is($index, $expectedIndex);
}

sub matchAttr {
    my $exp = shift;
    my $toMatch = shift;
    my $attr = shift;
    my $expectedMatch = shift;
    my $expectedIndex = shift;
    my $expectedAttr = shift;
    my ($matched, $index, $attrNew) = $exp->($toMatch, 0, $attr);
    is($matched, $expectedMatch);
    is($index, $expectedIndex);
    is($attrNew, $expectedAttr);
}

sub nomatch {
    my $exp = shift;
    my $toMatch = shift;
    my ($matched, $index, $attr) = $exp->($toMatch, 0, 0);
    ok(!defined $matched);
}

my $r = Rena->new();
my $r01 = Rena->new({ ignore => $r->re(qr/[\s]+/) });
my $r02 = Rena->new({ keys => ["+", "++", "+=", "-"] });
my $r03 = Rena->new({ ignore => $r->re(qr/[\s]+/), keys => ["+", "++", "+=", "-"] });

my $a001 = $r->str("765");
match($a001, "765pro", "765", 3);
nomatch($a001, "961pro");
nomatch($a001, "");

my $a002 = $r->re(qr/[0-9]{3}/);
match($a002, "765", "765", 3);
match($a002, "346", "346", 3);
nomatch($a002, "***");

my $a003 = $r->isEnd();
match($a003, "", "", 0);
nomatch($a003, "961");

my $a004 = $r->concat($r->str("765"), $r->str("pro"));
match($a004, "765pro", "765pro", 6);
nomatch($a004, "961pro");
nomatch($a004, "765aaa");
nomatch($a004, "765");

my $a005 = $r->choice($r->str("765"), $r->str("346"));
match($a005, "765", "765", 3);
match($a005, "346", "346", 3);
nomatch($a005, "961");

my $a006 = $r->zeroOrMore($r->re(qr/[a-z]/));
match($a006, "abd", "abd", 3);
match($a006, "", "", 0);

my $a007 = $r->lookahead($r->str("765"));
match($a007, "765", "", 0);
nomatch($a007, "346");
nomatch($a007, "961");

my $a008 = $r->lookaheadNot($r->str("961"));
match($a008, "765", "", 0);
match($a008, "346", "", 0);
nomatch($a008, "961");

my $a009 = $r->action($r->re(qr/[0-9]{3}/), sub {
    my $match = shift;
    my $syn = shift;
    my $inh = shift;
    return $match + $inh;
});
matchAttr($a009, "765", 346, "765", 3, 1111);
nomatch($a009, "abd");

my $a010 = $r->letrec(sub {
    my $a = shift;
    return $r->choice($r->concat($r->str("("), $a, $r->str(")")), $r->str(""));
});
match($a010, "((())))", "((()))", 6);
match($a010, "((())", "", 0);

my $a011 = $r->oneOrMore($r->re(qr/[a-z]/));
match($a011, "abd", "abd", 3);
match($a011, "a", "a", 1);
nomatch($a011, "");

my $a012 = $r->opt($r->str("765"));
match($a012, "765", "765", 3);
match($a012, "961", "", 0);

my $a013 = $r->attr(27);
matchAttr($a013, "", 0, "", 0, 27);

my $a014 = $r->real();
sub assertReal {
    my $toMatch = shift;
    my $expected = shift;
    my ($matched, $lastIndex, $attr) = $a014->($toMatch, 0, 0);
    is($attr, $expected);
}
assertReal("765", 765);
assertReal("76.5", 76.5);
assertReal("0.765", 0.765);
assertReal(".765", 0.765);
assertReal("765e2", 76500);
assertReal("765E2", 76500);
assertReal("765e+2", 76500);
assertReal("765e-2", 7.65);
#assertReal("765e+346", Infinity);
assertReal("765e-346", 0);
nomatch($a014, "a961");
assertReal("+765", 765);
assertReal("+76.5", 76.5);
assertReal("+0.765", 0.765);
assertReal("+.765", 0.765);
assertReal("+765e2", 76500);
assertReal("+765E2", 76500);
assertReal("+765e+2", 76500);
assertReal("+765e-2", 7.65);
#assertReal("+765e+346", Infinity);
assertReal("+765e-346", 0);
nomatch($a014, "+a961");
assertReal("-765", -765);
assertReal("-76.5", -76.5);
assertReal("-0.765", -0.765);
assertReal("-.765", -0.765);
assertReal("-765e2", -76500);
assertReal("-765E2", -76500);
assertReal("-765e+2", -76500);
assertReal("-765e-2", -7.65);
#assertReal("-765e+346", -Infinity);
assertReal("-765e-346", 0);
nomatch($a014, "-a961");

my $a015 = $r02->key("+");
match($a015, "+!", "+", 1);
nomatch($a015, "++");
nomatch($a015, "+=");
nomatch($a015, "-");

my $a016 = $r02->notKey();
match($a016, "!", "", 0);
nomatch($a016, "+");
nomatch($a016, "++");
nomatch($a016, "+=");
nomatch($a016, "-");

my $a017 = $r->equalsId("key");
match($a017, "key", "key", 3);
match($a017, "keys", "key", 3);
match($a017, "key+", "key", 3);
match($a017, "key ", "key", 3);

my $a018 = $r01->equalsId("key");
match($a018, "key", "key", 3);
nomatch($a018, "keys");
nomatch($a018, "key+", "key", 3);
match($a018, "key ", "key", 3);

my $a019 = $r02->equalsId("key");
match($a019, "key", "key", 3);
nomatch($a019, "keys");
match($a019, "key+", "key", 3);
nomatch($a019, "key ");

my $a020 = $r03->equalsId("key");
match($a020, "key", "key", 3);
nomatch($a020, "keys");
match($a020, "key+", "key", 3);
match($a020, "key ", "key", 3);

my $a021 = $r01->concat($r01->str("765"), $r01->str("pro"));
match($a021, "765  pro", "765  pro", 8);
match($a021, "765pro", "765pro", 6);
nomatch($a021, "765  aaa");

my $a022 = $r01->oneOrMore($r01->re(qw/[a-z]/));
match($a022, "a  b d", "a  b d", 6);
match($a022, "abd", "abd", 3);
nomatch($a022, "961");

done_testing();

