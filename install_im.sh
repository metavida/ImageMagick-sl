#!/bin/bash
# Install ImageMagick on Snow Leopard (10.6)
# Reported to work also on Leopard (10.5)
#
# Created by Claudio Poli (http://www.icoretech.org)

# Configuration
# Set the sourceforge.net's mirror to use.
SF_MIRROR="heanet"
# ImageMagick configure arguments.
# If you plan on using PerlMagick remove --without-perl
IMAGEMAGICK_ARGUMENTS="--disable-static --with-modules --without-perl --without-magick-plus-plus --with-quantum-depth=8 --disable-openmp"
# Installation path.
CONFIGURE_PREFIX=/usr/local # no trailing slash.
# GhostScript font path.
CONFIGURE_GS_FONT=$CONFIGURE_PREFIX/share/ghostscript
# Mac OS X version.
DEPLOYMENT_TARGET=10.6

# Starting.
echo "---------------------------------------------------------------------"
echo "ImageMagick installation started."
echo "Please note that there are incompatibilities with MacPorts."
echo "Read: http://github.com/masterkain/ImageMagick-sl/issues/#issue/1 - reported by Nico Ritsche"
echo "---------------------------------------------------------------------"

apps=()
files=()
urls=()

function to_install () {
  apps=( "${apps[@]}" "$1" )
  urls=( "${urls[@]}" "$2" )
  file_name=`echo "$2" | ruby -ruri -e 'puts File.basename(gets.to_s.chomp)'` # I cheated.
  files=( "${files[@]}" "$file_name" ) # add the filename to an array to be decompressed later.
}

# Function that tries to download a file, if not abort the process.
function try_download () {
  file_name=$1
  url=$2
  echo "Downloading $file_name"
  
  # see if any of the files have already been downloaded
  if [[ -f $file_name ]]
  then
    echo "Already downloaded: $file_name"
    #rm -f $file_name # Cleanup in case of retry.
  else
    curl --fail --silent -O --url $1
    result=$? # Store the code of the last action, should be 0 for a successfull download.
    file_size=`ls -l "$file_name" | awk '{print $5}'`

    # We check for normal errors, otherwise check the file size.
    # Some websites like sourceforge redirects and curl can't
    # detect the problem.
    if [[ $result -ne 0 || $file_size -lt 500000 ]] # less than 500K
    then
      echo "Failed download: $1, size: "$file_size"B, aborting." >&2 # output on stderr.
      exit 65
    else
      echo "Decompressing $file_name"
      tar zxf $file_name
    fi
  fi
}

