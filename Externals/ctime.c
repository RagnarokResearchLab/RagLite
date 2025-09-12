/* ========================================================================
   $File: tools/ctime/ctime.c $
   $Date: 2016/05/08 02:15:52PM $
   $Revision: 6 $
   $Creator: Casey Muratori $
   $Notice:

   The author of this software MAKES NO WARRANTY as to the RELIABILITY,
   SUITABILITY, or USABILITY of this software. USE IT AT YOUR OWN RISK.

   This is a simple timing utility.  It is in the public domain.
   Anyone can use it, modify it, roll'n'smoke hardcopies of the source
   code, sell it to the terrorists, etc.

   But the author makes absolutely no warranty as to the reliability,
   suitability, or usability of the software.  There might be bad bugs
   in here.  It could delete all your files.  It could format your
   hard drive.  I have no idea.  If you lose all your files from using
   it, it is your fault.

   $

   ctime is a simple utility that helps you keep track of how much time
   you spend building your projects.  You use it the same way you would
   use a begin/end block profiler in your normal code, only instead of
   profiling your code, you profile your build.

   BASIC INSTRUCTIONS
   ------------------

   On the very first line of your build script, you do something like this:

	   ctime -begin timings_file_for_this_build.ctm

   and then on the very last line of your build script, you do

	   ctime -end timings_file_for_this_build.ctm

   That's all there is to it!  ctime will keep track of every build you
   do, when you did it, and how long it took.  Later, when you'd like to
   get a feel for how your build times have evolved, you can type

	   ctime -stats timings_file_for_this_build.ctm

   and it will tell you a number of useful statistics!


   ADVANCED INSTRUCTIONS
   ---------------------

   ctime has the ability to track the difference between _failed_ builds
   and _successful_ builds.  If you would like it to do so, you can capture
   the error status in your build script at whatever point you want,
   for example:

	   set LastError=%ERRORLEVEL%

   and then when you eventually call ctime to end the profiling, you simply
   pass that error code to it:

	   ctime -end timings_file_for_this_build.ctm %LastError%

   ctime can also dump all timings from a timing file into a textual
   format for use in other types of tools.  To get a CSV you can import
   into a graphing program or database, use:

	   ctime -csv timings_file_for_this_build.ctm

   Also, you may want to do things like timing multiple builds separately,
   or timing builds based on what compiler flags are active.  To do this,
   you can use separate timing files for each configuration by using
   the shell variables for the build at the filename, eg.:

	   ctime -begin timings_for_%BUILD_NAME%.ctm
	   ...
	   ctime -end timings_for_%BUILD_NAME%.ctm

   ======================================================================== */

#include <stdio.h>
#include <stdlib.h>
#include <io.h>
#include <time.h>
#include <fcntl.h>
#include <sys/stat.h>

#pragma pack(push, 1)

#define MAGIC_VALUE 0xCA5E713F
typedef struct timing_file_header {
	int unsigned MagicValue;
} timing_file_header;

typedef struct timing_file_date {
	int unsigned E[2];
} timing_file_date;

enum timing_file_entry_flag {
	TFEF_Complete = 0x1,
	TFEF_NoErrors = 0x2,
};
typedef struct timing_file_entry {
	timing_file_date StartDate;
	int unsigned Flags;
	int unsigned MillisecondsElapsed;
} timing_file_entry;

#pragma pack(pop)

typedef struct timing_entry_array {
	int EntryCount;
	timing_file_entry* Entries;
} timing_entry_array;

//
// TODO(casey): More platforms?  Sadly, ANSI C doesn't support high-resolution timing across runs of a process AFAICT :(
//

#include <windows.h>

static int unsigned
GetClock(void) {
	static_assert(sizeof(int unsigned) == sizeof(DWORD), "ERROR: Unexpected integer size - timing will not work on this platform!\n");

	return (timeGetTime());
}

static timing_file_date
GetDate(void) {
	timing_file_date Result = { 0 };

	FILETIME FileTime;
	GetSystemTimeAsFileTime(&FileTime);

	Result.E[0] = FileTime.dwLowDateTime;
	Result.E[1] = FileTime.dwHighDateTime;

	return (Result);
}

