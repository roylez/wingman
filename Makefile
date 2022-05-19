export hostname := $(shell hostname)
export app=wingman

.PHONY: iex chat
chat: export WINGMAN_CHAT_ADAPTER=console

chat iex:
	iex --name ${app}@${hostname}.local -S mix

.PHONY: docker
docker:
	docker build -t ${app} .
