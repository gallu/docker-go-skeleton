FROM golang:1.27.3-bookworm

ENV GOTOOLCHAIN=local
RUN go install github.com/air-verse/air@v1.67.4

COPY air.toml /etc/air.toml
COPY check-app.sh dev.sh dev-build.sh build.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/check-app.sh /usr/local/bin/dev.sh /usr/local/bin/dev-build.sh /usr/local/bin/build.sh

WORKDIR /app
CMD ["dev.sh"]