static void
PrintDate(timing_file_date Date) {
	FILETIME FileTime;
	SYSTEMTIME SystemTime;

	FileTime.dwLowDateTime = Date.E[0];
	FileTime.dwHighDateTime = Date.E[1];

	FileTimeToLocalFileTime(&FileTime, &FileTime);
	FileTimeToSystemTime(&FileTime, &SystemTime);

	fprintf(stdout, "%04d-%02d-%02d %02d:%02d.%02d",
		SystemTime.wYear, SystemTime.wMonth, SystemTime.wDay,
		SystemTime.wHour, SystemTime.wMinute, SystemTime.wSecond);
}

static double
MillisecondDifference(timing_file_date A, timing_file_date B) {
	ULARGE_INTEGER A64, B64;
	A64.LowPart = A.E[0];
	A64.HighPart = A.E[1];
	B64.LowPart = B.E[0];
	B64.HighPart = B.E[1];

	// NOTE(casey): FILETIME is in 100-nanosecond ticks, so there's a
	// coefficient to convert to milliseconds.
	return ((double)(A64.QuadPart - B64.QuadPart) * 0.0001);
}

static int unsigned
DayIndex(timing_file_date A) {
	double AD;
	ULARGE_INTEGER A64;

#if 0
    A64.LowPart = A.E[0];
    A64.HighPart = A.E[1];
#else
	// NOTE(casey): To help keeps things aligned with the user's local conception
	// of "day", we have the operating system floor to real local days here.

	FILETIME FileTime;
	SYSTEMTIME SystemTime;

	FileTime.dwLowDateTime = A.E[0];
	FileTime.dwHighDateTime = A.E[1];

	FileTimeToLocalFileTime(&FileTime, &FileTime);
	FileTimeToSystemTime(&FileTime, &SystemTime);

	SystemTime.wHour = 0;
	SystemTime.wMinute = 0;
	SystemTime.wSecond = 0;

	SystemTimeToFileTime(&SystemTime, &FileTime);

	A64.LowPart = FileTime.dwLowDateTime;
	A64.HighPart = FileTime.dwHighDateTime;
#endif

	AD = ((double)A64.QuadPart * (0.0001)) / (1000.0 * 60.0 * 60.0 * 24.0);

	return ((int unsigned)AD);
}

//
//
//

static void
Usage(void) {
	fprintf(stderr, "CTime v1.0 by Casey Muratori\n");
	fprintf(stderr, "Usage:\n");
	fprintf(stderr, "  ctime -begin <timing file>\n");
	fprintf(stderr, "  ctime -end <timing file> [error level]\n");
	fprintf(stderr, "  ctime -stats <timing file>\n");
	fprintf(stderr, "  ctime -csv <timing file>\n");
}

static timing_entry_array
ReadAllEntries(int Handle) {
	timing_entry_array Result = { 0 };

	long EntriesBegin = sizeof(timing_file_header);
	long FileSize = _lseek(Handle, 0, SEEK_END);
	if(FileSize > 0) {
		long EntriesSize = FileSize - EntriesBegin;
		Result.Entries = (timing_file_entry*)malloc(EntriesSize);
		if(Result.Entries) {
			long TestPos = _lseek(Handle, EntriesBegin, SEEK_SET);
			long ReadSize = _read(Handle, Result.Entries, EntriesSize);
			if(ReadSize == EntriesSize) {
				Result.EntryCount = EntriesSize / sizeof(timing_file_entry);
			} else {
				fprintf(stderr, "ERROR: Unable to read timing entries from file.\n");
			}
		} else {
			fprintf(stderr, "ERROR: Unable to allocate %d for storing timing entries.\n", EntriesSize);
		}
	} else {
		fprintf(stderr, "ERROR: Unable to determine file size of timing file.\n");
	}

	return (Result);
}

