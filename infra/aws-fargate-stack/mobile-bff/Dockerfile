# Minimal mobile-bff: the prebuilt YARP reverse proxy with eShop's routes baked
# in. The base image is chiseled/distroless (no shell), so the config must be
# copied in at build time rather than written at startup.
FROM mcr.microsoft.com/dotnet/nightly/yarp:2.3-preview
COPY yarp.config /etc/yarp.config
