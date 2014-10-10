PROJECT = vbisect
ERL_LIBS = /Users/jay/Git/proper

# Comment out the CT_OPTS for performance testing
CT_OPTS = -cover test/vbisect_func.coverspec
CT_SUITES = vbisect

include erlang.mk
