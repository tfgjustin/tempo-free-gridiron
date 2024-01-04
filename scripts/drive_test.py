#!/usr/bin/python

import gflags
import httplib2
import os
import pprint
import sys

from apiclient.discovery import build
from apiclient.http import MediaFileUpload
from oauth2client.file import Storage
from oauth2client.client import AccessTokenRefreshError
from oauth2client.client import flow_from_clientsecrets
from oauth2client import tools

FLAGS = gflags.FLAGS

gflags.DEFINE_string('play_filename', None, 'Name of the play-by-play CSV')

# CLIENT_SECRETS, name of a file containing the OAuth 2.0 information for this
# application, including client_id and client_secret, which are found
# on the API Access tab on the Google APIs
# Console <http://code.google.com/apis/console>
CLIENT_SECRETS = 'client_secrets.json'
CLIENT_SECRETS_FILE = os.path.join(os.path.dirname(__file__), CLIENT_SECRETS)
DRIVE_DAT    = 'drive.dat'
DRIVE_DAT_FILE = os.path.join(os.path.dirname(__file__), DRIVE_DAT)

# Helpful message to display in the browser if the CLIENT_SECRETS file
# is missing.
MISSING_CLIENT_SECRETS_MESSAGE = """
WARNING: Please configure OAuth 2.0

To make this sample run you will need to populate the client_secrets.json file
found at:

%s

with information from the APIs Console <https://code.google.com/apis/console>.

""" % CLIENT_SECRETS_FILE


# Copy your credentials from the console
CLIENT_ID = '__update_this__'
CLIENT_SECRET = '__update_this__'

# Check https://developers.google.com/drive/scopes for all available scopes
OAUTH_SCOPE = 'https://www.googleapis.com/auth/drive'

# Redirect URI for installed apps
REDIRECT_URI = 'urn:ietf:wg:oauth:2.0:oob'

def ConnectToDrive():
  # Set up a Flow object to be used if we need to authenticate.
  FLOW = flow_from_clientsecrets(CLIENT_SECRETS_FILE,
                                 scope='https://www.googleapis.com/auth/drive',
                                 message=MISSING_CLIENT_SECRETS_MESSAGE)
  # If the Credentials don't exist or are invalid run through the native client
  # flow. The Storage object will ensure that if successful the good
  # Credentials will get written back to a file.
  storage = Storage(DRIVE_DAT_FILE)
  credentials = storage.get()
  if credentials is None or credentials.invalid:
    credentials = tools.run_flow(FLOW, storage)

  # Create an httplib2.Http object to handle our HTTP requests and authorize it
  # with our good Credentials.
  http = httplib2.Http()
  http = credentials.authorize(http)
  return build('drive', 'v2', http=http)

def ParsePerGame():
  all_lines = []
  try:
    with open(FLAGS.play_filename, 'r') as fh:
      all_lines = [line.strip() for line in fh]
  except:
    return None
  header = all_lines.pop(0)
  per_game = {}
  for line in all_lines:
    game_id = line.split(',', 1)[0]
    if not game_id:
      print 'Missing game ID from %s' % (line)
      continue
    if not game_id in per_game:
      per_game[game_id] = [ line ]
    else:
      per_game[game_id].append(line)
#  print 'Found data for %d games' % len(per_game)
  return [header, per_game]

def SyncWithDrive(per_game_data, drive_service):
  header = per_game_data[0]
  per_game = per_game_data[1]
#  for game_id in sorted(per_game.keys()):
#    print '%d%s' % (len(per_game[game_id]), game_id)
  # TODO: List all the play-by-play files in a directory
  
  # TODO: Iterate over the set of files and only upload ones for which we
  # don't have files that exist.
  # Insert a file
  #media_body = MediaFileUpload(FILENAME, mimetype='text/csv', resumable=True)
  #body = {
  #  'title': 'Test Play-by-Play',
  #  'description': 'A test spreadsheet',
  #  'mimeType': 'text/csv'
  #}
  #
  #file = drive_service.files().insert(body=body, media_body=media_body, convert=True).execute()
  #pprint.print(file)
  #list_data = drive_service.files().list().execute()
  #pprint.pprint(list_data)


def main(argv):
  try:
    argv = FLAGS(argv)
  except gflags.FlagsError, e:
    print '%s\nUsage: %s ARGS\n%s' % (e, argv[0], FLAGS)
    sys.exit(1)

  if not FLAGS.play_filename:
    print 'Missing play-by-play file'
    print '%s\nUsage: %s ARGS\n%s' % (e, argv[0], FLAGS)
    sys.exit(1)

  per_game_data = ParsePerGame()
  if not per_game_data or len(per_game_data) != 2:
    print 'Invalid play-by-play file %s' % FLAGS.play_filename
    print 'Usage: %s ARGS\n%s' % (argv[0], FLAGS)
    sys.exit(1)

  drive_service = ConnectToDrive()
  SyncWithDrive(per_game_data, drive_service)


if __name__ == '__main__':
  main(sys.argv)
