#!/usr/bin/perl
# ---   *   ---   *   ---
# BMP
# Image handling
#
# LIBRE SOFTWARE
# Licensed under GNU GPL3
# be a bro and inherit
#
# CONTRIBUTORS
# talamus, lyeb,

# ---   *   ---   *   ---
# deps

package BMP;

  use v5.36.0;
  use strict;
  use warnings;

  use Carp;
  use Readonly;
  use English qw(-no_match_vars);

  use Cwd qw(abs_path);

  use lib $ENV{'ARPATH'}.'/lib/sys/';

  use Style;
  use Arstd::IO;
  use Arstd::RD;

  use lib $ENV{'ARPATH'}.'/ft8/';
  use FT8;

# ---   *   ---   *   ---
# info

  our $VERSION = v0.00.1;#b
  our $AUTHOR  = 'Tero Niemi';

# ---   *   ---   *   ---
# NOTE:
#
# bmp read-write routines were
# taken from rw-psf:
#
#   https://github.com/talamus/rw-psf.git
#
#
# i (lyeb) merely hacked
# his implementation
#
# therefore, i do not list myself
# as author of these bits

# ---   *   ---   *   ---
# ROM

  Readonly our $ERRME=>{

    badfile  => 'Bad BMP',
    badsig   => 'Not a BMP',

    baddepth => 'BMP must have a bit-depth of 24',
    badfsz   => 'Bad file size',

  };

# ---   *   ---   *   ---
# open new file

sub fnew($class,$fpath) {

  open my $bmp,'>:raw',glob($fpath)
  or croak strerr($fpath);

  my $self=bless {

    sz_x=>$FT8::SZ_X

  };

  $self->calc_bpr();
  $self->write_header();

  return $self;

};

# ---   *   ---   *   ---
# open file

sub fopen($class,$fpath) {

  open my $bmp,'<:raw',glob($fpath)
  or croak strerr($fpath);

  my $self=bless {

    fpath   => $fpath,
    fhandle => $bmp,

    header  => undef,

    data    => [],

  },$class;

  $self->read_header();
  $self->calc_bpr();

  return $self;

};

# ---   *   ---   *   ---
# ^undo

sub fclose($self) {
  close $self->{fhandle}
  or croak strerr($self->{fpath});

};

# ---   *   ---   *   ---
# put bmp file header

sub write_header($self) {

  my $hed=pack 'a2 V n2 V4 v2 V6',

    'BM',54 + ($FT8::SZ_Y * $self->{bpr}),

    # you know it's a pleb format when
    # it uses this cringe siggy
    0xCAFE,0xBABE,
    54,40,

    $FT8::SZ_X,$FT8::SZ_Y,
    1,24,0,

    $FT8::SZ_Y * $self->{bpr},
    0,0,0,0,

  ;

  print {$self->{fhandle}} $hed;

};

# ---   *   ---   *   ---
# extract bmp file header

sub read_header($self) {

  my $hed = $NULLSTR;
  my $rdb = read $self->{fhandle},$hed,54;

  # errchk read
  $rdb==54 or croak "$ERRME->{badfile}\n";

  # ^unpack bytes to hashref
  my $st=fstin(

    \$hed,

    id     => 'a2',
    sz_f   => 'V1',

    unused => 'a12',

    sz_x   => 'V1',
    sz_y   => 'V1',

    unused => 'a2',

    depth  => 'v1',

  );

  # ^errchk unpack
  ($st->{id} eq 'BM')
  or croak "$ERRME->{badsig}\n";

  ($st->{depth} == 24)
  or croak "$ERRME->{baddepth}\n";

  ($st->{sz_f} == -s $self->{fpath})
  or die "$ERRME->{badfsz}\n";

  # cat header to self
  map {

    $self->{$ARG}=$st->{$ARG}

  } grep {$ARG ne 'unused'} keys %$st;

};

# ---   *   ---   *   ---
# get bytes per row

sub calc_bpr($self) {

  my $a=$self->{sz_x}*3;

  $a+=3;
  $a/=4;

  $self->{bpr}=int($a)*4;

};

