#!/usr/bin/python

import oauth2 as oauth
import sys
import urllib

POST_API='https://api.twitter.com/1.1/statuses/update.json'

class AccessInfo():
    _consumer_key = ''
    _consumer_secret = ''
    _access_token = ''
    _access_token_secret = ''
    def __init__(self):
        pass

    def consumer_key(self):
        return self._consumer_key

    def consumer_secret(self):
        return self._consumer_secret

    def access_token(self):
        return self._access_token

    def access_token_secret(self):
        return self._access_token_secret


class LiveOddsAccessInfo(AccessInfo):
    def __init__(self):
        self._consumer_key = ''
        self._consumer_secret = ''
        self._access_token = ''
        self._access_token_secret = ''


class TfgMainAccessInfo(AccessInfo):
    def __init__(self):
        self._consumer_key = ''
        self._consumer_secret = ''
        self._access_token = ''
        self._access_token_secret = ''


def oauth_post(status, access_info):
    consumer = oauth.Consumer(key=access_info.consumer_key(),
                              secret=access_info.consumer_secret())
    token = oauth.Token(key=access_info.access_token(),
                        secret=access_info.access_token_secret())
    client = oauth.Client(consumer, token)
    tweet_body=urllib.parse.urlencode({'status': status, 'wrap_links': True})
    try:
        resp, content = client.request(
            POST_API,
            method='POST',
            body=tweet_body,
        )
        print(resp)
        print(content)
    except oauth.Error as err:
      print('Twitter error: %s' % (err))
      return 1
    return 0

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print ('Usage: %s <main|odds> <message>' % (sys.argv[0]))
        sys.exit(1)
    access_info = None
    if sys.argv[1] == 'main':
        access_info = TfgMainAccessInfo()
    elif sys.argv[1] == 'odds':
        access_info = LiveOddsAccessInfo()
    else:
        print('Invalid mode "%s": must be either "main" or "odds"' % (sys.argv[1]))
        sys.exit(1)
    rc = oauth_post(sys.argv[2], access_info)
    sys.exit(rc)
