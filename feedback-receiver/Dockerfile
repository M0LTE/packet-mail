# A static binary on an empty image: no shell, no package manager, no files
# to write. Run it with a read-only root filesystem (see README.md).
FROM rust:1-alpine AS build
RUN apk add --no-cache musl-dev
WORKDIR /src
COPY Cargo.toml Cargo.lock ./
COPY src ./src
RUN cargo build --release --locked

FROM scratch
COPY --from=build /src/target/release/feedback-receiver /feedback-receiver
USER 65534:65534
EXPOSE 8080
ENTRYPOINT ["/feedback-receiver"]