static void
FreeAllEntries(timing_entry_array Array) {
	if(Array.Entries) {
		free(Array.Entries);
		Array.EntryCount = 0;
		Array.Entries = 0;
	}
}

static void
CSV(timing_entry_array Array, char* TimingFileName) {
	int EntryIndex;
	timing_file_entry* Entry = Array.Entries;

	fprintf(stdout, "%s Timings\n", TimingFileName);
	fprintf(stdout, "ordinal, date, duration, status\n");
	{
		for(EntryIndex = 0;
			EntryIndex < Array.EntryCount;
			++EntryIndex, ++Entry) {
			fprintf(stdout, "%d, ", EntryIndex);
			PrintDate(Entry->StartDate);
			if(Entry->Flags & TFEF_Complete) {
				fprintf(stdout, ", %0.3fs, %s", (double)Entry->MillisecondsElapsed / 1000.0,
					(Entry->Flags & TFEF_NoErrors) ? "succeeded" : "failed");
			} else {
				fprintf(stdout, ", (never completed), failed");
			}

			fprintf(stdout, "\n");
		}
	}
}

typedef struct time_part {
	char* Name;
	double MillisecondsPer;
} time_part;

static void
PrintTime(double Milliseconds) {
	double MillisecondsPerSecond = 1000;
	double MillisecondsPerMinute = 60 * MillisecondsPerSecond;
	double MillisecondsPerHour = 60 * MillisecondsPerMinute;
	double MillisecondsPerDay = 24 * MillisecondsPerHour;
	double MillisecondsPerWeek = 7 * MillisecondsPerDay;
	time_part Parts[] = {
		{ "week", MillisecondsPerWeek },
		{ "day", MillisecondsPerDay },
		{ "hour", MillisecondsPerHour },
		{ "minute", MillisecondsPerMinute },
	};
	int unsigned PartIndex;
	double Q = Milliseconds;

	for(PartIndex = 0;
		PartIndex < (sizeof(Parts) / sizeof(Parts[0]));
		++PartIndex) {
		double MsPer = Parts[PartIndex].MillisecondsPer;
		double This = (double)(int)(Q / MsPer);

		if(This > 0) {
			fprintf(stdout, "%d %s%s, ", (int)This, Parts[PartIndex].Name,
				(This != 1) ? "s" : "");
		}
		Q -= This * MsPer;
	}

	fprintf(stdout, "%0.3f seconds", (double)Q / 1000.0);
}

static void
PrintTimeStat(char* Name, int unsigned Milliseconds) {
	fprintf(stdout, "%s: ", Name);
	PrintTime((double)Milliseconds);
	fprintf(stdout, "\n");
}

typedef struct stat_group {
	int unsigned Count;

	int unsigned SlowestMs;
	int unsigned FastestMs;
	double TotalMs;

} stat_group;

#define GRAPH_HEIGHT 5
#define GRAPH_WIDTH 150
typedef struct graph {
	stat_group Buckets[GRAPH_WIDTH];
} graph;

static void
PrintStatGroup(char* Title, stat_group* Group) {
	int unsigned AverageMs = 0;
	if(Group->Count >= 1) {
		AverageMs = (int unsigned)(Group->TotalMs / (double)Group->Count);
	}

	if(Group->Count > 0) {
		fprintf(stdout, "%s (%d):\n", Title, Group->Count);
		PrintTimeStat("  Slowest", Group->SlowestMs);
		PrintTimeStat("  Fastest", Group->FastestMs);
		PrintTimeStat("  Average", AverageMs);
		PrintTimeStat("  Total", (int unsigned)Group->TotalMs);
	}
}

static void
UpdateStatGroup(stat_group* Group, timing_file_entry* Entry) {
	if(Group->SlowestMs < Entry->MillisecondsElapsed) {
		Group->SlowestMs = Entry->MillisecondsElapsed;
	}

	if(Group->FastestMs > Entry->MillisecondsElapsed) {
		Group->FastestMs = Entry->MillisecondsElapsed;
	}

	Group->TotalMs += (double)Entry->MillisecondsElapsed;

	++Group->Count;
}

