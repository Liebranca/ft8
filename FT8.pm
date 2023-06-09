#!/usr/bin/perl
# ---   *   ---   *   ---
# FT8
# Lord of the fonts
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# lyeb,

# ---   *   ---   *   ---
# deps

package FT8;

  use v5.36.0;
  use strict;
  use warnings;

  use Carp;
  use Readonly;
  use English qw(-no_match_vars);

  use Cwd qw(abs_path);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;

  use Arstd::String;
  use Arstd::RD;
  use Arstd::IO;

  use lib $ENV{'ARPATH'}.'/lib/';
  use Emit::Std;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.02.0;#a
  our $AUTHOR  = 'IBN-3DILA';

# ---   *   ---   *   ---
# ROM

  Readonly our $GL_X    => 8;
  Readonly our $GL_Y    => 8;

  Readonly our $GL_ROWS => 16;
  Readonly our $GL_GPR  => 16;

  Readonly our $SZ_X    => 128;
  Readonly our $SZ_Y    => 128;

  Readonly our $GZIP_RE  => qr{ \.gz$ }x;
  Readonly our $SKIP_ROW => $SZ_X*8;

# ---   *   ---   *   ---
# open file

sub forc($class,$fpath) {

  my $self=bless {
    fpath => glob($fpath),
    data  => [],

  },$class;

  if($self->{fpath}=~ s[$GZIP_RE][]) {
    $self->from_gzip();

  } else {
    $self->fread();

  };

  return $self;

};

# ---   *   ---   *   ---
# fill out pixel array

sub fread($self) {

  my $body=orc($self->{fpath});

  my $x=0;
  my $y=0;
  my $i=0;

  # walk file
  while($body) {

    # read entry
    my @ar=();
    csume(\$body,\@ar,qw(L L));

    # ^store
    $self->{data}->[$y][$x++]=\@ar;

    # next row
    if($x == $GL_GPR) {
      $x^=$x;
      $y++;

    };

  };

};

# ---   *   ---   *   ---
# unzip for reading and zip back

sub from_gzip($self) {

  `gunzip $self->{fpath}`;
  $self->fread();

  `gzip $self->{fpath}`;

};

# ---   *   ---   *   ---
# debug out

sub prich($self,$x=0,$y=0) {

  printf

    "%08X,%08X\n",

    $self->{data}->[$y][$x][0],
    $self->{data}->[$y][$x][1],

  ;

};

# ---   *   ---   *   ---
# human-readable reverse translation

sub rbw_row($self,$b,$off) {

  $off = 24-$off;

  my $out = $NULLSTR;
  my $x   = 7;

  do {

    my $n=(7-$x) + $off;
    my $c=($b & (1 << $n))
      ? '$'
      : ' '
      ;

    $out.=$c;

  } while($x--);

  return $out;

};

# ---   *   ---   *   ---
# reverse row-index order for humans

sub rbw($self,$x,$y) {

  my $out=$NULLSTR;

  for my $r(0..7) {

    my $i=32;

    do {

      my $glyph = $x+($r<=3)+(32-$i)+($y*16);

      my $b     = $self->{data}->[$glyph];
      my $off   = 8*($r&3);

      $out.=$self->rbw_row($b,24-$off);

    } while($i-=2);

    $out.="\n";

  };

  return $out;

};

# ---   *   ---   *   ---
# literal translation

sub bw_row($self,$b,$off) {

  my $out = $NULLSTR;
  my $x   = 0;

  do {

    my $n=$x+$off;
    my $c=($b & (1 << $n))
      ? '$'
      : ' '
      ;

    $out.=$c;

  } while($x++ < 7);

  return $out;

};

# ---   *   ---   *   ---
# literal row-index order

sub bw($self,$x,$y) {

  $x=480-$x;
  my $out=$NULLSTR;

  for my $r(0..7) {

    my $i=32;

    do {

      my $glyph = $x+($r>3)+(32-$i)-($y*16);

      my $b     = $self->{data}->[$glyph];
      my $off   = 8*($r&3);

      $out.=$self->bw_row($b,$off);

    } while($i-=2);

    $out.="\n"

  };

  return $out;

};

# ---   *   ---   *   ---
# literal translation, write to array

sub abw_row($self,$b,$off) {

  my @out=();

  my $x=7;

  do {
    my $n=(7-$x)+$off;
    push @out,($b & (1<<$n)) ? 1 : 0;

  } while($x--);

  return @out;

};

# ---   *   ---   *   ---
# literal row-index order, write to array

sub abw($self,$ar,$x,$y) {

  $x=480-$x;

  for my $r(0..7) {

    my $i=32;

    do {

      my $glyph = $x+(32-$i)-($y*16);

      my $b     = $self->{data}->[$glyph+($r>3)];
      my $off   = 8*($r&3);

      $ar=$self->abw_row($ar,$b,$off);

    } while($i-=2);

  };

  return $ar;

};

# ---   *   ---   *   ---

sub pr_ascii($mode=undef) {

  # default settings are human-readable
  my $tr_func=\&rbw;

  # switch to bmp y-invertion
  if($mode) {
    $tr_func=\&bw;

  };

  my $pr=$NULLSTR;

  my $r=0;
  my $x=0;

  for my $y(0..15) {
    $pr  = $pr . $tr_func->($x,$y);
    $x  += 16;

  };

  print $pr."\n";

};

# ---   *   ---   *   ---
# ft8 to raster representation

