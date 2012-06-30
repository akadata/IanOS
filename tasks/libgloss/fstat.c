#include <sys/stat.h>
#include <errno.h>
#include "filesystem.h"

#undef errno
extern int errno;

int fstat(int fildes, struct stat *st)
{
	struct FileInfo inf;
	sys_fstat(fildes, &inf);
	st->st_mode = S_IFCHR;
	st->st_ino = inf.inode;
	st->st_mode = inf.mode;
	st->st_uid = inf.uid;
	st->st_gid = inf.gid;
  	st->st_size = inf.size;
  	st->st_atime = inf.atime;
  	st->st_ctime = inf.ctime;
  	st->st_mtime = inf.mtime;
  	errno = 0;
  	return 0;
}

