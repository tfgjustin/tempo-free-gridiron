CC = g++
#DEBUG=-g -O0
#DEBUG=-O2
DEBUG=-O3 -fexpensive-optimizations
CFLAGS = -I. -W -Wall -Wno-sign-compare
CFLAGS += $(DEBUG)

LDFLAGS = $(DEBUG)

BINARY = predict

tempofree_OBJ = tempo-free.o game-data.o utillog.o utilio.o
predict_OBJ = main.o $(tempofree_OBJ)

all: $(BINARY)
.PHONY: all

# Generate dependencies
.%.d: %.cc
	@echo -n "Updating $< dependencies ... "
	@$(CC) $(CFLAGS) -MM $< > $@
	@echo "done."

# Update dependencies
depend: .make.deps
	@echo "Updated dependencies"

.PHONY: depend

.make.deps: $(patsubst %.cc,.%.d,$(wildcard *.cc))
	@rm -f .make.deps
	@cat $(patsubst %.cc,.%.d,$(wildcard *.cc)) > .make.deps

include .make.deps

%.o: %.cc
	$(CC) $(CFLAGS) -c -o $@ $<

$(BINARY): $(predict_OBJ)
	$(CC) -o $@ $(predict_OBJ) $(LDFLAGS)

.PHONY: cleanall clean cleanobj cleandep

cleanall: clean cleandep

clean: cleanobj
	rm -f $(BINARY)

cleanobj:
	rm -f *.o

cleandep:
	rm -f .*.d .make.deps
