/*
 * Copyright 2001-2003 Justin Moore, justin@cs.duke.edu
 *
 * This software may be freely redistributed under the terms of the GNU
 * public license.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 */

#include <errno.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

#include <sys/time.h>

#include "utilio.h"
#include "utillog.h"

static s_log_level log_level = S_NOTICE;
static FILE *log_stream = NULL;
static char hname[BUFSIZE+1] = { 0 };

void set_log_level(s_log_level level)
{
  if(log_stream == NULL)
    log_stream = stderr;

  if(log_level >= 0)
    log_level = level;

  return;
}

void set_log_stream(FILE *fp)
{
  if(fp != NULL) {
    log_stream = fp;
  }
  setlinebuf(log_stream);
}

s_log_level get_log_level(void)
{
  return log_level;
}

int s_log(s_log_level level, char const *format, ...)
{
  int rc = 0;

  if(log_stream && (level <= log_level)) {
    char buf[BUFSIZE + 1];
    va_list ap;
    struct tm *tm;
    struct timeval tv;

    if(!(*hname))
      (void)gethostname(hname, BUFSIZE);

    (void) gettimeofday(&tv, NULL);
    tm = localtime((const time_t *) &tv.tv_sec);
    strftime(buf, BUFSIZE, "%F %H:%M:%S", tm);

    fprintf(log_stream, "%d: %s %lu %s.%06d] ", level, hname,
            pthread_self(), buf, (int) tv.tv_usec);
    va_start(ap, format);
    rc = vfprintf(log_stream, format, ap);
    va_end(ap);

    /*
     * Make sure all log entries end with a newline.
     */
    {
      int len = strlen(format);
      if(len && (format[len - 1] != '\n'))
        fprintf(log_stream, "\n");
    }
  }

  return rc;
}
