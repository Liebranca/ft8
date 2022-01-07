#!/usr/bin/perl

#-------------------------+
# JOJFT                   |
# rd-wr joj fonts         |
# raw bmp handling        |
#                         |
# LIBRE SOFTWARE          |
# Licensed under GNU GPL3 |
# be a bro and inherit    |
#                         |
# CONTRIBUTORS            |
# lyeb,                   |
#-------------------------+

# ---   *   ---   *   ---

# deps
  use strict;
  use warnings;

package JOJ;

# constants
  use constant {
    
    GL_X    =>   8,
    GL_Y    =>   8,
    GL_ROWS =>  16,
    GL_GPR  =>  16,

    SZ_X    => 128,
    SZ_Y    => 128,

  };

# cache
  my @fon=();


# ---   *   ---   *   ---

# fpath=path to C header file
# file format:header containing OGL-styled macro for shader-block insertion

# opens a joj-encoded font
sub open_jojft_h {

  my $fpath=shift;
  open JOJF,$fpath;

  # skip declaration
  my $line=<JOJF>;$line=<JOJF>;

  # iter values
  my $i=0;while(($line=<JOJF>) ne "};\\\n") {

    # capture values
    $line=~ s/\{ 0x([\d|\w]+),\s0x([\d|\w]+)//;

    # save as integer  
    $fon[$i+0]=hex $1;
    $fon[$i+1]=hex $2;

    $i+=2;

  };close JOJF;

};

# ---   *   ---   *   ---

# fpath=path to binary file
# file format: gz compressed joj binary font

# opens a joj-encoded font
sub open_jojft {
  my $fpath=glob(shift);
  my @fon=();

  # unzip for reading  
  system 'gunzip',($fpath);
  open JOJF,$fpath;

  # idex-es
  my $x=0;
  my $y=0;
  
  # iter values
  my $row='';
  my $i=0;while(read JOJF,$row,8) {

    # capture
    ( $fon[$x][$y][0],
      $fon[$x][$y][1] )=unpack 'L2',$row;

    # advance/go to next row      
    $x++;if($x==GL_GPR) {
      $y++;$x^=$x;

    };

  };
  
  # close and zip
  close JOJF;
  system 'gzip',($fpath);

  return \@fon;

};

# ---   *   ---   *   ---

# human-readable reverse translation
sub rbw_row {
  my $b=shift;
  my $off=24-shift;
  
  my $s="";
  my $x=7;do {
    my $c=( $b & (1<<((7-$x)+$off)) ) ? '$' : ' ';
    $s=$s.$c;

  } while($x--);return $s;

};

# reverse row-index order for humans
sub rbw {

  my $x=shift;
  my $y=shift;

  my $line="";  

  for(my $r=0;$r<8;$r++) {
    my $i=32;do {
      my $glyph=$x+($r<=3)+(32-$i)+($y*16);
      my $b=$fon[$glyph];

      $line=$line.( rbw_row $b,24-(8*($r&3)) );

    } while($i-=2);$line=$line."\n"
    
  };return $line;
};

# ---   *   ---   *   ---

# literal translation
sub bw_row {
  my $b=shift;
  my $off=shift;
  
  my $s="";
  my $x=0;do {
    my $c=( $b & (1<<($x+$off)) ) ? '$' : ' ';
    $s=$s.$c;

  } while($x++<7);return $s;

};

# literal row-index order
sub bw {

  my $x=480-shift;
  my $y=shift;

  my $line="";

  for(my $r=0;$r<8;$r++) {
    my $i=32;do {
      my $glyph=$x+($r>3)+(32-$i)-($y*16);
      my $b=$fon[$glyph];

      $line=$line.( bw_row $b,8*($r&3) );

    } while($i-=2);$line=$line."\n"
    
  };return $line;
  
};

# ---   *   ---   *   ---

# literal translation, write to array
sub abw_row {

  my @ar=@{$_[0]};
  my $i=$_[1];

  my $b=$_[2];
  my $off=$_[3];
  
  my $x=7;do {
    push @ar,($b & (1<<((7-$x)+$off)) ) ? 1 : 0;

  } while($x--);return \@ar;

};

# literal row-index order, write to array
sub abw {

  my $ar=$_[0];
  my $x=480-$_[1];
  my $y=$_[2];

  for(my $r=0;$r<8;$r++) {
    my $i=32;do {
      my $glyph=$x+(32-$i)-($y*16);
      my $b=$fon[$glyph+($r>3)];

      $ar=abw_row $ar,$glyph,$b,8*($r&3);

    } while($i-=2);
    
  };return $ar;
  
};

# ---   *   ---   *   ---

sub pr_ascii {

  # default settings are human-readable
  my $mode=shift;
  my $tr_func=\&rbw;
  
  # switch to bmp y-invertion  
  if($mode) {
    $tr_func=\&bw;
    
  };

  my $pr="";
  
  my $r=0;
  my $x=0;
  
  for(my $y=0;$y<16;$y++) {

    $pr=$pr.( $tr_func->($x,$y) );$x+=16;

  }; print $pr."\n";

};

sub pr_bmp {

  open_jojft( glob(shift) );

  my @im=();
  
  my $r=0;
  my $x=0;
  
  for(my $y=0;$y<16;$y++) {
    @im=@{ abw(\@im,$x,$y) };$x+=16;

  };return \@im;

};

# ---   *   ---   *   ---

# BMP image handling
# modified from rw-psf:
#   https://github.com/talamus/rw-psf.git

# talamus, you absolute chad

# ---   *   ---   *   ---

# get bytes per row
sub calc_bpr {
  my $sz_x=shift;
  return int(($sz_x*3 + 3)/4)*4;
  
};

# fpath=path to bmp file
# extract header and data from bmp
sub read_bmp {

  # open file
  my $fpath=glob shift;
  open BMP,'<:raw',$fpath;

  my (
    $id,$sz_f,
    $sz_x,$sz_y,
    $depth

  # get the header
  );{

    my $header;(
      54 == read BMP,
      $header,54

    # never seen this errme
    ) or die "Bad BMP\n";(
      $id,$sz_f,undef,
      $sz_x,$sz_y,
      undef,
      $depth

    )=unpack 'a2 V1 a12 V2 a2 v1', $header;

    # nor this one
    ($id eq 'BM') or die "Not a BMP\n";
    ($depth == 24) or die "BMP must have a bit-depth of 24";
    ($sz_f == -s $fpath) or die "Bad file size\n"

  };my $bpr=calc_bpr($sz_x);

# ---   *   ---   *   ---

  # get the image data
  my @data=();for(my $y=$sz_y;$y--;) {
  
    my $row;(
      read BMP,$row,$bpr

    # never seen this one either
    ) or die "Bad row\n";

    my @bytes=unpack('C'.($sz_x*3).'h*',$row);
    for(my $x=0;$x<$sz_x;++$x) {

      # one channel is enough
      push @data,shift @bytes;
      shift @bytes;shift @bytes;

    };
    
  };close BMP;
  return ($id,$sz_f,$sz_x,$sz_y,$bpr,\@data);

};


# ---   *   ---   *   ---

# dst=outfile path
# src=pixel array
# sz_x=image width
# sz_y=image height

# write pix array to bmp
sub write_bmp {

  my $dst=shift;
  my @src=@{ $_[0] };shift;
  
  my $sz_x=shift;
  my $sz_y=shift;

  my $bpr=calc_bpr $sz_x;

  # open file and dump header
  open BMP, '>:raw',$dst;
  print BMP pack 'a2 V n2 V4 v2 V6', (
    'BM',54+($sz_y*$bpr),

    # you know it's a pleb format when
    # it uses this cringe siggy
    0xcafe,0xbabe,
    54,40,
    
    $sz_x,$sz_y,
    
    1,24,0,
    
    $sz_y*$bpr,0,0,0,0,

# ---   *   ---   *   ---

  );my $pad=$bpr-($sz_x*3);

  # write data and close
  for(my $y=$sz_y;$y--;) {
    my $row='';
    for(my $x=0;$x<$sz_x;++$x) {
      $row .= $src[$x][$y];
      
    };$row .= pack "C$pad",0;
    print BMP $row or die "Bad write\n";
  };close BMP; 

};

# ---   *   ---   *   ---

# first arg: path to jojfile
# sz_x=image width
# sz_y=image height

# copy joj font data into a checkerboard
sub checkers {

  # fetch joj data
  my @src=@{ pr_bmp(glob(shift)) };
  my @im=();my $dim=0;my $literal_edge_case=0;

  my $vy=0;
  my $vx=0;

  my $sz_x=shift;
  my $sz_y=shift;

# ---   *   ---   *   ---

  # read
  for(my $y=$sz_y;$y--;) {
    for(my $x=0;$x<$sz_x;++$x) {

      # pix either full black of white
      my $v=(shift @src)*255;

      # ascii checkers mindfuck
      $vy=(!(($y/8)&1));
      $vy|=(($x%($sz_x-1))!=0);
      $vx=(($x%8)!=0);

      # ^idem      
      if(($vx) ^ ($vy)){$dim=!$dim};
      $literal_edge_case=!(($x==($sz_x-1)) && (!$vy));

      # write checkered value to array
      $v=( ($v == 0) && ((!$dim)*$literal_edge_case))
        ? chr(hex 22)
        : chr($v)

      ;$im[$x][$y]=sprintf "%s",$v.$v.$v;

    };
    
  };return \@im;
};

# ---   *   ---   *   ---

# fin=joj input
# fout=name of file to write to

# joj font to bitmap converter
sub jtob {

  # hardcoded, 256 8x8 glyphs
  my $sz_x=128;
  my $sz_y=128;

  # get joj data
  my @im=@{ checkers(shift,$sz_x,$sz_y) };

  # get name of dst and write
  my $fout=shift;
  write_bmp $fout,\@im,$sz_x,$sz_y;

};

# ---   *   ---   *   ---

# im,dst=read-from, write-to
# x,y=glyph position

# reformat data from bitmap into glyph array
sub make_glyph {

  my @im=@{ $_[0] };shift;

  my $x=shift;
  my $y=shift;

  # pixel-wise position
  my $off_x=$x*(GL_X);
  my $off_y=$y*(GL_Y);

  my $r=0;my @glyph=(0,0);

# ---   *   ---   *   ---

  # iter through pixels for this glyph
  for(my $bit_y=0;$bit_y<GL_Y;$bit_y++) {
    for(my $bit_x=0;$bit_x<GL_X;$bit_x++) {

      # fetch pixel at offset
      my $pixel_idex=($off_x+$bit_x)+(($off_y+$bit_y)*(SZ_X));
      my $pixel=int($im[$pixel_idex]/255) ? 1 : 0;

      # flip the bit for this pixel
      $glyph[$bit_y>3] += $pixel<<( ($r*8)+$bit_x );

    };$r++;$r&=3;
  };

  return @glyph;
  
};

# ---   *   ---   *   ---

sub fuck {

  my $v=shift;
  my $fun=($_[0]) ? \&rbw_row : \&bw_row;
  return
    ( $fun->($v,  0) )."\n".
    ( $fun->($v,  8) )."\n".
    ( $fun->($v, 16) )."\n".
    ( $fun->($v, 24) )."\n";

};

# fout=path to font
# N=idex of glyph to fetch

# fetch N glyph from table
sub read_glyph {

  my @glyphs=@{ open_jojft(shift) };
  my $N=shift;

  my $x=0;
  my $y=15;

  while($N) {
    $x++;if($x==GL_GPR) {
      $y--;$x^=$x;

    };$N--;
  };

  my $s="";
  my $bot=$glyphs[$x][$y][1];$s.=fuck($bot,1);
  my $top=$glyphs[$x][$y][0];$s.=fuck($top,1);

  print $s;

};

# ---   *   ---   *   ---

# fin=path to bitmap
# fout=output path

# bmp to joj font
sub btoj {

  my $fin=glob(shift);
  my $fout=glob(shift);

  # get bmp data
  my ($id,$sz_f,$sz_x,$sz_y,$bpr,$data_ref)=
    read_bmp($fin);

  my @im=@{ $data_ref };
  my @glyph=();

# ---   *   ---   *   ---

  # open outfile
  open JOJF,'>',$fout;

  # convert data to joj format  
  for(my $y=0;$y<GL_ROWS;$y++) {
    for(my $x=0;$x<GL_GPR;$x++) {
      @glyph=make_glyph(\@im,$x,$y);
      print JOJF pack('L2',@glyph,2);
      

    };
  };close JOJF;
  system 'gzip',($fout);
  
};

# ---   *   ---   *   ---

# testing
btoj('./LyTest/LyTest8_src.bmp','./lycon');
read_glyph('./lycon',65);

# ---   *   ---   *   ---
1; # ret
