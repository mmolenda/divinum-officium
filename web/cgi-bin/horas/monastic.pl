#!/usr/bin/perl
use utf8;

# Name : Laszlo Kiss
# Date : 01-25-08
# horas common files to reconcile tempora & sancti
#use warnings;
#use strict "refs";
#use strict "subs";
use FindBin qw($Bin);
use lib "$Bin/..";

# Defines ScriptFunc and ScriptShortFunc attributes.
use horas::Scripting;
my $a = 4;

#*** makeferia()
# generates a name and office for feria
# if there is none
sub makeferia {
  my @nametab = ('Sunday', 'II.', 'III.', 'IV.', 'V.', 'VI.', 'Sabbato');
  my $name = $nametab[$dayofweek];
  if ($dayofweek > 0 && $dayofweek < 6) { $name = "Feria $name"; }
  return $name;
}

#*** psalmi_matutinum_monastic($lang)
# generates the appropriate psalm and lessons
# for the monastic version
sub psalmi_matutinum_monastic {
  $lang = shift;
  $psalmnum1 = $psalmnum2 = -1;

  #** reads the set of antiphons-psalms from the psalterium
  my %psalmi = %{setupstring($datafolder, $lang, 'Psalterium/Psalmi matutinum.txt')};
  my $dw = $dayofweek;
  if ($winner{Rank} =~ /Dominica/i) { $dw = 0; }
  my @psalmi = split("\n", $psalmi{"Daym$dw"});
  setbuild("Psalterium/Psalmi matutinum monastic", "dayM$dw", 'Psalmi ord');
  $comment = 1;
  my $prefix = translate('Antiphonae', $lang);

  #** special Adv - Pasc antiphons for Sundays
  if ($dayofweek == 0 && $dayname[0] =~ /(Adv|Pasc)/i) {
    @psalmi = split("\n", $psalmi{$1 . 'm0'});
    setbuild2("Antiphonas Psalmi Dominica special for Adv Pasc");
  }

  #** special antiphons for not Quad weekdays
  if ($dayofweek > 0 && $dayname[0] !~ /Quad/i) {
    my $start = ($dayname[0] =~ /Pasc|Nat/i) ? 0 : 8;
    my @p = split("\n", $psalmi{'Daym Pasc'});
    if (($dayname[0] =~ /Nat/)) {
      @p = split("\n", $psalmi{'Daym Nat'});
    }
    my $i;

    for ($i = $start; $i < 14; $i++) {
      my $p = $p[$i];
      if ($psalmi[$i] =~ /;;(.*)/s) { $p = ";;$1"; }
      if ($i == 0 || $i == 8) {
        if ($dayname[0] !~ /Nat/) {
          my $ant = $prayers{$lang}{"Alleluia Duplex"};
          $ant =~ s/ / * /;
          $ant =~ s/\./$prayers{$lang}{"Alleluia Simplex"}/;
          $p = "$ant$p";
        }
        else {
          $p = "$p[$i]$p";
        }
      }
      $psalmi[$i] = $p;
    }
    setbuild2("Antiphonas Psalmi weekday special no Quad");
  }

  #** change of versicle for Adv, Quad, Quad5, Pasc
  if ($dayofweek > 0 && ($winner =~ /tempora/i && $dayname[0] =~ /(Adv|Quad|Pasc)([0-9])/i)
      || $dayname[0] =~ /(Nat)(\d)$/) {
    my $name = $1;
    my $i = $2;
    if ($name =~ /Quad/i && $i > 4) { $name = 'Quad5'; }
    $i = $dayofweek;
    if ($name =~ /Nat/ && $i > 3) { $i -= 3; }
    my @a = split("\n", $psalmi{"$name $i Versum"});
    $psalmi[6] = $a[0];
    $psalmi[7] = $a[1];
    setbuild2("Subst Matutitunun Versus $name $dayofweek");
  }

  #** special cantica for quad time
  if (exists($winner{'Cantica'})) {
    my $c = split("\n", $winner{Cantica});
    my $i;
    for ($i = 0; $i < 3; $i++) { $psalmi[$i + 16] = $c[$i]; }
  }

  if ($rank > 4.9) {
    #** get proper Ant Matutinum
    my ($w, $c) = getproprium('Ant Matutinum', $lang, 0, 1);
    if ($w) {
      @psalmi = split("\n", $w);
      $comment = $c;
      $prefix .= ' ' . translate('et Psalmi', $lang);
    }
  }
  setcomment($label, 'Source', $comment, $lang, $prefix);
  my $i = 0;
  my %w = (columnsel($lang)) ? %winner : %winner2;
  antetpsalm_mm('', -1);    #initialization for multiple psalms under one antiphon
  push(@s, '!Nocturn I.');
  foreach $i (0, 1, 2, 3, 4, 5) { antetpsalm_mm($psalmi[$i], $i); }
  antetpsalm_mm('', -2);    # set antiphon for multiple psalms under one antiphon situation
  push(@s, $psalmi[6]);
  push(@s, $psalmi[7]);
  push(@s, "\n");

  if ($rule =~ /(9|12) lectio/i && $rank > 4.9) {
    lectiones(1, $lang);
  } elsif ($dayname[0] =~ /(Pasc[1-6]|Pent)/i && $month < 11 && $winner{Rank} !~ /vigil|quattuor/i) {
    if ($winner =~ /Tempora/i
      || !(exists($winner{Lectio94}) || exists($winner{Lectio4})))
    {
      brevis_monastic($lang);
    } elsif (exists($winner{Lectio94}) || exists($winner{Lectio4})) {
      legend_monastic($lang);
    }
  } else {
    lectiones($winner{Rank} !~ /vigil/i, $lang);
  }
  push(@s, "\n");
  push(@s, '!Nocturn II.');
  foreach $i (8, 9, 10, 11, 12, 13) { antetpsalm_mm($psalmi[$i], $i); }
  antetpsalm_mm('', -2);    #draw out antiphon if any

  if ($winner{Rule} =~ /(12|9) lectiones/i && $rank > 4.9) {
    push(@s, $psalmi[14]);
    push(@s, $psalmi[15]);
    push(@s, "\n");
    lectiones(2, $lang);
    push(@s, "\n");
    push(@s, '!Nocturn III.');

    if ($psalmi[16] =~ /(.*?);;(.*)/s) {
      my $ant = $winner{"Ant Matutinum 3N"} || $1;
      my $p = $2;
      $p =~ s/[\(\-]/\,/g;
      $p =~ s/\)//g;
      my @c = split(';', $p);
      push(@s, "Ant. $ant");
      push(@s, "\&psalm($c[0])\n");
      push(@s, "\n");
      push(@s, "\&psalm($c[1])\n");
      push(@s, "\n");
      push(@s, "\&psalm($c[2])");
      push(@s, "Ant. $ant");
      push(@s, "\n");
      push(@s, $psalmi[17]);
      push(@s, $psalmi[18]);
      push(@s, "\n");
      lectiones(3, $lang);
      push(@s, '&teDeum');
      push(@s, "\n");

      if (exists($winner{LectioE})) {    #** set evangelium
        my %w = (columnsel($lang)) ? %winner : %winner2;
        my @w = split("\n", $w{LectioE});

        $w[0] =~ s/^(v. )?/v./;
        splice(@w, 1, 1, "R. " . translate("Gloria tibi Domine", $lang), $w[1]);
        if ($w[-1] !~ /Te decet/) { push(@w, "\$Te decet"); }
        splice(@w, -1, 1, "R. " . translate("Amen", $lang), "_", $w[-1]);

        $w = '';
        foreach $item (@w) {
          if ($item =~ /^([0-9:]+)\s+(.*)/s) {
            my $rest = $2;
            my $num = $1;
            if ($rest =~ /^\s*([a-z])(.*)/is) { $rest = uc($1) . $2; }
            $item = setfont($smallfont, $num) . " $rest";
          }
          $w .= "$item\n";
        }
        push(@s, $w);
      }
      push(@s, "\n");
    }
    return;
  }
  my ($w, $c) = getproprium('MM Capitulum', $lang, 0, 1);
  my %s = %{setupstring($datafolder, $lang, 'Psalterium/Matutinum Special.txt')};

  if ((!$w || $commune =~ /M\/C10/) && $commune) {
    my $name = $commune;
    $name =~ s/.*M.//;
    $name =~ s/\.txt//;
    $w = $s{"MM Capitulum $name"};
  }
  if (!$w) {
    if ($dayname[0] =~ /(Adv|Nat|Quad|Pasc)/i) {
      my $name = $1;
      if ($dayname[0] =~ /Quad[56]/i) { $name .= '5'; }
      $w = $s{"MM Capitulum $name"};
    }
  }
  if (!$w) { $w = $s{'MM Capitulum'}; }
  push(@s, "!!Capitulum");
  push(@s, $w);
  push(@s, "\n");
}

