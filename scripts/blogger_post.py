#!/usr/bin/python2.7
# -*- coding: utf-8 -*-
#
# Copyright (C) 2010 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
gflags.DEFINE_string('post_time', None, 'Time of the post in HH:MM:SS-ZZZZ format.')
gflags.DEFINE_string('post_file', None, 'File containing the most recent HTML contents.')
gflags.DEFINE_string('post_title', None, 'Title of the new post.')
gflags.DEFINE_string('post_labels', None, 'Additional labels for the post.')

def IsValidPostTime(timestamp_string):
  if not timestamp_string:
    return True
  # 2014-10-20T11:00:00-04:00:00
  d = re.compile(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}-\d{2}:\d{2}:\d{2}$')
  return d.match(timestamp_string)

def CreateBlogPost(title, labels, contents, post_date, posts, http):
  print 'Attempting to create new blog post "%s" at %s (%s)' % (title, post_date, labels)
  post = { 'content': contents,
           'kind': 'blogger#post',
           'author': { 'displayName': '__name__', 'id': '__id__' },
           'labels': labels,
           'blog': { 'id': TFG_BLOG_ID },
           'title': title,
           'published': post_date,
         }
  request = posts.insert(blogId=TFG_BLOG_ID, body=post)
  if not request:
    print 'Could not assemble insert request'
    sys.exit(1)
  inserted_post = request.execute(http)
  return

def SanitizeContents(contents):
  lines = contents.splitlines()
  outlines = []
  for l in lines:
    if l.startswith('<!-- ') and l.find('|') >= 0:
      continue
    elif l.find('type="text/css"') >= 0:
      continue
    else:
      outlines.append(l)
  return '\n'.join(outlines)

def main(argv):
  # Let the gflags module process the command-line arguments
  try:
    argv = FLAGS(argv)
  except gflags.FlagsError:
    print 'X) %s\nUsage: %s ARGS\n%s' % (e, argv[0], FLAGS)
    sys.exit(1)

  # Set the logging according to the command-line flag
  logging.getLogger().setLevel(getattr(logging, FLAGS.logging_level))

  if not IsValidPostTime(FLAGS.post_time):
    print '\nInvalid post time: %s' % (FLAGS.post_time)
    sys.exit(1)

  if not FLAGS.post_file:
    print 'Y)\nUsage: %s ARGS\n%s' % (argv[0], FLAGS)
    sys.exit(1)

  f = open(FLAGS.post_file, mode='r')
  contents = f.read()
  f.close()
  print 'Read %d bytes from %s' % (len(contents), FLAGS.post_file)
  contents = SanitizeContents(contents);

  # If the Credentials don't exist or are invalid run through the native client
  # flow. The Storage object will ensure that if successful the good
  # Credentials will get written back to a file.
  storage = Storage(BLOGGER_DAT_FILE)
  credentials = storage.get()
  if credentials is None or credentials.invalid:
    try:
      credentials = tools.run_flow(FLOW, storage)
    except Exception as e:
      print 'Flow failed'
      print e

  # Create an httplib2.Http object to handle our HTTP requests and authorize it
  # with our good Credentials.
  http = httplib2.Http()
  http = credentials.authorize(http)

  service = build("blogger", "v3", http=http)
  posts = service.posts();
  labels = []
  if FLAGS.post_labels:
    labels = FLAGS.post_labels.split(',');
    if len(labels) > 15:
      labels = labels[:15]
  try:
    CreateBlogPost(FLAGS.post_title, labels, contents, FLAGS.post_time, posts, http)

  except AccessTokenRefreshError:
    print ("The credentials have been revoked or expired, please re-run"
      "the application to re-authorize")

if __name__ == '__main__':
  main(sys.argv)
