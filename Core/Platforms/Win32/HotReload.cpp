String MODULE_FILE_NAME = StringLiteral("RagLite2Dbg.dll");

INTERNAL bool PlatformShouldReloadProgramCode(program_code_t& program) {
	FILETIME writeTime = PlatformGetLastWriteTime(MODULE_FILE_NAME);
	bool isOutdated = CompareFileTime(&writeTime, &program.lastWriteTime) != 0;
	return isOutdated;
}

INTERNAL void PlatformLoadProgramCode(program_code_t& program) {
	// NOTE: There's not much of a point to use hot-reloading in release builds, so this should be OK-ish for now...
	String sourcePDB = StringLiteral("RagLite2Dbg.pdb");
	String tempPDB = StringLiteral("RagLite2Dbg.loaded.pdb");
	CopyFileA(sourcePDB.buffer, tempPDB.buffer, FALSE);
	// TODO: ASSUME it worked, check error etc otherwise
	// TODO PlatformCopyFile

	String sourceDLL = MODULE_FILE_NAME;
	String tempDLL = StringLiteral("RagLite2Dbg.loaded.dll");
	CopyFileA(sourceDLL.buffer, tempDLL.buffer, FALSE);

	// TBD: Technically, the second file system query is redundant (but it's almost certainly cached, anyway)
	program.lastWriteTime = PlatformGetLastWriteTime(MODULE_FILE_NAME);
	program.handle = LoadLibraryA(tempDLL.buffer);
	// TODO: In case loading actually failed, it would be prudent to keep using the previously-loaded DLL instead
	ASSUME(program.handle, "Failed to load program code (check platform error or try again later)");

	program.SimulateNextFrame = (simulation_step_function_t*)GetProcAddress(program.handle, "SimulateNextFrame");
	ASSUME(program.SimulateNextFrame, "Failed to load executable program hook (cannot advance the simulation)");
}

void PlatformUnloadProgramCode(program_code_t& program) {
	if(!program.handle) return;
	// TODO: Ensure there's no dangling pointers (redirect to guard module/blocks -> Fail immediately in debug mode)
	FreeLibrary(program.handle);
	program.handle = NULL;
	program.SimulateNextFrame = NULL;
}

INTERNAL void PlatformReloadProgramCode(program_code_t& program) {
	// TBD: If LoadLibrary fails, skip the unload step and keep using the existing handle?
	PlatformUnloadProgramCode(program);
	PlatformLoadProgramCode(program);
}

#if 0

internal void
Win32UnloadCode(win32_loaded_code *Loaded)
{
    if(Loaded->DLL)
    {
        // TODO(casey): Currently, we never unload libraries, because
        // we may still be pointing to strings that are inside them
        // (despite our best efforts).  Should we just make "never unload"
        // be the policy?

        // FreeLibrary(GameCode->GameCodeDLL);
        Loaded->DLL = 0;
    }

    Loaded->IsValid = false;
    ZeroArray(Loaded->FunctionCount, Loaded->Functions);
}

internal void
Win32LoadCode(win32_state *State,
              win32_loaded_code *Loaded)
{
    char *SourceDLLName = Loaded->DLLFullPath;
    char *LockFileName = Loaded->LockFullPath;

    char TempDLLName[WIN32_STATE_FILE_NAME_COUNT];

    WIN32_FILE_ATTRIBUTE_DATA Ignored;
    if(!GetFileAttributesExA(LockFileName, GetFileExInfoStandard, &Ignored))
    {
        Loaded->DLLLastWriteTime = Win32GetLastWriteTime(SourceDLLName);

        for(u32 AttemptIndex = 0;
            AttemptIndex < 128;
            ++AttemptIndex)
        {
            Win32BuildEXEPathFileName(State, Loaded->TransientDLLName, Loaded->TempDLLNumber,
                                      sizeof(TempDLLName), TempDLLName);
            if(++Loaded->TempDLLNumber >= 1024)
            {
                Loaded->TempDLLNumber = 0;
            }

            if(CopyFile(SourceDLLName, TempDLLName, FALSE))
            {
                break;
            }
        }

        Loaded->DLL = LoadLibraryA(TempDLLName);
        if(Loaded->DLL)
        {
            Loaded->IsValid = true;
            for(u32 FunctionIndex = 0;
                FunctionIndex < Loaded->FunctionCount;
                ++FunctionIndex)
            {
                void *Function = GetProcAddress(Loaded->DLL, Loaded->FunctionNames[FunctionIndex]);
                if(Function)
                {
                    Loaded->Functions[FunctionIndex] = Function;
                }
                else
                {
                    Loaded->IsValid = false;
                }
            }
        }
    }

    if(!Loaded->IsValid)
    {
        Win32UnloadCode(Loaded);
    }
}

internal b32x
Win32CheckForCodeChange(win32_loaded_code *Loaded)
{
    FILETIME NewDLLWriteTime = Win32GetLastWriteTime(Loaded->DLLFullPath);
    b32x Result = (CompareFileTime(&NewDLLWriteTime, &Loaded->DLLLastWriteTime) != 0);
    return(Result);
}

internal void
Win32ReloadCode(win32_state *State, win32_loaded_code *Loaded)
{
    Win32UnloadCode(Loaded);
    for(u32 LoadTryIndex = 0;
        !Loaded->IsValid && (LoadTryIndex < 100);
        ++LoadTryIndex)
    {
        Win32LoadCode(State, Loaded);
        Sleep(100);
    }
}

#endif