function download_and_decompress_files () {
  # download all needed files.
  for (( i=0; i<${#apps[*]}; i++ ))
  do
    try_download ${files[$i]} ${urls[$i]}
  done
}

function should_install_check () {
  for app in ${apps[@]}
  do
    if [[ $app == ${1} ]]
    then 
      return 0
    fi
  done
  return 1
}

# Before running anything try to download all requires files, saving time.
#to_install "ghostscript" http://ghostscript.googlecode.com/files/ghostscript-8.70.tar.gz
#to_install "freetype" http://"$SF_MIRROR".dl.sourceforge.net/project/freetype/freetype2/2.3.11/freetype-2.3.11.tar.gz
#to_install "gs-fonts" http://"$SF_MIRROR".dl.sourceforge.net/gs-fonts/ghostscript-fonts-std-8.11.tar.gz
#to_install "libwmf" http://"$SF_MIRROR".dl.sourceforge.net/project/wvware/libwmf/0.2.8.4/libwmf-0.2.8.4.tar.gz
#to_install "jpegsrc" http://www.ijg.org/files/jpegsrc.v7.tar.gz
#to_install "libtiff" ftp://ftp.remotesensing.org/pub/libtiff/tiff-3.9.2.tar.gz
#to_install "libpng" ftp://ftp.simplesystems.org/pub/libpng/png/src/libpng-1.2.42.tar.gz
#to_install "lcms" http://www.littlecms.com/lcms-1.19.tar.gz
to_install "ImageMagick" ftp://ftp.imagemagick.org/pub/ImageMagick/ImageMagick-6.5.9-0.tar.gz

# Decompress applications.
download_and_decompress_files

echo "Starting..."

# LibPNG.
# Official PNG reference library.
should_install_check 'libpng'
if [[ $? -eq 0 ]]
then
  cd libpng-1.2.42
  ./configure --prefix=$CONFIGURE_PREFIX
  make
  sudo make install
  cd ..
fi

# JPEG.
# Library for JPEG image compression.
should_install_check 'jpegsrc'
if [[ $? -eq 0 ]]
then
  cd jpeg-7
  ln -s `which glibtool` ./libtool
  export MACOSX_DEPLOYMENT_TARGET=$DEPLOYMENT_TARGET
  ./configure --enable-shared --prefix=$CONFIGURE_PREFIX
  make
  sudo make install
  cd ..
fi

# Little cms.
# A free color management engine in 100K.
should_install_check 'lcms'
if [[ $? -eq 0 ]]
then
  cd lcms-1.19
  make clean
  ./configure
  make
  sudo make install
  cd ..
fi

# GhostScript.
# Interpreter for the PostScript language and for PDF.
should_install_check 'ghostscript'
if [[ $? -eq 0 ]]
then
  cd ghostscript-8.70
  ./configure --prefix=$CONFIGURE_PREFIX
  make
  sudo make install
  cd ..
fi

# Ghostscript Fonts.
# Fonts and font metrics customarily distributed with Ghostscript.
should_install_check 'gs-fonts'
if [[ $? -eq 0 ]]
then
  sudo rm -rf $CONFIGURE_PREFIX/share/ghostscript/fonts # cleanup
  sudo mv fonts $CONFIGURE_GS_FONT
fi

# The FreeType Project.
# A free, high-quality and portable font engine.
should_install_check 'freetype'
if [[ $? -eq 0 ]]
then
  cd freetype-2.3.11
  ./configure --prefix=$CONFIGURE_PREFIX
  make
  sudo make install
  cd ..
fi

# libwmf.
# library to convert wmf files
should_install_check 'libwmf'
if [[ $? -eq 0 ]]
then
  cd libwmf-0.2.8.4
  make clean
  ./configure --without-expat --with-xml --with-png=/usr/X11
  make
  sudo make install
  cd ..
fi

# LibTIFF.
# Support for the Tag Image File Format (TIFF)
should_install_check 'libtiff'
if [[ $? -eq 0 ]]
then
  cd tiff-3.9.2
  ./configure --prefix=$CONFIGURE_PREFIX
  make
  sudo make install
  cd ..
fi

# ImageMagick.
# Software suite to create, edit, and compose bitmap images.
should_install_check 'ImageMagick'
if [[ $? -eq 0 ]]
then
  cd ImageMagick-6.5.9-0
  
  if [[ -d $CONFIGURE_GS_FONT ]]
  then
    IMAGEMAGICK_ARGUMENTS="$IMAGEMAGICK_ARGUMENTS --with-gs-font-dir=$CONFIGURE_GS_FONT"
  fi
  
  export CPPFLAGS=-I$CONFIGURE_PREFIX/include
  export LDFLAGS=-L$CONFIGURE_PREFIX/lib
  ./configure --prefix=$CONFIGURE_PREFIX $IMAGEMAGICK_ARGUMENTS 
  make
  sudo make install
  cd ..
fi

echo "ImageMagick installed."
convert -version

echo "Testing..."
$CONFIGURE_PREFIX/bin/convert logo: logo.gif
$CONFIGURE_PREFIX/bin/convert logo: logo.jpg
$CONFIGURE_PREFIX/bin/convert logo: logo.png
$CONFIGURE_PREFIX/bin/convert logo: logo.tiff
echo "Tests done."

exit