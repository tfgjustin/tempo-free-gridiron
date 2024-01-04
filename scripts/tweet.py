#!/usr/bin/python

import sys
from twitter import *

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


def post_image(upload_api, image):
  with open(image, "rb") as imagefile:
    data = imagefile.read();
    return upload_api.media.upload(media=data)['media_id_string']


def post(access_info, message, images):
#    api = Twitter(auth=Oauth(consumer_key=access_info.consumer_key(),
#                      consumer_secret=access_info.consumer_secret(),
#                      access_token_key=access_info.access_token(),
#                      access_token_secret=access_info.access_token_secret())
    twitter_auth = OAuth(
      consumer_key=access_info.consumer_key(),
      consumer_secret=access_info.consumer_secret(),
      token=access_info.access_token(),
      token_secret=access_info.access_token_secret(),
    )
    image_ids = []
    if len(images) > 0:
      upload_api = Twitter(domain='upload.twitter.com', auth=twitter_auth)
      for image_filename in images:
        image_id = post_image(upload_api, image_filename)
        image_ids.append(image_id)
    t = Twitter(auth=twitter_auth)
    t.statuses.update(status=message, media_ids=','.join(image_ids))
    return 0


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print ('Usage: %s <main|odds> <message> [image0]' % (sys.argv[0]))
        sys.exit(1)
    access_info = None
    mode = sys.argv[1]
    message = sys.argv[2]
    images=[]
    if len(sys.argv) > 3:
      images = sys.argv[3:]
    if mode == 'main':
        access_info = TfgMainAccessInfo()
    elif mode == 'odds':
        access_info = LiveOddsAccessInfo()
    else:
        print('Invalid mode "%s": must be either "main" or "odds"' % (mode))
        sys.exit(1)
    rc = post(access_info, message, images)
    sys.exit(rc)
