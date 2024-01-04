#!/bin/bash
#
# Updates the list of current posts on the blog.

set -x

BASEDIR=$(pwd)
DATADIR=$BASEDIR/data
SCRIPTDIR=$BASEDIR/scripts

LISTBLOGPOSTS=$SCRIPTDIR/list_blogger_posts.py
BLOGLIST=/tmp/blogposts.$$.txt
NEWBLOGURLS=/tmp/blogurls.$$.new
OLDBLOGURLS=/tmp/blogurls.$$.old
SVNBLOGLIST=$DATADIR/blogposts.txt
URL2TWEET=$SCRIPTDIR/url2tweet.sh

if [[ ! -s $SVNBLOGLIST ]]
then
  echo "Cannot find existing list of blog posts"
  exit 1
fi

$LISTBLOGPOSTS > $BLOGLIST
if [[ $? -ne 0 ]]
then
  echo "Error fetching list of blog posts."
  exit 1
fi

if [[ ! -s $BLOGLIST ]]
then
  echo "Error fetching list of blog posts (is empty)."
  rm -f $BLOGLIST
  exit 1
fi

cat $BLOGLIST | tr ',' '\n' | grep ^http: > $NEWBLOGURLS
cat $SVNBLOGLIST | tr ',' '\n' | grep ^http: > $OLDBLOGURLS
NEWURLS=$(for url in `cat $NEWBLOGURLS` ; do \
grep -c $url $OLDBLOGURLS > /dev/null ; \
if [[ $? -ne 0 ]] ; then echo $url ; fi ; \
  done )
if [[ -z $NEWURLS ]]
then
  rm -f $NEWBLOGURLS $OLDBLOGURLS $BLOGLIST
  exit 0
fi

count=0
for url in $NEWURLS
do
  line=`grep ,${url}$ $BLOGLIST`
  title=`echo $line | cut -d',' -f1`
  $URL2TWEET "$title" "$url"
  if [[ $? -ne 0 ]]
  then
    echo "Failed to tweet new URL \"$url\""
    exit 1
  fi
  let "count += 1"
done
echo "count = $count"
#exit 0

if [[ $count -eq 0 ]]
then
  # Nothing's changed.
  rm -f $NEWBLOGURLS $OLDBLOGURLS $BLOGLIST
  exit 1
fi

cp $SVNBLOGLIST $SVNBLOGLIST.old
mv $BLOGLIST $SVNBLOGLIST
if [[ $? -ne 0 ]]
then
  echo "Error moving $BLOGLIST to $SVNBLOGLIST"
  mv $SVNBLOGLIST.old $SVNBLOGLIST
  rm -f $NEWBLOGURLS $OLDBLOGURLS $BLOGLIST
  exit 1
fi

rm -f $NEWBLOGURLS $OLDBLOGURLS

#svn commit -m "Found $count new posts to tweet." $SVNBLOGLIST > /dev/null 2>&1
#rc=$?
#if [[ $rc -ne 0 ]]
#then
#  echo "Error checking new blog list into SVN: $rc"
#  mv $SVNBLOGLIST.old $SVNBLOGLIST
#  exit 1
#fi  
rm -f $SVNBLOGLIST.old
exit 0
