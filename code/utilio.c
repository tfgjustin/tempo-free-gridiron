/* 
 * Copyright 2001-2004 Justin Moore, justin@cs.duke.edu
 *
 * This software may be freely redistributed under the terms of the GNU
 * public license.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 */

#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>

#include "utilio.h"

int split(char *delim, char *buf, char *args[], int maxargs,
          ws_handler spaces)
{
  char *p;
  char *empty_delim = "";
  char *my_delim;
  int nargs;

  if(!buf || !args || (maxargs < 1))
    return -1;

  if(!delim)
    my_delim = empty_delim;
  else
    my_delim = delim;

  memset(args, 0, (maxargs * sizeof(char*)));
  nargs = 0;
  p = buf;
  while(*p) {                   /* Leading delims */
    if(isspace((int) (*p))) {
      if((spaces != ws_keep) || strchr(my_delim, *p))
        *p++ = '\0';
      else
        break;
    }
    else if(strchr(my_delim, *p))
      *p++ = '\0';
    else
      break;
  }
  if(*p)
    args[nargs++] = p;
  else
    return 0;

  /*
   * Currently we're pointing at the first valid character in this
   * buffer.  Move along to an invalid character, and zero out the
   * delimiter stuff.
   */
  while(*p && (nargs < maxargs)) {
    /*
     * Move past all the valid characters 
     */
    while(*p) {
      if(isspace((int) (*p))) {
        if((spaces != ws_is_delim) && !strchr(my_delim, *p))
          p++;
        else
          break;
      }
      else if(!strchr(my_delim, *p))
        p++;
      else
        break;
    }
    if(*p == '\0')
      break;

    /*
     * If we did ws_around_delim, go backwards to find whitespace.
     */
    if(spaces == ws_around_delim) {
      char *q;

      q = p - 1;
      while(*q && (q >= buf)) {
        if(isspace((int) (*q)))
          *q-- = '\0';
        else
          break;
      }
      if(q == buf)
        return 0;
    }

    *p++ = '\0';
    while(*p) {                 /* Trailing delims */
      if(isspace((int) (*p))) {
        if((spaces != ws_keep) && !strchr(my_delim, *p))
          *p++ = '\0';
        else
          break;
      } else if(strchr(my_delim, *p))
        *p++ = '\0';
      else
        break;
    }
    if(*p == '\0')
      break;
    else
      args[nargs++] = p;
  }

  return nargs;
}

void chomp(char *buf)
{
  char *p;
  p = strrchr(buf, '\n');
  if(p)
    *p = '\0';
}

typedef enum {
  io_wait = 0,
  io_can
} io_pref;

typedef enum {
  io_read = 0,
  io_write
} io_mode;

static int io(int fd, io_mode mode, io_pref pref)
{
  int rc;
  fd_set set;
  struct timeval tv;
  struct timeval *tvp;

  if(fd < 0)
    return 0;

  if((pref != io_can) && (pref != io_wait))
    return 0;
  if((mode != io_read) && (mode != io_write))
    return 0;

  tvp = &tv;

  while(1) {
    FD_ZERO(&set);
    FD_SET(fd, &set);

    errno = 0;
    if(pref == io_can) {
      tv.tv_sec = 0;
      tv.tv_usec = 0;
    } else                      /* io_wait */
      tvp = NULL;

    if(mode == io_read)
      rc = select(fd + 1, &set, NULL, NULL, tvp);
    else                        /* io_write */
      rc = select(fd + 1, NULL, &set, NULL, tvp);

    if(!rc || (rc == 1) || (errno != EINTR))
      break;
  }

  return rc;
}

int can_read(int fd)
{
  return io(fd, io_read, io_can);
}

int can_write(int fd)
{
  return io(fd, io_write, io_can);
}

int wait_read(int fd)
{
  return io(fd, io_read, io_wait);
}

int wait_write(int fd)
{
  return io(fd, io_write, io_wait);
}

int get_line(char *buf, int len, FILE * fp)
{
  char *p;

  memset(buf, 0, len);
  p = fgets(buf, len, fp);
  if(!p && ferror(fp))
    return -1;
  else if(!p && feof(fp))
    return 0;
  else
    return strlen(buf);
}

int get_bin_line(char *buf, int len, FILE * fp)
{
  size_t rc;

  memset(buf, 0, len);
  rc = fread(buf, 1, len, fp);
  if(ferror(fp))
    return -1;
  else
    return rc;
}

int gets_line(char *buf, int len, const char *sbuf)
{
  const char *p;
  int linelen;

  if(!buf || (len < 1) || !sbuf)
    return -1;

  p = strchr(sbuf, '\n');
  if(!p) {
    linelen = strlen(sbuf);

    if(linelen > (len + 1))     /* Need one for the terminating NULL */
      return -1;

    strncpy(buf, sbuf, linelen);
    buf[linelen] = '\0';

    return linelen;
  } else {
    linelen = (int) ((unsigned long) p - (unsigned long) sbuf);

    if(linelen > (len + 1))     /* Need one for the terminating NULL */
      return -1;

    memcpy(buf, sbuf, linelen);
    buf[linelen] = '\0';

    return (linelen + 1);
  }
}
