#
# This source code is under the Unlicense
#
use strict;
use warnings;
package Rena;

sub new {
    my $class = shift;
    my $option = shift;
    my $keys = defined $option && defined $option->{"keys"} ? $option->{"keys"} : 0;
    my $ignoreOrg = defined $option && defined $option->{"ignore"} ? $option->{"ignore"} : 0;
    my $ignore;
    if($ignoreOrg) {
        $ignore = sub {
            my $match = shift;
            my $index = shift;
            my ($matched, $indexNew, $attr) = $ignoreOrg->($match, $index, 0);
            if(defined $matched) {
                return $indexNew;
            } else {
                return $index;
            }
        };
    } else {
        $ignore = sub {
            my $match = shift;
            my $index = shift;
            return $index;
        };
    }
    my $opt = {
        ignoreOrg => $ignoreOrg,
        ignore => $ignore,
        keys => $keys
    };
    bless $opt, $class;
}

sub str {
    my $self = shift;
    my $str = shift;
    return sub {
        my $match = shift;
        my $lastIndex = shift;
        my $attr = shift;
        if(substr($match, $lastIndex, length($str)) eq $str) {
            return ($str, $lastIndex + length($str), $attr);
        } else {
            return (undef, undef, undef);
        }
    };
}

sub re {
    my $self = shift;
    my $regex = shift;
    return sub {
        my $match = shift;
        my $lastIndex = shift;
        my $attr = shift;
        $match = substr($match, $lastIndex, length($match) - $lastIndex);
        if($match =~ $regex && $-[0] == 0) {
            return (substr($match, $-[0], $+[0] - $-[0]), $+[0] + $lastIndex, $attr);
        } else {
            return (undef, undef, undef);
        }
    };
}

sub isEnd {
    my $self = shift;
    return sub {
        my $match = shift;
        my $lastIndex = shift;
        my $attr = shift;
        if($lastIndex >= length($match)) {
            return ("", $lastIndex, $attr);
        } else {
            return (undef, undef, undef);
        }
    };
}

sub concatSkip {
    my $self = shift;
    my $skip = shift;
    my @args = @_;
    return sub {
        my $match = shift;
        my $lastIndex = shift;
        my $attr = shift;
        my $matched = "";
        my $indexNew = $lastIndex;
        foreach my $exp (@args) {
            ($matched, $indexNew, $attr) = $exp->($match, $indexNew, $attr);
            if(!(defined $matched)) {
                return (undef, undef, undef);
            }
            $indexNew = $skip->($match, $indexNew);
        }
        return (substr($match, $lastIndex, $indexNew - $lastIndex), $indexNew, $attr);
    };
}

sub concat {
    my $self = shift;
    my @args = @_;
    return $self->concatSkip($self->{"ignore"}, @args);
}

sub choice {
    my $self = shift;
    my @args = @_;
    return sub {
        my $match = shift;
        my $lastIndex = shift;
        my $attr = shift;
        my $matched;
        my $indexNew;
        foreach my $exp (@args) {
            ($matched, $indexNew, $attr) = $exp->($match, $lastIndex, $attr);
            if(defined $matched) {
                return ($matched, $indexNew, $attr);
            }
        }
        return (undef, undef, undef);
    };
}

sub zeroOrMore {
    my $self = shift;
    my $exp = shift;
    return sub {
        my $match = shift;
        my $lastIndex = shift;
        my $attr = shift;
        my $indexNew = $lastIndex;
        while(1) {
            my ($matched, $indexLoop, $attrNew) = $exp->($match, $indexNew, $attr);
            if(defined $matched) {
                $indexNew = $self->{"ignore"}->($match, $indexLoop);
                $attr = $attrNew;
            } else {
                return (substr($match, $lastIndex, $indexNew - $lastIndex), $indexNew, $attr);
            }
        }
    };
}

