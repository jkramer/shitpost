#!/usr/bin/env perl

use Mojolicious::Lite;

use List::Util qw'sum0 max';

plugin 'config';

use constant EXAMPLE => 'Wie kacke ist dein Titel? Diese 5 Antworten könnten dich überraschen!';


get '/' => sub {
  my ($c) = @_;

  my $title = $c->param('title') || EXAMPLE;

  $c->param(title => $title);

  $c->render('index', score => $c->shit_score($title));
};


helper shit_score => sub {
  my ($c, $title) = @_;

  my %score;
  my @chunks = split /[:?!.]\s+|\s+-\s+/, $title;

  my @patterns = (
    [ 30, 'article', 'number'], # "Diese 10 ..."
    [ 40, 'number', 'noun'], # 10 Dinge die Sie unbedingt...
    [ 50, 'number', 'noun', 'article'], # 10 Dinge die Sie unbedingt...
    [ 40, 'number', 'any', 'noun'], # 15 dicke Affen die Sie ...
    [ 10, 'article', 'noun'], # Dieser Affe wird Sie verblüffen!
    [ 60, 'interrogative_or_pronominal_adverb'], # Was hat dieser Affe zu verbergen? | Daran erkennen Sie eine gute Bratwurst!
  );

  $score{question_mark} = 15 if $title =~ /\?/;
  $score{exclamation_mark} = 10 if $title =~ /!/;
  $score{chunked} = 5 if @chunks > 1;
  $score{addressing} += 15 while $title =~ /\b(?:[Dd]u|Sie|Ihr(?:en?)?|[Uu]ns(?:ere?)?|[mMdD]eine?|[MmdD]ich|[mMdDwW]ir)\b/ig;
  $score{excessive_length} += 2.5 * max(0, scalar(split /[^\w-]+/, $title) - 10);

  for(@chunks) {
    my @words = split /[\s,]+/;

    for my $pattern (sort { @$b <=> @$a } @patterns) {
      my ($score, @expected) = @$pattern;

      if($c->check_pattern(\@words, \@expected)) {
        $score{join('_', 'pattern', @expected)} += $score;
        last;
      }
    }
  }

  $score{total} = sum0 values %score;

  return \%score;
};

helper check_pattern => sub {
  my ($c, $words, $expected) = @_;

  my @expected = @$expected;

  my %check = (
    any     => sub { 1 },
    noun    => sub { /^[A-ZÄÖÜ]/ }, # XXX Really naive check for nouns...
    article => sub { /^(?:der|die|das|diese[rsn]?|denen)$/i },
    number  => sub { /^(?:\d+)$/i },

    interrogative_or_pronominal_adverb => sub {
      /^(?:wer|wie|was|warum|[wd]eshalb|welchen?|wen|(?:wo|da|hier?)(?:ran|mit|her|rum)|so)$/i
    },
  );

  return 0 if @$words < @expected;

  for(@$words) {
    return 1 unless @expected;

    my $check = shift @expected;

    die "No check for $check" unless $check{$check};

    return 0 unless &{$check{$check}};
  }

  return 1;
};

app->start;

__DATA__
@@ index.html.ep
% title param('title');
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><%= title %></title>
    <style type="text/css">
      body {
        margin: 40px auto;
        max-width: 650px;
        line-height: 1.6;
        font-size: 18px;
        color: #444;
        padding: 0 10px;
      }
      h1,h2,h3 {
        line-height:1.2;
      }
    </style>
  </head>
  <body>
    <h1><%= title %></h1>
    <form>
      %= text_field title => (id => 'title', style => 'width:100%')
      %= submit_button 'Dein Titel: Erfahre in 5 einfachen Schritten wie kacke er ist!', (style => 'width:100%')
    </form>

    %= tag pre => dumper(stash('score'))
  </body>
</html>
