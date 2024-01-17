if [ "$1" = "--quick" ]; then
	# Some of the database files are huge, so formatting takes a lot of time and hogs memory
	# Since they're rarely changed, can skip them for local development (but never in CI runs)
    stylua . --verbose --glob '*.lua' --glob '!DB/*'
else
    stylua . --verbose
fi