return {
	testMatch = { "**/*.spec" },
	-- A modest bump over the 5s default: enough to absorb MessagingService loopback variance in the
	-- two-server tests, without masking the hang tests (they fail via a bounded assertion at ~5s).
	testTimeout = 10000,
}
