return {
	testMatch = { "**/*.spec" },
	-- Modest bump over the 5s default so the hang tests fail via their bounded assertion, not a timeout.
	testTimeout = 10000,
}