#*** antetpsal_mmm($line, $i)
# format of line is antiphona;;psalm number
# sets the antiphon and psalm call into the output flow
# handles the multiple psalms under one antiphon situation
sub antetpsalm_mm {
  my $line = shift;
  my $ind = shift;
  my @line = split(';;', $line);
  our $lastantiphon;
  $lastantiphon =~ s/\s+\*//;

  if ($ind == -1) { $lastantiphon = ''; return; }

  if ($ind == -2) {
    if ($lastantiphon) { push(@s, "Ant. $lastantiphon"); push(@s, "\n"); $lastantiphon = ''; }
    return;
  }

  if ( $dayname[0] =~ /Pasc/i
    && $hora =~ /Vespera/i
    && !exists($winner{"Ant $hora"})
    && $rule !~ /ex /i)
  {
    if ($ind == 0) {
      $line[0] = Alleluia_ant($lang, 0, 0);
      $lastantiphon = '';
    } else {
      $line[0] = '';
      $lastantiphon = Alleluia_ant($lang, 0, 0);
    }
  }

  if ( $dayname[0] =~ /Pasc/i
    && $hora =~ /Laudes/i
    && $winner{Rank} !~ /Dominica/i
    && !exists($winner{"Ant $hora"})
    && $rule !~ /ex /i)
  {

    if ($ind == 0) { $line[0] = Alleluia_ant($lang, 0, 0); $lastantiphon = ''; }
    if ($ind == 1) { $line[0] = ''; $lastantiphon = ''; }
    if ($ind == 2) { $line[0] = ''; $lastantiphon = Alleluia_ant($lang, 0, 0); }
    if ($ind == 3) { ensure_single_alleluia($line[0], $lang); }
    if ($ind == 4) { $line[0] = Alleluia_ant($lang, 0, 0); }
  }
  if ($line[0] && $lastantiphon) { push(@s, "Ant. $lastantiphon"); push(@s, "\n"); }
  if ($line[0]) { push(@s, "Ant. $line[0]"); $lastantiphon = $line[0]; }
  my $p = $line[1];
  my @p = split(';', $p);
  my $i = 0;

  foreach $p (@p) {
    if (!$p || $p =~ /^\s*$/) { next; }
    $p =~ s/[\(\-]/\,/g;
    $p =~ s/\)//;
    if (!$line[0]) { push(@s, "\n"); }
    if ($i < (@p - 1)) { $p = '-' . $p; }
    push(@s, "\&psalm($p)");
    push(@s, "\_");
    $i++;
  }
}

