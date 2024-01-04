#!/bin/bash
#
# Posts a tweet and a short URL.
#
# To install:
#   1. sudo apt-get install ruby
#   2. sudo gem i oauth
#   3. ./twurl/bin/twurl authorize --consumer-key $TWITTER_CONSUMER_KEY \
#         --consumer-secret $TWITTER_CONSUMER_SECRET
#   4. Go to URL and paste result.

if [[ $# != 2 ]]; then
  echo "Usage:  $0 'tweet contents' 'tempo-free-url'"
  exit 1
fi;

TWITTER_API_KEY="__provide_this__"
TWITTER_CONSUMER_KEY="__provide_this__"
TWITTER_CONSUMER_SECRET="__provide_this__"
TWITTER_REQUEST_TOKEN_URL="https://api.twitter.com/oauth/request_token"
TWITTER_ACCESS_TOKEN_URL="https://api.twitter.com/oauth/access_token"
TWITTER_AUTHORIZE_URL="https://api.twitter.com/oauth/authorize"

TWITTER_TAGS="#NCAA #Football"
#TWITTER_TAGS="#SSAC"

BASEDIR=$(pwd)
TWURL=$BASEDIR/twurl/bin/twurl
SEND_TWEET=$BASEDIR/scripts/send_tweet.py
CURL=`which curl`

TWEET="$1"
TFG_URL="$2"

if [[ ! -x $SEND_TWEET ]]
then
  echo "Cannot locate executable file $SEND_TWEET"
  exit 1
fi

if [[ -z $CURL ]]
then
  echo "Cannot locate curl binary."
  exit 1
fi

if [[ -z $TWEET ]]
then
  echo "Empty tweet. Exiting."
  exit 1
fi

if [[ -z $TFG_URL ]]
then
  echo "Empty URL. Exiting."
  exit 1
fi

whole_post="New blog post: \"$TWEET\" $TFG_URL $TWITTER_TAGS"
charcount=`echo -n "$whole_post" | wc -c`
to_cut=$(( $charcount - 280 ))
if [[ $to_cut -gt 0 ]]
then
  tweet_char_count=`echo -n "$TWEET" | wc -c`
  trunc_tweet=`echo -n "$TWEET" | dd bs=1 count=$(( $tweet_char_count - $to_cut - 4 ))`
  whole_post="New blog post: \"$trunc_tweet ...\" $TFG_URL $TWITTER_TAGS"
fi

$SEND_TWEET main "$whole_post"
if [[ $? -ne 0 ]]
then
  echo "Failed to tweet \"$whole_post\""
  exit 1
fi
exit 0
