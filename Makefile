BIN_DIR := ./bin

CMDS := Install auto-test

BINS := $(addprefix $(BIN_DIR)/, $(CMDS))

DEPS := shell-funcs

all: $(BINS)

$(BIN_DIR)/%: % %/lib $(DEPS)
	@mkdir -p $(BIN_DIR)
	go build -o $@ ./$*

clean:
	rm -rf $(BIN_DIR)
	rm go.work*
	go work init
	go work use -r .
	go work sync

test: all
	sudo bin/auto-test unit ./Install/lib system ./Install -v

.PHONY: all clean test
