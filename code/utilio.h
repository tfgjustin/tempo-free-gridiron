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

#ifndef _UTIL_IO_H
#define _UTIL_IO_H

#include <netdb.h>

#ifndef BUFSIZE
#define BUFSIZE 512
#endif

#ifndef MAX_BUFSZIE
#define MAX_BUFSIZE (64*1024) /* 64 KB */
#endif

#ifndef IP_ADDRLEN
#define IP_ADDRLEN 16
#endif

/*
 * Simple macro to close unused fd.
 * Programmer must make sure invalid fds have values of -1.
 */
#define test_and_close(fd) { if((fd) >= 0) { close((fd)); (fd) = -1; } }

/*
 * How do we handle whitespace in the buffer (whitespace handler enum)?
 * ws_is_delim: it's a delimiter, so NULL it out wherever we see it
 * ws_around_delim: only zero out whitespace that is around other
 *                  delimiters we've already come across.
 * ws_keep: treat whitespace as a normal character.
 *
 * Example: buf[] = "foo ? bar, and baz ? X";
 *          delim = "?,"
 * With ws_is_delim:     args[][] = "foo", "bar", "and", "baz", "X"
 *  ''  ws_around_delim: args[][] = "foo", "bar" "and baz", "X"
 *  ''  ws_keep:         args[][] = "foo ", " bar", " and baz ", " X"
 */
typedef enum {
  ws_is_delim = 0,
  ws_around_delim,
  ws_keep
} ws_handler;

extern int split(char *delim, char *buf, char *args[], int maxargs,
                 ws_handler spaces);
extern void chomp(char *buf);

extern int can_read(int fd);
extern int can_write(int fd);
extern int wait_read(int fd);
extern int wait_write(int fd);

extern int get_line(char *buf, int len, FILE *fp);
extern int get_bin_line(char *buf, int len, FILE *fp);
extern int gets_line(char *buf, int len, const char *sbuf);

#endif /* _UTIL_IO_H */