sub to_raster($self) {

  my @im=();

  my $r=0;
  my $x=0;

  # iter through glyphs
  for my $y(0..$GL_ROWS-1) {
    for my $x(0..$GL_GPR-1) {

      # write glyph to flat array
      my @ar=$self->get_glyph($x,$y,1);

      # calc offset
      my $off_y =
        (($GL_ROWS-1)*$GL_Y)
      - ($y*$GL_Y)
      ;

      # place array values
      # at corresponding pixels
      for my $z(0..7) {

        my $off_x=
          ($x*$GL_X)
        + ($off_y*$SZ_X)
        ;

        @im[$off_x..$off_x+$GL_X-1]=
          @ar[($z*8)..($z*8)+$GL_X-1];

        $off_y++;

      };

    };

  };

  return @im;

};

# ---   *   ---   *   ---
# copy font data into a checkerboard

sub checkers($self) {

  # fetch pixel array
  my @src  = $self->to_raster();

  # iter vars
  my @im   = ();
  my $dim  = 0;

  my $vy   = 0;
  my $vx   = 0;

  my $edge = 0;

  # read
  for(my $y=$SZ_Y;$y--;) {
    for(my $x=0;$x<$SZ_X;++$x) {

      # pix either full black of white
      my $v=(shift @src)*255;

      # ascii checkers mindfuck
      $vy  = (!(($y/8)&1));
      $vy |= (($x%($SZ_X-1))!=0);
      $vx  = (($x%8)!=0);

      # ^idem
      $dim  =! $dim if $vx ^ $vy;
      $edge =! (($x==($SZ_X-1)) && (!$vy));

      # write checkered value to array
      $v=(($v == 0) && ((!$dim) * $edge))
        ? chr(hex 22)
        : chr($v)
        ;

      $im[$x][$y]=sprintf "%s","$v$v$v";

    };

  };

  return @im;

};

# ---   *   ---   *   ---
# ft8 to glsl const uint array converter

sub to_singl($self,$fpath) {

  my $mod=caller;

  no strict 'refs';

  my $version = ${"$mod\::VERSION"};
  my $author  = ${"$mod\::AUTHOR"};

  $version //= v0.00.1;
  $author  //= 'ANON';

  $version=vstr($version);

  my @glyphs = ();
  my $pad    = q[ ] x 4;

  for my $y(0..$GL_ROWS-1) {
    for my $x(0..$GL_GPR-1) {

      push @glyphs,(sprintf

        "${pad}{0x%08X,0x%08X}",

        $self->{data}->[$y][$x][0],
        $self->{data}->[$y][$x][1]

      );

    };

  };

  my $body=

    '  const uint CHARS'
  . '['.($GL_ROWS * $GL_GPR) . "][2]={\n\n"

  . ( join ",\n",@glyphs ) . "\n\n  };\n"
  ;

  my $note=Emit::Std::note($author,'//');

  my $out=

    $note . "\n"
  . q[$:VERT;>] . "\n\n"

  . "  VERSION   $version;\n"
  . "  AUTHOR    \"$author\";\n\n"

  . q[$:FRAG;>] . "\n\n"
  . $body
  ;

  owc($fpath,$out);

};

# ---   *   ---   *   ---
# read row as array

sub ar_row($self,$row) {

  return (

    $self->abw_row($row,  0),
    $self->abw_row($row,  8),
    $self->abw_row($row, 16),
    $self->abw_row($row, 24)

  );

};

# ---   *   ---   *   ---
# read row as string

sub pr_row($self,$row,$iv=undef) {

  my $fun = ($iv) ? \&rbw_row : \&bw_row;

  return

    ( $fun->($self,$row,  0) ) . "\n"
  . ( $fun->($self,$row,  8) ) . "\n"
  . ( $fun->($self,$row, 16) ) . "\n"
  . ( $fun->($self,$row, 24) ) . "\n"

  ;

};

# ---   *   ---   *   ---
# fetch Nth glyph from table

sub get_glyph($self,$x,$y,$as_arr=0) {

  my $n=$x+($y*$GL_GPR);

  $x=0;
  $y=15;

 while($n) {

    $x++;

    if($x==$GL_GPR) {
      $y--;
      $x^=$x;

    };

    $n--;

  };

  my $top=$self->{data}->[$x][$y][0];
  my $bot=$self->{data}->[$x][$y][1];

  if($as_arr) {

    return (

      $self->ar_row($top),
      $self->ar_row($bot)

    );

  };

  my $s=$NULLSTR;

  $s.=pr_row($bot,1);
  $s.=pr_row($top,1);

  return $s;

};

# ---   *   ---   *   ---
# args psf source,outpath
# the stupid way of using unprintable chars

sub stunift($infont,$intable) {

  $infont  = glob($infont);
  $intable = glob($intable);

  # copy the font, then unzip
  `cp $infont ~/tmp_stunift.gz`;
  $infont=glob('~/tmp_stunift');

  `gunzip $infont.gz`;

  # generate table and open for read
  `psfgettable $infont $intable`;
  open FH,'<',$intable or die $!;

  # readlines
  my @lines=();while(my $line=<FH>) {
    if(!$line) {next;};
    if((index $line,'#') eq 0) {
      push @lines,$line;next;

    };

    # capture keycode
    $line=~ s/0x([\w|\d]+)\s+//;
    my $kc=hex $1;

    # ensure keycode corresponds to char
    push @lines,sprintf (
      "0x%02X U+%04x U+%04x\n",
      $kc,$kc,256+$kc

    );


  };close FH;

  # now dump buffer
  open FH,'>',$intable or die $!;

  while(@lines) {
    print FH shift @lines;

  };close FH;

  # get rid of the temp file
  `rm ~/tmp_stunift`;

};

# ---   *   ---   *   ---
1; # ret