#*** monstic_lectio3($w, $lang)
# return the legend if appropriate
sub monastic_lectio3 {
  my $w = shift;
  my $lang = shift;
  if ($winner !~ /Sancti/i || exists($winner{Lectio3}) || $rank >= 4 || $rule =~ /(9|12) lectio/i) { return $w; }
  my %w = (columnsel($lang)) ? %winner : %winner2;
  if (exists($w{Lectio94})) { return $w{Lectio94}; }
  if (exists($w{Lectio4})) { return $w{Lectio4}; }
  return $w;
}

#*** absolutio_benedictio($lang)
sub absolutio_benedictio {
  my $lang = shift;

  push(@s, "\n");
  push(@s, '&pater_noster');
  my @a;
  if ($commune =~ /C10/) {
    my %m = (columnsel($lang)) ? %commune : %commune2;
    @a = split("\n", $m{Benedictio});
    setbuild2('Special benedictio');
  } else {
    my %benedictio = %{setupstring($datafolder, $lang, 'Psalterium/Benedictions.txt')};
    my $i =
        ($dayofweek == 1 || $dayofweek == 4) ? 1
      : ($dayofweek == 2 || $dayofweek == 5) ? 2
      : ($dayofweek == 3 || $dayofweek == 6) ? 3
      : 1;
    @a = split("\n", $benedictio{"Nocturn $i"});
    $a[4] = $a[5] if ($i != 3);
  }
  push(@s, "Absolutio. $a[0]");
  push(@s, "\n");
  push(@s, "V. $a[1]");
  push(@s, "Benedictio. $a[4]");
  push(@s, "_");
}