static int
MapToDiscrete(double Value, double InMax, double OutMax) {
	int Result;

	if(InMax == 0) {
		InMax = 1;
	}

	Result = (int)((Value / InMax) * OutMax);

	return (Result);
}

static void
PrintGraph(char* Title, double DaySpan, graph* Graph) {
	int unsigned BucketIndex;
	int LineIndex;
	int unsigned MaxCountInBucket = 0;
	int unsigned SlowestMs = 0;
	double DPB = DaySpan / (double)GRAPH_WIDTH;

	for(BucketIndex = 0;
		BucketIndex < GRAPH_WIDTH;
		++BucketIndex) {
		stat_group* Group = Graph->Buckets + BucketIndex;

		if(Group->Count) {
			//            double AverageMs = Group->TotalMs / (double)Group->Count;
			if(MaxCountInBucket < Group->Count) {
				MaxCountInBucket = Group->Count;
			}

			if(SlowestMs < Group->SlowestMs) {
				SlowestMs = Group->SlowestMs;
			}
		}
	}

	fprintf(stdout, "\n%s (%f day%s/bucket):\n", Title, DPB, (DPB == 1) ? "" : "s");
	for(LineIndex = GRAPH_HEIGHT - 1;
		LineIndex >= 0;
		--LineIndex) {
		fputc('|', stdout);
		for(BucketIndex = 0;
			BucketIndex < GRAPH_WIDTH;
			++BucketIndex) {
			stat_group* Group = Graph->Buckets + BucketIndex;
			int This = -1;
			if(Group->Count) {
				//                double AverageMs = Group->TotalMs / (double)Group->Count;
				This = MapToDiscrete(Group->SlowestMs, SlowestMs, GRAPH_HEIGHT - 1);
			}
			fputc((This >= LineIndex) ? '*' : ' ', stdout);
		}
		if(LineIndex == (GRAPH_HEIGHT - 1)) {
			fputc(' ', stdout);
			PrintTime(SlowestMs);
		}
		fputc('\n', stdout);
	}
	fputc('+', stdout);
	for(BucketIndex = 0; BucketIndex < GRAPH_WIDTH; ++BucketIndex) {
		fputc('-', stdout);
	}
	fputc(' ', stdout);
	PrintTime(0);
	fputc('\n', stdout);
	fputc('\n', stdout);
	for(LineIndex = GRAPH_HEIGHT - 1;
		LineIndex >= 0;
		--LineIndex) {
		fputc('|', stdout);
		for(BucketIndex = 0;
			BucketIndex < GRAPH_WIDTH;
			++BucketIndex) {
			stat_group* Group = Graph->Buckets + BucketIndex;
			int This = -1;
			if(Group->Count) {
				This = MapToDiscrete(Group->Count, MaxCountInBucket, GRAPH_HEIGHT - 1);
			}
			fputc((This >= LineIndex) ? '*' : ' ', stdout);
		}
		if(LineIndex == (GRAPH_HEIGHT - 1)) {
			fprintf(stdout, " %d", MaxCountInBucket);
		}
		fputc('\n', stdout);
	}
	fputc('+', stdout);
	for(BucketIndex = 0; BucketIndex < GRAPH_WIDTH; ++BucketIndex) {
		fputc('-', stdout);
	}
	fprintf(stdout, " 0\n");
}

