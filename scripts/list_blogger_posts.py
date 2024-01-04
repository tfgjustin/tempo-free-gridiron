#!/usr/bin/python2.7
# -*- coding: utf-8 -*-


"""Simple command-line sample for Blogger.

Command-line application that retrieves the users blogs and posts.

Usage:
  $ python blogger_post.py

You can also get help on all the command-line flags the program understands
by running:

  $ python blogger_post.py --help

To get detailed log output run:

  $ python blogger_post.py --logging_level=DEBUG
"""

__author__ = 'jcgregorio@google.com (Joe Gregorio)'

import gflags
import httplib2
import logging
import pprint
import re
import sys
import os

from apiclient.discovery import build
from oauth2client.file import Storage
from oauth2client.client import AccessTokenRefreshError
from oauth2client.client import flow_from_clientsecrets
from oauth2client import tools

FLAGS = gflags.FLAGS

# CLIENT_SECRETS, name of a file containing the OAuth 2.0 information for this
# application, including client_id and client_secret, which are found
# on the API Access tab on the Google APIs
# Console <http://code.google.com/apis/console>
CLIENT_SECRETS = 'client_secrets.json'
CLIENT_SECRETS_FILE = os.path.join(os.path.dirname(__file__), CLIENT_SECRETS)
BLOGGER_DAT    = 'blogger.dat'
BLOGGER_DAT_FILE = os.path.join(os.path.dirname(__file__), BLOGGER_DAT)
TFG_BLOG_ID = '__provide_this__'

# Helpful message to display in the browser if the CLIENT_SECRETS file
# is missing.
MISSING_CLIENT_SECRETS_MESSAGE = """
WARNING: Please configure OAuth 2.0

To make this sample run you will need to populate the client_secrets.json file
found at:

%s

with information from the APIs Console <https://code.google.com/apis/console>.

""" % CLIENT_SECRETS_FILE

def PrintBlogPost(post):
  print '%s,%s' % (post['title'].replace(',', ' '), post['url'])

def PrintBlogPosts(http, posts, token):
  req = posts.list(blogId=TFG_BLOG_ID, orderBy='published', pageToken=token,
                   status=['live'], fetchBodies=False, maxResults=50)
  resp = req.execute(http)
  if 'items' not in resp:
    return
  for post in resp['items']:
    PrintBlogPost(post)
#  if 'nextPageToken' not in resp or resp['nextPageToken'] is None:
#    return
#  PrintBlogPosts(http, posts, resp['nextPageToken'])
  return

# Set up a Flow object to be used if we need to authenticate.
FLOW = flow_from_clientsecrets(CLIENT_SECRETS_FILE,
           scope='https://www.googleapis.com/auth/blogger',
           message=MISSING_CLIENT_SECRETS_MESSAGE)

# The gflags module makes defining command-line options easy for
# applications. Run this program with the '--help' argument to see
# all the flags that it understands.
gflags.DEFINE_enum('logging_level', 'ERROR',
    ['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'],
    'Set the level of logging detail.')

def main(argv):
  # Let the gflags module process the command-line arguments
  try:
    argv = FLAGS(argv)
  except gflags.FlagsError, e:
    print '%s\nUsage: %s ARGS\n%s' % (e, argv[0], FLAGS)
    sys.exit(1)

  # Set the logging according to the command-line flag
  logging.getLogger().setLevel(getattr(logging, FLAGS.logging_level))

  # If the Credentials don't exist or are invalid run through the native client
  # flow. The Storage object will ensure that if successful the good
  # Credentials will get written back to a file.
  storage = Storage(BLOGGER_DAT_FILE)
  credentials = storage.get()
  if credentials is None or credentials.invalid:
    credentials = tools.run_flow(FLOW, storage)

  # Create an httplib2.Http object to handle our HTTP requests and authorize it
  # with our good Credentials.
  http = httplib2.Http()
  http = credentials.authorize(http)

  service = build("blogger", "v3", http=http)
  posts = service.posts();
  labels = []
  try:
    PrintBlogPosts(http, posts, None)

  except AccessTokenRefreshError:
    print ("The credentials have been revoked or expired, please re-run"
      "the application to re-authorize")

if __name__ == '__main__':
  main(sys.argv)