sub lookahead {
    my $self = shift;
    my $exp = shift;
    my $sign = shift;
    $sign = 1 if !(defined $sign);
    return sub {
        my $match = shift;
        my $lastIndex = shift;
        my $attr = shift;
        my ($matched, $indexExp, $attrExp) = $exp->($match, $lastIndex, $attr);
        if(($sign && defined $matched) || (!$sign && !(defined $matched))) {
            return ("", $lastIndex, $attr);
        } else {
            return (undef, undef, undef);
        }
    };
}

sub lookaheadNot {
    my $self = shift;
    my $exp = shift;
    return lookahead($self, $exp, 0);
}

sub action {
    my $self = shift;
    my $exp = shift;
    my $action = shift;
    return sub {
        my $match = shift;
        my $lastIndex = shift;
        my $attr = shift;
        my ($matched, $indexExp, $attrSyn) = $exp->($match, $lastIndex, $attr);
        if(defined $matched) {
            return ($matched, $indexExp, $action->($matched, $attrSyn, $attr));
        } else {
            return (undef, undef, undef);
        }
    };
}

sub letrec {
    my $self = shift;
    my @args = @_;
    my $g = sub {
        my $g = shift;
        return $g->($g);
    };
    my $p = sub {
        my $p = shift;
        my @res = ();
        foreach my $li (@args) {
            (sub {
                my $li = shift;
                push @res, sub {
                    my $match = shift;
                    my $lastIndex = shift;
                    my $attr = shift;
                    return ($li->($p->($p)))->($match, $lastIndex, $attr);
                };
            })->($li);
        }
        return @res;
    };
    return ($g->($p))[0];
}

sub oneOrMore {
    my $self = shift;
    my $exp = shift;
    return $self->concat($exp, $self->zeroOrMore($exp));
}

sub opt {
    my $self = shift;
    my $exp = shift;
    return $self->choice($exp, $self->str(""));
}

sub attr {
    my $self = shift;
    my $val = shift;
    return $self->action($self->str(""), sub { return $val; });
}

sub real {
    my $self = shift;
    return $self->action(
        $self->re(qr/[\+\-]?(?:[0-9]+(?:\.[0-9]+)?|\.[0-9]+)(?:[eE][\+\-]?[0-9]+)?/),
        sub {
            my $match = shift;
            return $match + 0;
        });
}

sub key {
    my $self = shift;
    my $key = shift;
    my @skipKeys = ();

    if(!$self->{"keys"}) {
        die "Keys are not set";
    }
    foreach my $optKey (@{$self->{"keys"}}) {
        if(length($key) < length($optKey) && $key eq substr($optKey, 0, length($key))) {
            push @skipKeys, $self->str($optKey);
        }
    }
    return $self->concat($self->lookaheadNot($self->choice(@skipKeys)), $self->str($key));
}

sub notKey {
    my $self = shift;
    my @skipKeys = ();

    if(!$self->{"keys"}) {
        die "Keys are not set";
    }
    foreach my $optKey (@{$self->{"keys"}}) {
        push @skipKeys, $self->str($optKey);
    }
    return $self->lookaheadNot($self->choice(@skipKeys));
}

sub equalsId {
    my $self = shift;
    my $key = shift;
    my $optIgnore = $self->{"ignoreOrg"};
    my $optKeys = $self->{"keys"};
    my $notSkip = sub {
        my $match = shift;
        return shift;
    };

    if(!$optIgnore && !$optKeys) {
        return $self->str($key);
    } elsif($optIgnore && !$optKeys) {
        return $self->concatSkip($notSkip, $self->str($key), $self->choice($self->isEnd(), $self->lookahead($optIgnore)));
    } elsif($optKeys && !$optIgnore) {
        return $self->concatSkip($notSkip, $self->str($key), $self->choice($self->isEnd(), $self->lookaheadNot($self->notKey())));
    } else {
        return $self->concatSkip($notSkip, $self->str($key), $self->choice($self->isEnd(), $self->lookahead($optIgnore), $self->lookaheadNot($self->notKey())));
    }
}

1;