static void
Stats(timing_entry_array Array, char* TimingFileName) {
	stat_group WithErrors = { 0 };
	stat_group NoErrors = { 0 };
	stat_group AllStats = { 0 };

	int unsigned IncompleteCount = 0;
	int unsigned DaysWithTimingCount = 0;
	int unsigned DaySpanCount = 0;

	int EntryIndex;

	timing_file_entry* Entry = Array.Entries;
	int unsigned LastDayIndex = 0;

	double AllMs = 0;

	int unsigned FirstRecentEntry = 0;

	double FirstDayAt = 0;
	double LastDayAt = 0;
	double DaySpan = 0;

	graph TotalGraph = { 0 };
	graph RecentGraph = { 0 };

	WithErrors.FastestMs = 0xFFFFFFFF;
	NoErrors.FastestMs = 0xFFFFFFFF;

	if(Array.EntryCount >= 2) {
		double MilliD = MillisecondDifference(Array.Entries[Array.EntryCount - 1].StartDate, Array.Entries[0].StartDate);
		DaySpanCount = (int unsigned)(MilliD / (1000.0 * 60.0 * 60.0 * 24.0));

		FirstDayAt = (double)DayIndex(Array.Entries[0].StartDate);
		LastDayAt = (double)DayIndex(Array.Entries[Array.EntryCount - 1].StartDate);
		DaySpan = (LastDayAt - FirstDayAt);
	}
	DaySpan += 1;

	for(EntryIndex = 0;
		EntryIndex < Array.EntryCount;
		++EntryIndex, ++Entry) {
		if(Entry->Flags & TFEF_Complete) {
			stat_group* Group = (Entry->Flags & TFEF_NoErrors) ? &NoErrors : &WithErrors;

			int unsigned ThisDayIndex = DayIndex(Entry->StartDate);
			if(LastDayIndex != ThisDayIndex) {
				LastDayIndex = ThisDayIndex;
				++DaysWithTimingCount;
			}

			UpdateStatGroup(Group, Entry);
			UpdateStatGroup(&AllStats, Entry);

			AllMs += (double)Entry->MillisecondsElapsed;

			{
				int GraphIndex = (int)(((double)(ThisDayIndex - FirstDayAt) / DaySpan) * (double)GRAPH_WIDTH);
				UpdateStatGroup(TotalGraph.Buckets + GraphIndex, Entry);
			}

			{
				int GraphIndex = ThisDayIndex - (int)(LastDayAt - GRAPH_WIDTH + 1);
				if(GraphIndex >= 0) {
					UpdateStatGroup(RecentGraph.Buckets + GraphIndex, Entry);
				}
			}
		} else {
			++IncompleteCount;
		}
	}

	fprintf(stdout, "\n%s Statistics\n\n", TimingFileName);
	fprintf(stdout, "Total complete timings: %d\n", WithErrors.Count + NoErrors.Count);
	fprintf(stdout, "Total incomplete timings: %d\n", IncompleteCount);
	fprintf(stdout, "Days with timings: %d\n", DaysWithTimingCount);
	fprintf(stdout, "Days between first and last timing: %d\n", DaySpanCount);
	PrintStatGroup("Timings marked successful", &NoErrors);
	PrintStatGroup("Timings marked failed", &WithErrors);

	PrintGraph("All", (LastDayAt - FirstDayAt), &TotalGraph);
	PrintGraph("Recent", GRAPH_WIDTH, &RecentGraph);

	fprintf(stdout, "\nTotal time spent: ");
	PrintTime(AllMs);
	fprintf(stdout, "\n");
}

