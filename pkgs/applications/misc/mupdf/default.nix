{ stdenv
, lib
, fetchurl
, fetchpatch
, desktopToDarwinBundle
, pkg-config
, freetype
, harfbuzz
, openjpeg
, jbig2dec
, libjpeg
, darwin
, gumbo
, enableX11 ? (!stdenv.isDarwin)
, libX11
, libXext
, libXi
, libXrandr
, enableCurl ? true
, curl
, openssl
, enableGL ? true
, freeglut
, libGLU
, xcbuild
}:
let

  # OpenJPEG version is hardcoded in package source
  openJpegVersion = with stdenv;
    lib.versions.majorMinor (lib.getVersion openjpeg);


in
stdenv.mkDerivation rec {
  version = "1.19.0";
  pname = "mupdf";

  src = fetchurl {
    url = "https://mupdf.com/downloads/archive/${pname}-${version}-source.tar.gz";
    sha256 = "1vfyhlqq1a0k0drcggly4bgsjasmf6lmpfbdi5xcrwdbzkagrbr1";
  };

  patches = [ ./0001-Use-command-v-in-favor-of-which.patch
              ./0002-Add-Darwin-deps.patch
            ];

  postPatch = ''
    sed -i "s/__OPENJPEG__VERSION__/${openJpegVersion}/" source/fitz/load-jpx.c
  '';

  # Use shared libraries to decrease size
  buildFlags = [ "shared" ];

  makeFlags = [ "prefix=$(out)" "USE_SYSTEM_LIBS=yes" ]
    ++ lib.optionals (!enableX11) [ "HAVE_X11=no" ]
    ++ lib.optionals (!enableGL) [ "HAVE_GLUT=no" ];

  nativeBuildInputs =
    [ pkg-config ] ++ lib.optional stdenv.isDarwin desktopToDarwinBundle;

  buildInputs = [ freetype harfbuzz openjpeg jbig2dec libjpeg gumbo ]
    ++ lib.optional stdenv.isDarwin xcbuild
    ++ lib.optionals enableX11 [ libX11 libXext libXi libXrandr ]
    ++ lib.optionals enableCurl [ curl openssl ]
    ++ lib.optionals enableGL (
    if stdenv.isDarwin then
      with darwin.apple_sdk.frameworks; [ GLUT OpenGL ]
    else
      [ freeglut libGLU ]
  )
  ;
  outputs = [ "bin" "dev" "out" "man" "doc" ];

  preConfigure = ''
    # Don't remove mujs because upstream version is incompatible
    rm -rf thirdparty/{curl,freetype,glfw,harfbuzz,jbig2dec,libjpeg,openjpeg,zlib}
  '';

  postInstall = ''
    mkdir -p "$out/lib/pkgconfig"
    cat >"$out/lib/pkgconfig/mupdf.pc" <<EOF
    prefix=$out
    libdir=$out/lib
    includedir=$out/include

    Name: mupdf
    Description: Library for rendering PDF documents
    Version: ${version}
    Libs: -L$out/lib -lmupdf -lmupdf-third
    Cflags: -I$dev/include
    EOF

    moveToOutput "bin" "$bin"
  '' + lib.optionalString enableX11 ''
    ln -s "$bin/bin/mupdf-x11" "$bin/bin/mupdf"
    mkdir -p $bin/share/applications
    cat > $bin/share/applications/mupdf.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Version=1.0
    Name=mupdf
    Comment=PDF viewer
    Exec=$bin/bin/mupdf-x11 %f
    Terminal=false
    MimeType=application/pdf;application/x-pdf;application/x-cbz;application/oxps;application/vnd.ms-xpsdocument;application/epub+zip
    EOF
  '';

  enableParallelBuilding = true;

  meta = with lib; {
    homepage = "https://mupdf.com";
    repositories.git = "git://git.ghostscript.com/mupdf.git";
    description = "Lightweight PDF, XPS, and E-book viewer and toolkit written in portable C";
    license = licenses.agpl3Plus;
    maintainers = with maintainers; [ vrthra fpletz ];
    platforms = platforms.unix;
  };
}
