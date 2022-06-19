FROM golang:1.17-alpine3.14
RUN apk add --no-cache bash curl
WORKDIR /vk8s
COPY *.bash ./
RUN ./download-bin.bash

FROM alpine:3.14
RUN apk add --no-cache bash
COPY --from=0 /vk8s /vk8s
WORKDIR /vk8s
RUN head -1 ./download-bin.bash | cat >./download-bin.bash
RUN ln -s /vk8s/bin/kubectl /bin/kubectl
CMD ./start.bash