# ---   *   ---   *   ---
# read next row in image

sub get_row($self) {

  my $row=$NULLSTR;
  my $rdb=read $self->{fhandle},$row,$self->{bpr};

  $rdb==$self->{bpr} or croak "Bad row\n";

  my $width=$self->{sz_x} * 3;
  my @bytes=unpack "C${width} h*",$row;

  return @bytes;

};

# ---   *   ---   *   ---
# get image data from open

sub fread($self) {

  for(my $y=$self->{sz_y};$y--;) {

    my @bytes=$self->get_row();
    for my $x(0..$self->{sz_x}-1) {
      push @{$self->{data}},$bytes[$x*3];

    };

  };

};

# ---   *   ---   *   ---
# commit bytes to file

sub fwrite($self,$src) {

  my $body = $NULLSTR;
  my $pad  = $self->{bpr} - ($FT8::SZ_X * 3);

  # write data and close
  for(my $y=$FT8::SZ_Y;$y--;) {

    for(my $x=0;$x<$FT8::SZ_X;++$x) {
      $body.=$src->[$x][$y];

    };

    $body.=pack "C$pad",0;

  };

  print {$self->{fhandle}} $body
  or croak "Bad write\n";

};

# ---   *   ---   *   ---
# extract header and data from bmp

sub forc($class,$fpath) {

  my $self=$class->fopen($fpath);
  $self->fread();
  $self->fclose();

  return $self;

};

# ---   *   ---   *   ---
# write pix array to bmp

sub fowc($class,$dst,$src) {

  my $self=class->fnew($dst);
  $self->fwrite($src);
  $self->fclose();

};

# ---   *   ---   *   ---
# get pixel idex for glyph

sub pidex($self,$x,$gx,$y,$gy) {

  $y=(7-$y) * $FT8::SZ_X;
  $x=$x+$gx;

  my $off=$FT8::SKIP_ROW * $gy;

  return $off+$x+$y;

};

# ---   *   ---   *   ---
# fetches glyph

sub get_8x8($self,$x,$y) {

  my @out = ();
  my $ar  = $self->{data};

  $x *= 8;
  $y  = ($FT8::GL_ROWS-1)-$y;

  for my $py(0..7) {
    for my $px(0..7) {

      my $idex  = $self->pidex($px,$x,$py,$y);
      my $pixel = $ar->[$idex];

      $pixel=($pixel < 255)
        ? 0
        : 1
        ;

      $out[$py][$px]=$pixel;

    };

  };

  return @out;

};

# ---   *   ---   *   ---
# ^pack as u32 pair

sub pack_8x8($self,$x,$y) {

  my @out   = ();
  my @glyph = $self->get_8x8($x,$y);

  my $bit   = 0;
  my $long  = 0;

  map {

    map {

      $long |= $ARG << $bit++;

    } @$ARG;

    if($bit == 32) {

      push @out,$long;

      $long ^= $long;
      $bit  ^= $bit;

    };

  } @glyph;

  return @out;

};

# ---   *   ---   *   ---
# print glyph to console

sub prich($self,$gx=0,$gy=0) {

  my @glyph=$self->get_8x8($gx,$gy);

  map { map {
    printf [' ','$']->[$ARG]

  } @$ARG;say $NULLSTR } @glyph;

};

# ---   *   ---   *   ---
# create bmp from ft8 file

sub from_ft8($dst,$src) {

  # fetch pixel array
  my $ft8 = FT8->fopen($src);
  my @im  = $ft8->checkers();

  # ^write to file
  BMP->fowc($dst,\@im);

};

# ---   *   ---   *   ---
# ^iv

sub to_ft8($self,$fpath) {

  my $out=$NULLSTR;

  # convert data to ft8 format
  for my $y(0..$FT8::GL_ROWS-1) {
    for my $x(0..$FT8::GL_GPR-1) {
      $out.=pack 'L2',$self->pack_8x8($x,$y);

    };

  };

  owc($fpath,$out);
  `gzip $fpath`;

};

# ---   *   ---   *   ---
1; # ret