#*** legend_monastic($lang)
sub legend_monastic {
  my $lang = shift;
  #1 lesson
  absolutio_benedictio($lang);
  my %w = (columnsel($lang)) ? %winner : %winner2;
  my $str == '';

  if (exists($w{Lectio94})) {
    $str = $w{Lectio94};
  } else {
    $str = $w{Lectio4};
    if (exists($w{Lectio5}) && $w{Lectio5} !~ /!/) { $str .= $w{Lectio5} . $w{Lectio6}; }
  }

  $str =~ s/&teDeum\s*//;
  push(@s, $str, '$Tu autem', '_');

  my $resp = '';

  if (exists($w{Responsory1})) {
    $resp = $w{Responsory1};
  } else {
    my %c = (columnsel($lang)) ? %commune : %commune2;

    if (exists($c{Responsory1})) {
      $resp = $c{Responsory1};
    } else {
      $resp = "Responsory for ne lesson not found!";
    }
  }
  push(@s, responsory_gloria($resp, 3));
}

#*** brevis_monstic($lang)
sub brevis_monastic {
  my $lang = shift;
  absolutio_benedictio($lang);
  my $lectio;
  if ($commune =~ /C10/) {
    my %c = (columnsel($lang)) ? %commune : %commune2;
    $lectio = $c{getC10readingname()} ."\n_\n" . $c{'Responsory3'};
    setbuild2("Mariae $name");
  }
  else {
    my %b = %{setupstring($datafolder, $lang, 'Psalterium/Matutinum Special.txt')};
    $lectio  = $b{"MM LB$dayofweek"};
  }
  $lectio =~ s/&Gloria1?/&Gloria1/;
  push(@s, $lectio);
}

#*** regula($lang)
#returns the text of the Regula for the day
sub regula : ScriptFunc {

  my $lang = shift;
  my @a;
  my $t = setfont($largefont, translate("Regula", $lang)) . "\n_\n";
  my $d = $day;
  my $l = leapyear($year);

  if ($month == 2 && $day >= 24 && !$l) { $d++; }
  $fname = sprintf("%02i-%02i", $month, $d);

  if (!-e "$datafolder/Latin/Regula/$fname.txt") {
    if (@a = do_read("$datafolder/Latin/Regula/Regulatable.txt")) {
      my $a;
      my %a = undef;

      foreach $a (@a) {
        my @a1 = split(';', $a);
        $a{$a1[1]} = $a1[0];
        $a{$a1[2]} = $a1[0];
      }
      $fname = $a{$fname};
    } else {
      return $t;
    }
  }
  $fname = checkfile($lang, "Regula/$fname.txt");

  if (@a = do_read($fname)) {
    foreach $line (@a) {
      $line =~ s/^.*?\#//;
      $line =~ s/^(\s*)$/_$1/;
      $t .= "$line\n";
    }
  }

  if (!$l && $fname =~ /02\-23/) {
    $fname = checkfile($lang, "Regula/02-24.txt");

    if (@a = do_read($fname)) {
      foreach $line (@a) {
        $line =~ s/^.*?\#//;
        $line =~ s/^(\s*)$/_$1/;
        $t .= "$line\n";
      }
    }
  }
  $t .= '$Tu autem';
  return $t;
}
