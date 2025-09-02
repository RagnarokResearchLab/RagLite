#ifdef RAGLITE_DEBUG_ASSERTIONS

#define ASSERT(condition, failureMessage) \
	if(!(condition)) {                    \
		DebugMessage(failureMessage);     \
		DebugTrap();                      \
	}
#define ASSUME(condition, failureMessage) ASSERT(condition, failureMessage)

#else

#define NOOP ((void)0)
#define ASSUME(condition, failureMessage) NOOP

#endif