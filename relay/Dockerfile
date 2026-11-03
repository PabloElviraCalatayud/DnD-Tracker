# Imagen mínima del relay de DnD Tracker.
#   docker build -t dndt-relay .
#   docker run -p 8080:8080 dndt-relay
FROM dart:stable AS build
WORKDIR /app
COPY pubspec.yaml ./
RUN dart pub get
COPY bin ./bin
RUN dart compile exe bin/relay.dart -o /app/relay

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/relay /app/relay
EXPOSE 8080
ENV PORT=8080
CMD ["/app/relay"]
