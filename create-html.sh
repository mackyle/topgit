#!/bin/sh

# Create the tg-foo.html files which contain a relocation to topgit.html#tg-foo

# Some command line "helpers" that open html files refuse to pass along an
# anchor attached to a file:///... URL or bare /file... name.  Since all our
# HTML help is in one file with anchors, we create small helper .html files
# that redirect to the main file and the proper anchor.

if [ $# -ne 1 ] ; then
	echo "Usage: $0 <tgcommand>" 1>&2
	exit 1
fi

anchor=
[ "$1" = "tg" ] || anchor="#tg-$1"
cat <<EOT > tg-"$1".html
<?xml version="1.0" encoding="utf-8" ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta http-equiv="Refresh" content="0;URL='topgit.html$anchor'" />
<title>tg help $1</title>
</head>
<body>
<p>Click <a href="topgit.html$anchor">here</a> if your browser does not automatically redirect you.</p>
</body>
</html>
EOT

# vim:noet
