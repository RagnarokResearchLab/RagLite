#ifdef RAGLITE_DEBUG_ASSERTIONS

#define ASSERT(condition, failureMessage) \
	if(!(condition)) {                    \
		DebugTrap();                      \
	}
#define ASSUME(condition, failureMessage) ASSERT(condition, failureMessage)

#else

#define NOOP ((void)0)
#define ASSUME(condition, failureMessage) NOOP

#endif

#define EXPAND_AS_STRING(x) #x
#define TOSTRING(x) EXPAND_AS_STRING(x)

#define FROM_HERE __FILE__ ":" TOSTRING(__LINE__)