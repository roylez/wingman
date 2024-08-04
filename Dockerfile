ARG ELIXIR=1.17.2
ARG ERLANG=27.0.1
ARG ALPINE=3.20.2

FROM hexpm/elixir:${ELIXIR}-erlang-${ERLANG}-alpine-${ALPINE} AS builder

RUN apk update
RUN apk add build-base git libtool autoconf automake
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix hex.info

WORKDIR /app
ENV MIX_ENV=prod
ADD mix* ./
RUN mix deps.get

ADD . .
RUN mix release

# ==============================================

FROM alpine:${ALPINE}

ENV LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8

RUN apk update --no-cache && \
    apk add --no-cache bash ncurses-libs libstdc++ ca-certificates tzdata

WORKDIR /app

RUN addgroup -S app && adduser -S app -G app -h /app
USER app

COPY --chown=app:app --from=builder /app/_build/prod/rel/wingman .

CMD ["./bin/wingman", "start" ]
