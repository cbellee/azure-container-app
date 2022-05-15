FROM golang:1.17.5-alpine3.15 AS builder

ARG SERVICE_NAME=""
ARG SERVICE_PORT=""

RUN mkdir /build
WORKDIR /build
RUN apk update && apk add --no-cache git
COPY ./cmd .

RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux GO111MODULE=on \
    go build \
    -o server \
    ./${SERVICE_NAME}

# release container image
FROM alpine:latest

ARG SERVICE_NAME=""
ARG SERVICE_PORT=""

WORKDIR /app
RUN apk --no-cache add ca-certificates
COPY --from=builder /build/server .

# run server
EXPOSE $SERVICE_PORT
CMD ["./server"]