int main(int ArgCount, char** Args) {
	// TODO(casey): It would be nice if this supported 64-bit file sizes, but I can't really
	// tell right now if "ANSI C" supports this.  I feel like it should by now, but the
	// MSVC docs seem to suggest you have to use __int64 to do 64-bit stuff with the CRT
	// low-level IO routines, and I'm pretty sure that isn't a portable type :(

	// NOTE(casey): We snap the clock time right on entry, to minimize any overhead on
	// "end" times that might occur from opening the file.
	int unsigned EntryClock = GetClock();

	if((ArgCount == 3) || (ArgCount == 4)) {
		char* Mode = Args[1];
		int ModeIsBegin = (strcmp(Mode, "-begin") == 0);
		char* TimingFileName = Args[2];
		timing_file_header Header = { 0 };

		int Handle = _open(TimingFileName, _O_RDWR | _O_BINARY, _S_IREAD | _S_IWRITE);
		if(Handle != -1) {
			// NOTE(casey): The file exists - check the magic value
			_read(Handle, &Header, sizeof(Header));
			if(Header.MagicValue == MAGIC_VALUE) {
				// NOTE(casey): The file is at least nominally valid.
			} else {
				fprintf(stderr, "ERROR: Unable to verify that \"%s\" is actually a ctime-compatible file.\n", TimingFileName);

				_close(Handle);
				Handle = -1;
			}
		} else if(ModeIsBegin) {
			// NOTE(casey): The file doesn't exist and we're starting a new timing, so create it.

			_sopen_s(&Handle, TimingFileName, _O_RDWR | _O_CREAT | _O_BINARY, _SH_DENYNO, _S_IREAD | _S_IWRITE);
			if(Handle != -1) {
				Header.MagicValue = MAGIC_VALUE;
				if(_write(Handle, &Header, sizeof(Header)) == sizeof(Header)) {
					// NOTE(casey): File creation was (presumably) successful.
				} else {
					fprintf(stderr, "ERROR: Unable to write header to \"%s\".\n", TimingFileName);
				}
			} else {
				fprintf(stderr, "ERROR: Unable to create timing file \"%s\".\n", TimingFileName);
			}
		}

		if(Handle != -1) {
			if(ModeIsBegin) {
				timing_file_entry NewEntry = { 0 };
				NewEntry.StartDate = GetDate();
				NewEntry.MillisecondsElapsed = GetClock();
				if((_lseek(Handle, 0, SEEK_END) >= 0) && (_write(Handle, &NewEntry, sizeof(NewEntry)) == sizeof(NewEntry))) {
					// NOTE(casey): Timer begin entry was written successfully.
				} else {
					fprintf(stderr, "ERROR: Unable to append new entry to file \"%s\".\n", TimingFileName);
				}
			} else if(strcmp(Mode, "-end") == 0) {
				timing_file_entry LastEntry = { 0 };
				if((_lseek(Handle, -(long)sizeof(timing_file_entry), SEEK_END) >= 0) && (_read(Handle, &LastEntry, sizeof(LastEntry)) == sizeof(LastEntry))) {
					if(!(LastEntry.Flags & TFEF_Complete)) {
						int unsigned StartClockD = LastEntry.MillisecondsElapsed;
						int unsigned EndClockD = EntryClock;
						LastEntry.Flags |= TFEF_Complete;
						LastEntry.MillisecondsElapsed = 0;
						if(StartClockD < EndClockD) {
							LastEntry.MillisecondsElapsed = (EndClockD - StartClockD);
						}

						if((ArgCount == 3) || ((ArgCount == 4) && (atoi(Args[3]) == 0))) {
							LastEntry.Flags |= TFEF_NoErrors;
						}

						if((_lseek(Handle, -(long)sizeof(timing_file_entry), SEEK_END) >= 0) && (_write(Handle, &LastEntry, sizeof(LastEntry)) == sizeof(LastEntry))) {
							fprintf(stdout, "CTIME: ");
							PrintTime(LastEntry.MillisecondsElapsed);
							fprintf(stdout, " (%s)\n", TimingFileName);
						} else {
							fprintf(stderr, "ERROR: Unable to rewrite last entry to file \"%s\".\n", TimingFileName);
						}
					} else {
						fprintf(stderr, "ERROR: Last entry in file \"%s\" is already closed - unbalanced/overlapped calls?\n", TimingFileName);
					}
				} else {
					fprintf(stderr, "ERROR: Unable to read last entry from file \"%s\".\n", TimingFileName);
				}
			} else if(strcmp(Mode, "-stats") == 0) {
				timing_entry_array Array = ReadAllEntries(Handle);
				Stats(Array, TimingFileName);
				FreeAllEntries(Array);
			} else if(strcmp(Mode, "-csv") == 0) {
				timing_entry_array Array = ReadAllEntries(Handle);
				CSV(Array, TimingFileName);
				FreeAllEntries(Array);
			} else {
				fprintf(stderr, "ERROR: Unrecognized command \"%s\".\n", Mode);
			}

			_close(Handle);
			Handle = -1;
		} else {
			fprintf(stderr, "ERROR: Cannnot open file \"%s\".\n", TimingFileName);
		}
	} else {
		Usage();
	}
}